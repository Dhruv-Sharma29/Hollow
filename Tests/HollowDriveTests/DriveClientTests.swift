import Foundation
import Testing
@testable import HollowDrive

/// Serialized: the fake server is shared state.
@Suite(.serialized)
struct DriveClientTests {
    let google = FakeGoogle()

    @Test func listFollowsEveryPage() async throws {
        google.respond { request, _ in
            request.query("pageToken") == nil
                ? FakeGoogle.json(["files": [["id": "1", "name": "a.mov", "mimeType": "video/quicktime", "size": "10"]],
                                   "nextPageToken": "p2"])
                : FakeGoogle.json(["files": [["id": "2", "name": "b", "mimeType": DriveFile.folderMIMEType]]])
        }
        let files = try await google.client().list(in: "root")
        #expect(files.map(\.id) == ["1", "2"])
        #expect(files[0].size == 10)
        #expect(files[1].isFolder)
        #expect(google.requests.first?.request.query("q") == "'root' in parents and trashed = false")
    }

    @Test func findEscapesQuotesInNames() async throws {
        google.respond { _, _ in FakeGoogle.json(["files": []]) }
        _ = try await google.client().find(named: "Dhruv's film", in: "root")
        #expect(google.requests.first?.request.query("q") == #"name = 'Dhruv\'s film' and 'root' in parents and trashed = false"#)
    }

    @Test func readAsksForJustTheRange() async throws {
        google.respond { _, _ in (206, [:], Data("0123456789".utf8)) }
        let data = try await google.client().read(id: "f", range: 100..<110)
        #expect(data == Data("0123456789".utf8))
        #expect(google.requests.first?.request.value(forHTTPHeaderField: "Range") == "bytes=100-109")
    }

    @Test func readSlicesWhenDriveSendsTheWholeFile() async throws {
        google.respond { _, _ in (200, [:], Data("abcdef".utf8)) }
        #expect(try await google.client().read(id: "f", range: 2..<4) == Data("cd".utf8))
    }

    @Test func expiredTokenIsRefreshedOnceAndRetried() async throws {
        google.respond { request, _ in
            if request.url?.host == "oauth2.googleapis.com" { return FakeGoogle.json(["access_token": "fresh", "expires_in": 3600]) }
            return request.value(forHTTPHeaderField: "Authorization") == "Bearer fresh"
                ? FakeGoogle.json(["id": "f", "name": "a", "mimeType": "text/plain"])
                : (401, [:], Data())
        }
        let file = try await google.client().file(id: "f")
        #expect(file.id == "f")
        #expect(google.requests.count(where: { $0.request.url?.host == "oauth2.googleapis.com" }) == 1)
    }

    @Test func revokedSignInIsReportedAsSignedOut() async throws {
        google.respond { request, _ in
            request.url?.host == "oauth2.googleapis.com" ? (400, [:], Data(#"{"error":"invalid_grant"}"#.utf8)) : (401, [:], Data())
        }
        await #expect(throws: DriveError.signedOut) { try await google.client(token: nil).file(id: "f") }
    }

    @Test func serverErrorsAreRetriedButNotForever() async throws {
        google.respond { _, _ in (503, [:], Data()) }
        await #expect(throws: DriveError.http(status: 503, message: "")) { try await google.client().file(id: "f") }
        #expect(google.requests.count == 4)   // one try plus three retries
    }

    @Test func missingFileIsNotFound() async throws {
        google.respond { _, _ in (404, [:], Data()) }
        await #expect(throws: DriveError.notFound) { try await google.client().file(id: "gone") }
    }

    @Test func trashMovesToBinInsteadOfDeleting() async throws {
        google.respond { _, _ in FakeGoogle.json(["id": "f"]) }
        try await google.client().trash(id: "f")
        let sent = try #require(google.requests.first)
        #expect(sent.request.httpMethod == "PATCH")
        #expect(try JSONSerialization.jsonObject(with: sent.body) as? [String: Bool] == ["trashed": true])
    }
}
