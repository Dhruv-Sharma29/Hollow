import Foundation
import Testing
@testable import HollowDrive

/// A fake resumable-upload endpoint that stores what it accepts, like Drive does.
/// `acceptLimit` makes it keep less than each chunk sent, as Drive is allowed to.
final class FakeUploadServer: @unchecked Sendable {
    let lock = NSLock()
    var stored = Data()
    let size: Int
    let acceptLimit: Int?
    var failNextChunk: Bool

    init(size: Int, acceptLimit: Int? = nil, failNextChunk: Bool = false) {
        self.size = size
        self.acceptLimit = acceptLimit
        self.failNextChunk = failNextChunk
    }

    func reply(_ request: URLRequest, _ body: Data) -> FakeGoogle.Reply {
        lock.withLock {
            if request.httpMethod == "POST" { return (200, ["Location": "https://upload.example/session"], Data()) }
            let range = request.value(forHTTPHeaderField: "Content-Range") ?? ""
            if range.hasPrefix("bytes */") { return status() }               // "how much do you have?"
            if failNextChunk { failNextChunk = false; return (503, [:], Data()) }
            let start = Int(range.dropFirst(6).split(separator: "-")[0])!
            guard start == stored.count else { return status() }              // out of order: say where we are
            stored.append(body.prefix(acceptLimit ?? body.count))
            return status()
        }
    }

    private func status() -> FakeGoogle.Reply {
        if stored.count == size { return FakeGoogle.json(["id": "up", "name": "film.mov", "mimeType": "video/quicktime", "size": "\(size)"]) }
        return (308, stored.isEmpty ? [:] : ["Range": "bytes=0-\(stored.count - 1)"], Data())
    }
}

@Suite(.serialized)
struct UploadTests {
    let google = FakeGoogle()
    let unit = DriveClient.chunkUnit

    /// A file with distinct bytes, so a gap or repeat shows up as a mismatch.
    func sampleFile(size: Int) throws -> (URL, Data) {
        let data = Data((0..<size).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ $0 / 251) })
        let url = URL.temporaryDirectory.appending(path: "hollow-upload-\(UUID()).bin")
        try data.write(to: url)
        return (url, data)
    }

    @Test func uploadsInChunksAndFinishes() async throws {
        let (file, data) = try sampleFile(size: unit * 2 + 1000)
        let server = FakeUploadServer(size: data.count)
        google.respond(server.reply)
        let client = google.client()
        let session = try await client.startUpload(name: "film.mov", in: "root", size: Int64(data.count))
        let done = try await client.upload(session, from: file, chunkSize: unit)
        #expect(done.id == "up")
        #expect(server.stored == data)
    }

    @Test func continuesFromWhatDriveConfirmsNotWhatWasSent() async throws {
        let (file, data) = try sampleFile(size: unit * 3)
        let server = FakeUploadServer(size: data.count, acceptLimit: unit)   // keeps only half of each 2-unit chunk
        google.respond(server.reply)
        let client = google.client()
        let session = try await client.startUpload(name: "film.mov", in: "root", size: Int64(data.count))
        _ = try await client.upload(session, from: file, chunkSize: unit * 2)
        #expect(server.stored == data)
    }

    @Test func recoversFromAFailedChunk() async throws {
        let (file, data) = try sampleFile(size: unit * 2)
        let server = FakeUploadServer(size: data.count, failNextChunk: true)
        google.respond(server.reply)
        let client = google.client()
        let session = try await client.startUpload(name: "film.mov", in: "root", size: Int64(data.count))
        _ = try await client.upload(session, from: file, chunkSize: unit)
        #expect(server.stored == data)
    }

    @Test func resumesAfterStoppingPartWay() async throws {
        let (file, data) = try sampleFile(size: unit * 3)
        let server = FakeUploadServer(size: data.count)
        google.respond(server.reply)
        let client = google.client()
        let session = try await client.startUpload(name: "film.mov", in: "root", size: Int64(data.count))

        // Stop after the first chunk, as if the Mac went to sleep or Hollow quit.
        await #expect(throws: CancellationError.self) {
            try await client.upload(session, from: file, chunkSize: unit) { sent in
                if sent > 0 { throw CancellationError() }
            }
        }
        #expect(server.stored.count == unit)

        // Later, possibly after a restart, the same saved session picks up where it left off.
        let restored = try JSONDecoder().decode(UploadSession.self, from: JSONEncoder().encode(session))
        _ = try await client.upload(restored, from: file, chunkSize: unit)
        #expect(server.stored == data)
        let firstResumedChunk = google.requests.last { $0.request.value(forHTTPHeaderField: "Content-Range")?.hasPrefix("bytes \(unit)-") == true }
        #expect(firstResumedChunk != nil)   // it did not start again from byte 0
    }

    @Test func emptyFileNeedsNoChunks() async throws {
        let (file, _) = try sampleFile(size: 0)
        let server = FakeUploadServer(size: 0)
        google.respond(server.reply)
        let client = google.client()
        let session = try await client.startUpload(name: "empty", in: "root", size: 0)
        #expect(try await client.upload(session, from: file).id == "up")
    }

    @Test func driveStatusRangeHeaderIsParsed() {
        let response = HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 308, httpVersion: nil,
                                       headerFields: ["Range": "bytes=0-262143"])!
        #expect(DriveClient.received(from: response) == 262_144)
        let none = HTTPURLResponse(url: URL(string: "https://x")!, statusCode: 308, httpVersion: nil, headerFields: [:])!
        #expect(DriveClient.received(from: none) == 0)
    }
}

@Test func driveFileDecodesStringSizesAndDates() throws {
    let json = Data(#"{"id":"1","name":"a","mimeType":"video/mp4","size":"48318382080","modifiedTime":"2026-11-12T09:30:15.123Z"}"#.utf8)
    let file = try JSONDecoder().decode(DriveFile.self, from: json)
    #expect(file.size == 48_318_382_080)   // 45 GiB: larger than Int32, sent as a string
    #expect(file.modifiedTime != nil)
    #expect(file.isFolder == false)
}
