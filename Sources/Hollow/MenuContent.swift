import SwiftUI

struct MenuContent: View {
    let drive: Drive
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Text(drive.status)
        Divider()
        if !drive.signedIn {
            Button("Connect Google Drive…", action: showSetup)
        } else if drive.phase == .mounted {
            Button("Search Hollow…") { PaletteController.shared.show() }
            Button("Open in Finder", action: drive.openInFinder).keyboardShortcut("o")
            Button("Unmount") { Task { await drive.unmount() } }
        } else {
            Button("Mount") { Task { await drive.mount() } }
        }
        Divider()
        // A Button rather than SettingsLink, so Hollow can come forward with the window.
        Button("Settings…", action: showSettings).keyboardShortcut(",")
        if drive.signedIn {
            Button("Show Log", action: drive.openLog)
        }
        Divider()
        Button("Quit Hollow", action: quit).keyboardShortcut("q")
    }

    private func showSetup() {
        openWindow(id: "setup")
        BringForward.now()
    }

    private func showSettings() {
        openSettings()
        BringForward.now()
    }

    private func quit() {
        Task {
            if await drive.unmount() { NSApp.terminate(nil) }
        }
    }
}
