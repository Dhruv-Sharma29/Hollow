import Foundation

/// An upload Drive is expecting. Codable so it can be saved and resumed after Hollow quits:
/// Drive keeps the session for about a week.
public struct UploadSession: Codable, Sendable, Equatable {
    public let url: URL
    public let size: Int64
}

extension DriveClient {
    /// Drive requires every chunk except the last to be a multiple of 256 KiB.
    public static let chunkUnit = 256 * 1024

    /// Tells Drive a file is coming. Nothing is uploaded yet.
    public func startUpload(name: String, in parentID: String, size: Int64,
                            mimeType: String = "application/octet-stream") async throws -> UploadSession {
        var request = URLRequest(url: Self.uploadAPI.appending(queryItems: [
            .init(name: "uploadType", value: "resumable"), .init(name: "fields", value: DriveFile.fields),
        ]))
        request.httpMethod = "POST"
        request.setJSON(["name": name, "parents": [parentID]])
        request.setValue(String(size), forHTTPHeaderField: "X-Upload-Content-Length")
        request.setValue(mimeType, forHTTPHeaderField: "X-Upload-Content-Type")
        let (_, response) = try await send(request)
        guard let location = response.value(forHTTPHeaderField: "Location"), let url = URL(string: location) else {
            throw DriveError.http(status: response.statusCode, message: "Drive didn't return an upload session")
        }
        return UploadSession(url: url, size: size)
    }

    /// How many bytes Drive already has: where to continue after an interruption.
    /// Returns the finished file instead if Drive already has all of it.
    public func uploadStatus(_ upload: UploadSession) async throws -> (received: Int64, file: DriveFile?) {
        var request = URLRequest(url: upload.url)
        request.httpMethod = "PUT"
        request.setValue("bytes */\(upload.size)", forHTTPHeaderField: "Content-Range")
        request.httpBody = Data()
        let (data, response) = try await send(request, accept: [200, 201, 308])
        if response.statusCode == 308 { return (Self.received(from: response), nil) }
        return (upload.size, try decode(DriveFile.self, data))
    }

    /// Sends the file from wherever Drive left off, in chunks. Safe to call again after any failure,
    /// including a restart: it asks Drive what arrived and continues from there.
    /// `progress` gets the bytes Drive has confirmed; throwing from it stops the upload (resumable later).
    public func upload(_ upload: UploadSession, from file: URL, chunkSize: Int = 8 * 1024 * 1024,
                       progress: @Sendable (Int64) async throws -> Void = { _ in }) async throws -> DriveFile {
        precondition(chunkSize % Self.chunkUnit == 0, "chunkSize must be a multiple of 256 KiB")
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }

        var (offset, finished) = try await uploadStatus(upload)
        var failures = 0
        while finished == nil {
            if upload.size == 0 { break }   // an empty file needs no chunks; the status call completes it
            try handle.seek(toOffset: UInt64(offset))
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            guard !chunk.isEmpty else { throw DriveError.uploadOutOfSync(expected: upload.size, serverHas: offset) }

            var request = URLRequest(url: upload.url)
            request.httpMethod = "PUT"
            request.setValue("bytes \(offset)-\(offset + Int64(chunk.count) - 1)/\(upload.size)", forHTTPHeaderField: "Content-Range")
            request.httpBody = chunk
            do {
                let (data, response) = try await send(request, accept: [200, 201, 308], retries: false)
                failures = 0
                if response.statusCode == 308 {
                    // Drive may keep less than was sent; continue from what it confirms, not from what was sent.
                    offset = Self.received(from: response)
                } else {
                    finished = try decode(DriveFile.self, data)
                    offset = upload.size
                }
            } catch let error as DriveError where error == .signedOut || error == .notFound {
                throw error   // a new sign-in or a new session is needed; retrying won't help
            } catch {
                // Network drop or server error mid-chunk: ask Drive what arrived, then carry on.
                failures += 1
                guard failures < maxAttempts else { throw error }
                try await Task.sleep(for: retryDelay(failures))
                (offset, finished) = try await uploadStatus(upload)
            }
            try await progress(offset)
        }
        if let finished { return finished }
        return try await uploadStatus(upload).file ?? { throw DriveError.uploadOutOfSync(expected: upload.size, serverHas: offset) }()
    }

    /// Drive reports what it has as "Range: bytes=0-N". No header means nothing yet.
    static func received(from response: HTTPURLResponse) -> Int64 {
        guard let range = response.value(forHTTPHeaderField: "Range"),
              let last = range.split(separator: "-").last.flatMap({ Int64($0) }) else { return 0 }
        return last + 1
    }
}
