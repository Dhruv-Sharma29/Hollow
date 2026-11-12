import Foundation
import Testing
@testable import Hollow

struct RcloneTests {
    let tmp = URL.temporaryDirectory.appending(path: "hollow-test-\(UUID())")
    var r: Rclone { Rclone(binary: URL(filePath: "/bin/echo"), support: tmp, mountPoint: tmp.appending(path: "mnt")) }

    @Test func mountStreamsWithSparseCache() throws {
        let a = r.mountArgs()
        #expect(a.first == "nfsmount")
        #expect(a[1] == "hollow:")
        let i = try #require(a.firstIndex(of: "--vfs-cache-mode"))
        #expect(a[i + 1] == "full")
        #expect(a.contains(r.config.path))   // never touches the user's own rclone.conf
    }

    /// Decodes rclone's unpadded base64url blob back to its JSON fields.
    private func decode(_ blob: String) throws -> [String: String] {
        var b64 = blob.replacing("-", with: "+").replacing("_", with: "/")
        b64 += String(repeating: "=", count: (4 - b64.count % 4) % 4)
        let data = try #require(Data(base64Encoded: b64))
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
    }

    @Test func authorizeKeepsTheNarrowScope() throws {
        #expect(try decode(Rclone.authorizeBlob(clientID: "id", clientSecret: "s"))
                == ["scope": "drive.file", "client_id": "id", "client_secret": "s"])
        #expect(try decode(Rclone.authorizeBlob(clientID: nil, clientSecret: nil)) == ["scope": "drive.file"])
    }

    @Test func authorizeShowsHollowsPage() {
        let page = URL(filePath: "/tmp/signin.html")
        let a = r.authorizeArgs(clientID: "id", clientSecret: "s", template: page)
        #expect(Array(a.prefix(2)) == ["authorize", "drive"])
        #expect(Array(a.suffix(2)) == ["--template", page.path])
        #expect(r.authorizeArgs(clientID: nil, clientSecret: nil, template: nil).contains("--template") == false)
    }

    @Test func tokenIsReadFromAuthorizeOutput() {
        let printed = """
        Paste the following into your remote machine --->
        {"access_token":"a","token_type":"Bearer","refresh_token":"r","expiry":"2030-01-01T00:00:00Z"}
        <---End paste
        """
        #expect(Rclone.token(fromAuthorizeOutput: printed)?.hasPrefix(#"{"access_token":"a""#) == true)
        #expect(Rclone.token(fromAuthorizeOutput: "Failed to get token") == nil)
        #expect(Rclone.token(fromAuthorizeOutput: "---> not json <---End paste") == nil)
    }

    @Test func savingTheTokenUsesOwnClientWhenGiven() {
        let own = r.saveTokenArgs("{}", clientID: "id", clientSecret: "s")
        #expect(own.contains("token={}") && own.contains("client_id=id") && own.contains("--non-interactive"))
        #expect(own.contains(r.config.path))
        let shared = r.saveTokenArgs("{}", clientID: nil, clientSecret: nil)
        #expect(shared.contains("config_shared_client_id=true") && shared.contains("scope=drive.file"))
    }

    @Test func signedInNeedsAToken() throws {
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try "[hollow]\ntype = drive\n".write(to: r.config, atomically: true, encoding: .utf8)
        #expect(r.isSignedIn() == false)
        try "[hollow]\ntype = drive\ntoken = {}\n".write(to: r.config, atomically: true, encoding: .utf8)
        #expect(r.isSignedIn())
    }

    @Test func mountTableLookup() {
        #expect(isMountPoint(URL(filePath: "/")))
        #expect(isMountPoint(tmp) == false)
    }
}
