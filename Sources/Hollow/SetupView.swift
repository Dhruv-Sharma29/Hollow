import SwiftUI

/// The only window Hollow has: first-run setup. Everything after lives in the menu bar.
struct SetupView: View {
    let drive: Drive
    @Environment(\.dismissWindow) private var dismissWindow

    private enum Step { case welcome, signingIn, ready }

    private var step: Step {
        if drive.isSigningIn { .signingIn } else if drive.signedIn { .ready } else { .welcome }
    }

    var body: some View {
        VStack(spacing: 24) {
            header
            switch step {
            case .welcome: welcome
            case .signingIn: signingIn
            case .ready: ready
            }
        }
        .padding(32)
        .frame(width: 420)
        .onAppear { NSApp.activate() }   // menu-bar apps don't come to the front by themselves
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tint)
                .contentTransition(.symbolEffect(.replace))
            Text(title)
                .font(.title2.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var welcome: some View {
        VStack(spacing: 12) {
            if case .failed(let why) = drive.phase {
                Text(why).font(.callout).foregroundStyle(.red)
            }
            Button("Connect Google Drive") { Task { await drive.signIn() } }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(drive.rclone == nil)
            Text("Hollow can only see files it puts in your Drive.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    private var signingIn: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.small)
            Button("Cancel") { drive.cancelSignIn() }
                .keyboardShortcut(.cancelAction)
        }
    }

    private var ready: some View {
        VStack(spacing: 16) {
            Toggle("Open Hollow at login", isOn: Binding(get: { drive.opensAtLogin }, set: drive.setOpensAtLogin))
                .toggleStyle(.checkbox)
            if let error = drive.loginItemError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            HStack(spacing: 12) {
                Button("Done") { dismissWindow() }
                    .keyboardShortcut(.cancelAction)
                Button("Open in Finder") { drive.openInFinder(); dismissWindow() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(drive.phase != .mounted)
            }
            .controlSize(.large)
        }
    }

    private var icon: String {
        switch step {
        case .welcome: "externaldrive.badge.icloud"
        case .signingIn: "globe"
        case .ready: drive.phase == .mounted ? "checkmark.circle" : "externaldrive.badge.icloud"
        }
    }

    private var title: String {
        switch step {
        case .welcome: "Your Google Drive, as a disk"
        case .signingIn: "Finish in your browser"
        case .ready: drive.phase == .mounted ? "Hollow is ready" : "Almost ready"
        }
    }

    private var message: String {
        switch step {
        case .welcome: "Files stay in your Drive and open from Finder. Only the part you use is downloaded, so they take almost no space on your Mac."
        case .signingIn: "Sign in with Google in the browser window that just opened."
        case .ready: drive.phase == .mounted ? "Find it in Finder at ~/Hollow, or from the cloud in your menu bar." : drive.status
        }
    }
}
