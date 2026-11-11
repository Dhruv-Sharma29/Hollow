import AppKit
import SwiftUI

/// Owns the one palette panel. The menu-bar icon hands it the SwiftUI actions
/// (open the tour, open Settings) that only exist inside the scene graph.
@MainActor
final class PaletteController {
    static let shared = PaletteController()

    private var panel: PalettePanel?
    var drive: Drive?
    var openSetup: () -> Void = {}
    var openSettings: () -> Void = {}

    func toggle() {
        if let panel, panel.isVisible { panel.orderOut(nil); return }
        show()
    }

    /// Opening Hollow again (Finder, Launchpad, Spotlight) should show something:
    /// the tour until you're connected, the palette after.
    func reopen() {
        guard let drive else { return }
        if drive.signedIn { show() } else { openSetup() }
    }

    func show() {
        guard let drive else { return }
        let panel = panel ?? PalettePanel()
        self.panel = panel
        // A fresh view each time resets the query and selection.
        let host = NSHostingView(rootView: PaletteView(
            drive: drive,
            close: { [weak panel] in panel?.orderOut(nil) },
            openSetup: openSetup,
            openSettings: openSettings
        ))
        panel.contentView = host
        panel.setContentSize(host.fittingSize)
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameTopLeftPoint(NSPoint(x: screen.midX - panel.frame.width / 2,
                                               y: screen.maxY - screen.height * 0.2))
        }
        panel.makeKeyAndOrderFront(nil)
    }
}
