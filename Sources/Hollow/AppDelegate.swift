import AppKit

/// Brings Hollow forward when it's launched or opened again. A menu-bar app has no
/// Dock icon or main window, so without this a second launch looks like nothing happened.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Activating here, after launch finishes, is what macOS honours; earlier calls are ignored.
        BringForward.now()
    }

    /// hollow://open, from the "Back to Hollow" button on the sign-in page.
    func application(_ application: NSApplication, open urls: [URL]) {
        BringForward.now()
    }

    /// Don't leave a half-finished sign-in behind: it would hold rclone's callback port.
    func applicationWillTerminate(_ notification: Notification) {
        PaletteController.shared.drive?.cancelSignIn()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PaletteController.shared.reopen()   // the tour or palette, each brought to the front
        return false
    }
}
