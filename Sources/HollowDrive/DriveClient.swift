import Foundation

/// Google Drive v3, with only what a Finder-style disk needs. Every call adds a fresh access token,
/// refreshes it once on 401, and retries rate limits and server errors with backoff.
public struct DriveClient: Sendable {
    let tokens: TokenProvider
    let session: URLSession
    /// Wait before retry `n` (1, 2, 3…). Injectable so tests don't sleep.
    let retryDelay: @Sendable (Int) -> Duration
    let maxAttempts = 4
    /// Rate limited, or Google's side failed: worth another try after a pause.
    static let retryable: Set<Int> = [429, 500, 502, 503, 504]

    static let api = URL(string: "https://www.googleapis.com/drive/v3/")!
    static let uploadAPI = URL(string: "https://www.googleapis.com/upload/drive/v3/files")!

    public init(tokens: TokenProvider, session: URLSession = .shared,
                retryDelay: @escaping @Sendable (Int) -> Duration = { .milliseconds(500 << $0) }) {
        self.tokens = tokens
        self.session = session
        self.retryDelay = retryDelay
    }

    // MARK: Reading

    /// Everything directly inside a folder ("root" for the top of the Drive), following every page.
    public func list(in folderID: String) async throws -> [DriveFile] {
        try await query("'\(escape(folderID))' in parents and trashed = false")
    }

    /// The item with this exact name in a folder, if any.
    public func find(named name: String, in folderID: String) async throws -> DriveFile? {
        try await query("name = '\(escape(name))' and '\(escape(folderID))' in parents and trashed = false").first
    }

    public func file(id: String) async throws -> DriveFile {
        let url = Self.api.appending(path: "files/\(id)").appending(queryItems: [.init(name: "fields", value: DriveFile.fields)])
        return try decode(DriveFile.self, try await send(URLRequest(url: url)).0)
    }

    /// Just these bytes of a file: the reason Hollow never downloads a whole 48 GB film to play it.
    public func read(id: String, range: Range<Int64>) async throws -> Data {
        guard !range.isEmpty else { return Data() }
        var request = URLRequest(url: Self.api.appending(path: "files/\(id)").appending(queryItems: [.init(name: "alt", value: "media")]))
        request.setValue("bytes=\(range.lowerBound)-\(range.upperBound - 1)", forHTTPHeaderField: "Range")
        let (data, response) = try await send(request, accept: [200, 206])
        // 200 means Drive ignored the range and sent the whole file (it does for tiny files): slice it.
        if response.statusCode == 200 {
            let start = Int(min(range.lowerBound, Int64(data.count)))
            let end = Int(min(range.upperBound, Int64(data.count)))
            return data.subdata(in: start..<end)
        }
        return data
    }

    // MARK: Changing

    public func createFolder(named name: String, in parentID: String) async throws -> DriveFile {
        var request = URLRequest(url: Self.api.appending(path: "files").appending(queryItems: [.init(name: "fields", value: DriveFile.fields)]))
        request.httpMethod = "POST"
        request.setJSON(["name": name, "mimeType": DriveFile.folderMIMEType, "parents": [parentID]])
        return try decode(DriveFile.self, try await send(request).0)
    }

    /// Rename, move, or both. Pass nil for whichever stays the same.
    public func update(id: String, newName: String? = nil, moveFrom oldParent: String? = nil,
                       to newParent: String? = nil) async throws -> DriveFile {
        var items = [URLQueryItem(name: "fields", value: DriveFile.fields)]
        if let newParent, let oldParent {
            items += [.init(name: "addParents", value: newParent), .init(name: "removeParents", value: oldParent)]
        }
        var request = URLRequest(url: Self.api.appending(path: "files/\(id)").appending(queryItems: items))
        request.httpMethod = "PATCH"
        request.setJSON(newName.map { ["name": $0] } ?? [:])
        return try decode(DriveFile.self, try await send(request).0)
    }

    /// Moves to Drive's bin rather than deleting for good, so a mistake can be undone for 30 days.
    public func trash(id: String) async throws {
        var request = URLRequest(url: Self.api.appending(path: "files/\(id)").appending(queryItems: [.init(name: "fields", value: "id")]))
        request.httpMethod = "PATCH"
        request.setJSON(["trashed": true])
        _ = try await send(request)
    }

    // MARK: Plumbing

    private func query(_ q: String) async throws -> [DriveFile] {
        struct Page: Decodable { let files: [DriveFile]; let nextPageToken: String? }
        var all: [DriveFile] = []
        var pageToken: String?
        repeat {
            var items: [URLQueryItem] = [
                .init(name: "q", value: q),
                .init(name: "fields", value: "nextPageToken,files(\(DriveFile.fields))"),
                .init(name: "pageSize", value: "1000"),
            ]
            if let pageToken { items.append(.init(name: "pageToken", value: pageToken)) }
            let page = try decode(Page.self, try await send(URLRequest(url: Self.api.appending(path: "files").appending(queryItems: items))).0)
            all += page.files
            pageToken = page.nextPageToken
        } while pageToken != nil
        return all
    }

    /// Drive's query language quotes with ' and escapes with \.
    private func escape(_ value: String) -> String {
        value.replacing("\\", with: "\\\\").replacing("'", with: "\\'")
    }

    /// Sends with a bearer token. 401: refresh once and retry. 429 and 5xx: back off and retry.
    /// `retries: false` is for upload chunks, where the caller asks Drive what arrived instead.
    func send(_ request: URLRequest, accept: Set<Int> = [200], retries: Bool = true) async throws -> (Data, HTTPURLResponse) {
        var refreshed = false
        var attempt = 0
        while true {
            attempt += 1
            var authorized = request
            authorized.setValue("Bearer \(try await tokens.token())", forHTTPHeaderField: "Authorization")
            let (data, response) = try await session.data(for: authorized)
            guard let http = response as? HTTPURLResponse else { throw DriveError.http(status: 0, message: "No HTTP response") }
            switch http.statusCode {
            case let status where accept.contains(status):
                return (data, http)
            case 401 where !refreshed:
                refreshed = true
                await tokens.invalidate()
            case let status where Self.retryable.contains(status) && retries && attempt < maxAttempts:
                try await Task.sleep(for: retryDelay(attempt))
            case 404:
                throw DriveError.notFound
            default:
                throw DriveError.http(status: http.statusCode, message: String(decoding: data, as: UTF8.self))
            }
        }
    }

    func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }
}

extension URLRequest {
    mutating func setJSON(_ object: [String: Any]) {
        httpBody = try? JSONSerialization.data(withJSONObject: object)
        setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
    }
}
