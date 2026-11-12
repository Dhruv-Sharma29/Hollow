import SwiftUI

/// The menu-bar icon. It's the one view that lives as long as the app, so it's where
/// the global shortcut and the palette get the scene actions they need.
struct MenuBarIcon: View {
    let drive: Drive
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Image(nsImage: MenuBarGlyph.image(mounted: drive.phase == .mounted))
            .onAppear {
                let palette = PaletteController.shared
                palette.drive = drive
                palette.openSetup = { openWindow(id: "setup"); BringForward.now() }
                palette.openSettings = { openSettings(); BringForward.now() }
                GlobalHotKey.register { palette.toggle() }
            }
    }
}
