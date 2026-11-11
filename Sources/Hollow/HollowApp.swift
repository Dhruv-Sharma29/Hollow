import SwiftUI

@main
struct HollowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var drive = Drive()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(drive: drive)
        } label: {
            MenuBarIcon(drive: drive)
        }

        Window("Welcome to Hollow", id: "setup") {
            OnboardingView(drive: drive)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(drive.signedIn ? .suppressed : .presented)   // first run only

        Settings {
            SettingsView(drive: drive)
        }
    }
}
