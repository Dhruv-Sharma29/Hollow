import SwiftUI

struct MenuContent: View {
    let drive: Drive
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text(drive.status)
        Divider()
        if !drive.signedIn {
            Button("Set Up Hollow…") { openWindow(id: "setup") }
        } else if drive.phase == .mounted {
            Button("Open in Finder") { drive.openInFinder() }.keyboardShortcut("o")
            Button("Unmount") { Task { await drive.unmount() } }
        } else {
            Button("Mount") { drive.mount() }
        }
        if drive.signedIn {
            Button("Show Log") { drive.openLog() }
            Button("Sign Out") { Task { await drive.signOut() } }
        }
        Divider()
        Button("Quit Hollow") {
            Task {
                await drive.unmount()
                NSApp.terminate(nil)
            }
        }
        .keyboardShortcut("q")
    }
}
