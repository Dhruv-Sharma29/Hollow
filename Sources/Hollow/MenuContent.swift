import SwiftUI

struct MenuContent: View {
    let drive: Drive
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(drive.status)
        Divider()
        if !drive.signedIn {
            Button("Connect Google Drive…") { openWindow(id: "setup") }
        } else if drive.phase == .mounted {
            Button("Search Hollow…") { PaletteController.shared.show() }
            Button("Open in Finder") { drive.openInFinder() }.keyboardShortcut("o")
            Button("Unmount") { Task { await drive.unmount() } }
        } else {
            Button("Mount") { Task { await drive.mount() } }
        }
        Divider()
        SettingsLink { Text("Settings…") }.keyboardShortcut(",")
        if drive.signedIn {
            Button("Show Log") { drive.openLog() }
        }
        Divider()
        Button("Quit Hollow") {
            Task {
                if await drive.unmount() { NSApp.terminate(nil) }
            }
        }
        .keyboardShortcut("q")
    }
}
