import SwiftUI

/// The menu-bar icon. It's the one view that lives as long as the app, so it's where
/// the global shortcut and the palette get the scene actions they need.
struct MenuBarIcon: View {
    let drive: Drive
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(systemName: drive.phase == .mounted ? "cloud.fill" : "cloud")
            .onAppear {
                let palette = PaletteController.shared
                palette.openSetup = { openWindow(id: "setup"); NSApp.activate() }
                palette.openSettings = { openSettings(); NSApp.activate() }
                GlobalHotKey.register { palette.toggle(drive: drive) }
            }
    }
}
