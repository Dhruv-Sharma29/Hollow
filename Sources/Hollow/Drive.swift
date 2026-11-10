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

    init() {
        let support = URL.applicationSupportDirectory.appending(path: "Hollow")
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        rclone = Rclone.find().map {
            Rclone(binary: $0, support: support, mountPoint: URL.homeDirectory.appending(path: "Hollow"))
        }
        guard let rclone else { phase = .failed("rclone not found. Run: brew install rclone"); return }
        signedIn = rclone.isSignedIn()
        if signedIn { mount() }
    }

    var status: String {
        switch phase {
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
        mount()
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

    func mount() {
        guard let rclone, mountProcess == nil else { return }
        // A crash can leave a dead NFS mount behind, which hangs Finder. Clear it before
        // touching the folder, because even a stat on a dead mount can block.
        if isMountPoint(rclone.mountPoint) { Self.forceUnmount(rclone.mountPoint) }
        let fm = FileManager.default
        try? fm.createDirectory(at: rclone.mountPoint, withIntermediateDirectories: true)
        try? fm.createDirectory(at: rclone.cache, withIntermediateDirectories: true)

        let p = Process()
        p.executableURL = rclone.binary
        p.arguments = rclone.mountArgs()
        p.terminationHandler = { proc in
            let code = proc.terminationStatus
            Task { @MainActor in self.mountEnded(code) }
        }
        do { try p.run() } catch { phase = .failed("Couldn't start rclone: \(error.localizedDescription)"); return }
        mountProcess = p
        phase = .busy("Mounting…")

        Task {
            for _ in 0..<40 {
                guard mountProcess === p else { return }   // rclone exited; mountEnded reports why
                if isMountPoint(rclone.mountPoint) { phase = .mounted; return }
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard mountProcess === p else { return }
            phase = .failed("Mount timed out, see rclone.log")
            p.terminate()   // so Mount can be tried again

        }
    }

    /// SIGTERM makes rclone unmount cleanly and exit. The wait happens off the main actor,
    /// so the menu stays responsive.
    func unmount() async {
        guard let p = mountProcess else { return }
        phase = .busy("Unmounting…")
        p.terminate()
        await Self.waitForExit(p)
    }

    func signOut() async {
        await unmount()
        signInProcess?.terminate()
        guard let rclone else { return }
        try? FileManager.default.removeItem(at: rclone.config)
        // ponytail: the cache is kept on purpose. It can hold writes rclone hasn't uploaded yet,
        // and rclone uploads them on the next mount. Deleting it here could lose files.
        signedIn = false
        phase = .idle
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

    @concurrent private static func waitForExit(_ p: Process) async {
        p.waitUntilExit()
    }

    private static func forceUnmount(_ url: URL) {
        let p = Process()
        p.executableURL = URL(filePath: "/sbin/umount")
        p.arguments = ["-f", url.path]
        try? p.run()
        p.waitUntilExit()
    }
}
