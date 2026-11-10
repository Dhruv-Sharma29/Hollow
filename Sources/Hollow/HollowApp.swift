import SwiftUI

@main
struct HollowApp: App {
    @State private var drive = Drive()

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)   // menu bar only, no Dock icon
    }

    var body: some Scene {
        MenuBarExtra("Hollow", systemImage: drive.phase == .mounted ? "cloud.fill" : "cloud") {
            MenuContent(drive: drive)
        }

        Window("Set Up Hollow", id: "setup") {
            SetupView(drive: drive)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(drive.signedIn ? .suppressed : .presented)   // first run only
    }
}
