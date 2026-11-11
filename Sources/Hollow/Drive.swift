import AppKit
import Observation
import ServiceManagement

@MainActor @Observable
final class Drive {
    enum Phase: Equatable { case idle, busy(String), mounted, failed(String) }

    private(set) var phase: Phase = .idle
    private(set) var signedIn = false
    let rclone: Rclone?
    private var mountProcess: Process?
    private var signInProcess: Process?
    private var mounting = false
    /// A problem worth showing that doesn't change the mount state, e.g. a refused unmount.
    private(set) var notice: String?

    init() {
        let support = URL.applicationSupportDirectory.appending(path: "Hollow")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        rclone = Rclone.find().map {
            Rclone(binary: $0, support: support, mountPoint: URL.homeDirectory.appending(path: "Hollow"))
        }
        guard let rclone else { phase = .failed("rclone not found. Run: brew install rclone"); return }
        signedIn = rclone.isSignedIn()
        if signedIn { Task { await mount() } }   // never block launch on mount work
    }

    var status: String {
        if let notice { return notice }
        return switch phase {
        case .idle: signedIn ? "Not mounted" : "Not signed in"
        case .busy(let what): what
        case .mounted: "Mounted at ~/Hollow"
        case .failed(let why): why
        }
    }

    func signIn() async {
        guard let rclone else { return }
        // Clicking again restarts sign-in. Otherwise the old rclone keeps its local OAuth port
        // and the new one fails.
        signInProcess?.terminate()
        let client = Rclone.googleClient()
        let p = Process()
        p.executableURL = rclone.binary
        p.arguments = rclone.signInArgs(clientID: client?.id, clientSecret: client?.secret)
        signInProcess = p
        phase = .busy("Finish signing in in your browser…")

        let code = await Self.exitCode(of: p)
        guard signInProcess === p else { return }   // a newer sign-in replaced this one
        signInProcess = nil
        signedIn = rclone.isSignedIn()
        if code == 15 { phase = .idle; return }   // the user pressed Cancel
        guard code == 0, signedIn else { phase = .failed("Sign-in didn't finish. Try again."); return }
        await mount()
    }

    var isSigningIn: Bool { signInProcess != nil }

    func cancelSignIn() {
        signInProcess?.terminate()
    }

    private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled

    /// Only works from the bundled Hollow.app, not `swift run`.
    func setOpensAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            loginItemError = error.localizedDescription
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    private(set) var loginItemError: String?

    func mount() async {
        guard let rclone, mountProcess == nil, !mounting else { return }
        mounting = true
        defer { mounting = false }
        notice = nil

        // A crash can leave an old NFS mount behind. Clear it off the main actor, and give up
        // after a while: on a dead server even `umount -f` can wait in the kernel indefinitely.
        if isMountPoint(rclone.mountPoint) {
            phase = .busy("Clearing an old mount…")
            let code = await Self.run("/sbin/umount", ["-f", rclone.mountPoint.path], timeout: .seconds(10))
            if code == nil || isMountPoint(rclone.mountPoint) {
                phase = .failed("An old Hollow mount is stuck. Restart your Mac, then open Hollow.")
                return
            }
        }
        let fm = FileManager.default
        try? fm.createDirectory(at: rclone.mountPoint, withIntermediateDirectories: true)
        try? fm.createDirectory(at: rclone.cache, withIntermediateDirectories: true)

        let p = Process()
        p.executableURL = rclone.binary
        let gb = UserDefaults.standard.object(forKey: Self.cacheLimitKey) as? Int ?? Self.defaultCacheLimitGB
        p.arguments = rclone.mountArgs(cacheLimit: "\(gb)G")
        p.terminationHandler = { proc in
            let code = proc.terminationStatus
            Task { @MainActor in self.mountEnded(code) }
        }
        do { try p.run() } catch { phase = .failed("Couldn't start rclone: \(error.localizedDescription)"); return }
        mountProcess = p
        phase = .busy("Mounting…")

        for _ in 0..<40 {
            guard mountProcess === p else { return }   // rclone exited; mountEnded reports why
            if isMountPoint(rclone.mountPoint) { phase = .mounted; return }
            try? await Task.sleep(for: .milliseconds(250))
        }
        guard mountProcess === p else { return }
        phase = .failed("Mount timed out, see rclone.log")
        p.terminate()   // so Mount can be tried again
    }

