import Foundation

/// Everything Hollow asks rclone to do. Pure values, so it's testable.
struct Rclone {
    static let remote = "hollow"

    let binary: URL
    let support: URL      // ~/Library/Application Support/Hollow
    let mountPoint: URL   // ~/Hollow

    var config: URL { support.appending(path: "rclone.conf") }
    var cache: URL { support.appending(path: "cache") }
    var log: URL { support.appending(path: "rclone.log") }

    /// Opens the browser for Google sign-in and writes the token to our own config file.
    /// scope=drive.file: rclone only sees files it created, never the rest of the Drive.
    func signInArgs(clientID: String?, clientSecret: String?) -> [String] {
        var args = ["config", "create", Self.remote, "drive", "scope=drive.file"]
        if let clientID, let clientSecret {
            args += ["client_id=\(clientID)", "client_secret=\(clientSecret)"]
        } else {
            // ponytail: rclone's shared client is being retired in 2026; set HOLLOW_CLIENT_ID/SECRET.
            args += ["config_shared_client_id=true"]
        }
        return args + ["--config", config.path]
    }

    /// NFS mount (no kernel extension or macFUSE). Full VFS cache = sparse cache files,
    /// so only the byte ranges an app actually reads get downloaded.
    func mountArgs(cacheLimit: String = "10G") -> [String] {
        ["nfsmount", "\(Self.remote):", mountPoint.path,
         "--config", config.path,
         "--cache-dir", cache.path,
         "--vfs-cache-mode", "full",
         "--vfs-cache-max-size", cacheLimit,
         "--volname", "Hollow",
         "--log-file", log.path]
    }

    func isSignedIn() -> Bool {
        let text = (try? String(contentsOf: config, encoding: .utf8)) ?? ""
        return text.contains("[\(Self.remote)]") && text.contains("token =")
    }

    /// The copy shipped inside Hollow.app comes first. The fallbacks are for `swift run`;
    /// GUI apps don't get the shell's PATH, so look in the usual install spots.
    static func find() -> URL? {
        if let bundled = Bundle.main.url(forAuxiliaryExecutable: "rclone") { return bundled }
        return ["/opt/homebrew/bin/rclone", "/usr/local/bin/rclone", "/usr/bin/rclone"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
            .map { URL(filePath: $0) }
    }

    /// Release builds get the Google client baked into Info.plist by scripts/build-app.sh,
    /// so it never sits in the repo. `swift run` reads it from the environment.
    static func googleClient() -> (id: String, secret: String)? {
        let info = Bundle.main.infoDictionary ?? [:]
        let env = ProcessInfo.processInfo.environment
        guard let id = info["HollowGoogleClientID"] as? String ?? env["HOLLOW_CLIENT_ID"],
              let secret = info["HollowGoogleClientSecret"] as? String ?? env["HOLLOW_CLIENT_SECRET"],
              !id.isEmpty, !secret.isEmpty else { return nil }
        return (id, secret)
    }
}

/// True when something is mounted exactly at `url`.
/// Reads the kernel's mount table (MNT_NOWAIT) and never touches the path itself,
/// so a dead NFS mount can't hang the caller the way `statfs(path)` can.
func isMountPoint(_ url: URL) -> Bool {
    var mounts: UnsafeMutablePointer<statfs>?
    let count = Int(getmntinfo(&mounts, MNT_NOWAIT))
    guard let mounts else { return false }
    let target = url.standardizedFileURL.path
    return (0..<count).contains { i in
        withUnsafeBytes(of: mounts[i].f_mntonname) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) } == target
    }
}
