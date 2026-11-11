import AppKit

/// Brings Hollow forward when it's launched or opened again. A menu-bar app has no
/// Dock icon or main window, so without this a second launch looks like nothing happened.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activating here, after launch finishes, is what macOS honours; earlier calls are ignored.
        NSApp.activate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate()
        PaletteController.shared.reopen()
        return false
    }
}