    /// Unmounts first, while rclone's NFS server is still up, then stops rclone.
    /// The other order (SIGTERM first) can leave the kernel waiting on a server that's gone.
    /// Returns false, and stays mounted, when macOS refuses because files are open.
    @discardableResult
    func unmount() async -> Bool {
        guard let rclone, let p = mountProcess else { return true }
        notice = nil
        phase = .busy("Unmounting…")
        if isMountPoint(rclone.mountPoint) {
            let code = await Self.run("/sbin/umount", [rclone.mountPoint.path], timeout: .seconds(15))
            if code != 0, isMountPoint(rclone.mountPoint) {
                phase = .mounted
                notice = "Couldn't unmount. Close files open from Hollow, then try again."
                return false
            }
        }
        p.terminate()
        // ponytail: rclone may still be uploading. Its cache keeps pending writes and retries
        // them on the next mount, so after 30 s we stop waiting rather than hang Quit.
        _ = await Self.wait(for: p, timeout: .seconds(30))
        return true
    }

    func signOut() async {
        guard await unmount() else { return }
        signInProcess?.terminate()
        guard let rclone else { return }
        try? FileManager.default.removeItem(at: rclone.config)
        // ponytail: the cache is kept on purpose. It can hold writes rclone hasn't uploaded yet,
        // and rclone uploads them on the next mount. Deleting it here could lose files.
        signedIn = false
        phase = .idle
    }

    static let cacheLimitKey = "cacheLimitGB"
    static let defaultCacheLimitGB = 10

    /// Copies files into the mount. rclone uploads them in the background.
    func add(_ urls: [URL]) async {
        guard let dest = rclone?.mountPoint, phase == .mounted else { return }
        notice = nil
        let failed = await Self.copy(urls, to: dest)
        // A notice, not .failed: the Drive is still mounted, and .failed would offer a "Mount again"
        // that can't run while rclone is up.
        if !failed.isEmpty { notice = "Couldn't add \(failed.formatted())" }
    }

    @concurrent private static func copy(_ urls: [URL], to dest: URL) async -> [String] {
        var failed: [String] = []
        for url in urls {
            do { try FileManager.default.copyItem(at: url, to: dest.appending(path: url.lastPathComponent)) }
            catch { failed.append(url.lastPathComponent) }
        }
        return failed
    }

    func openInFinder() {
        guard let rclone else { return }
        NSWorkspace.shared.open(rclone.mountPoint)
    }

    func openLog() {
        guard let rclone else { return }
        NSWorkspace.shared.open(rclone.log)
    }

    private func mountEnded(_ code: Int32) {
        mountProcess = nil
        if case .failed = phase { return }   // keep the timeout message
        // 0 = clean exit, 15 = the SIGTERM we sent. Anything else is a real failure.
        phase = (code == 0 || code == 15) ? .idle : .failed("rclone stopped (exit \(code)), see rclone.log")
    }

    private static func exitCode(of p: Process) async -> Int32 {
        await withCheckedContinuation { cont in
            p.terminationHandler = { cont.resume(returning: $0.terminationStatus) }
            do { try p.run() } catch { cont.resume(returning: -1) }   // handler never fires if run() throws
        }
    }

    /// Runs a tool off the main actor. nil means it didn't finish within `timeout`
    /// (it's left running: a process stuck in the kernel can't be killed anyway).
    @concurrent private static func run(_ path: String, _ args: [String], timeout: Duration) async -> Int32? {
        let p = Process()
        p.executableURL = URL(filePath: path)
        p.arguments = args
        do { try p.run() } catch { return nil }
        return await wait(for: p, timeout: timeout) ? p.terminationStatus : nil
    }

    @concurrent private static func wait(for p: Process, timeout: Duration) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while p.isRunning {
            if ContinuousClock.now >= deadline { return false }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return true
    }
}
