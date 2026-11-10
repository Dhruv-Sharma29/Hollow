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

    @Test func signInUsesOwnClientWhenGiven() {
        #expect(r.signInArgs(clientID: "id", clientSecret: "s").contains("client_id=id"))
        #expect(r.signInArgs(clientID: nil, clientSecret: nil).contains("config_shared_client_id=true"))
        #expect(r.signInArgs(clientID: nil, clientSecret: nil).contains("scope=drive.file"))
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
