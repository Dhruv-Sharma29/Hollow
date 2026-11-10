import AppKit
import SwiftUI

/// Spotlight-style floating panel. `.nonactivatingPanel` lets it take keystrokes without
/// pulling Hollow to the front, which macOS won't reliably do for a menu-bar app.
final class PalettePanel: NSPanel {
    override var canBecomeKey: Bool { true }

    init() {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                   backing: .buffered, defer: true)
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        backgroundColor = .clear
        hasShadow = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override func resignKey() {
        super.resignKey()
        orderOut(nil)   // click elsewhere = dismiss, like Spotlight
    }

    override func cancelOperation(_ sender: Any?) { orderOut(nil) }   // Esc
}

/// Owns the one palette panel. The menu-bar icon hands it the SwiftUI actions
/// (open the tour, open Settings) that only exist inside the scene graph.
@MainActor
final class PaletteController {
    static let shared = PaletteController()

    private var panel: PalettePanel?
    var openSetup: () -> Void = {}
    var openSettings: () -> Void = {}

    func toggle(drive: Drive) {
        if let panel, panel.isVisible { panel.orderOut(nil); return }
        show(drive: drive)
    }

    func show(drive: Drive) {
        let panel = panel ?? PalettePanel()
        self.panel = panel
        // A fresh view each time resets the query and selection.
        panel.contentView = NSHostingView(rootView: PaletteView(
            drive: drive,
            close: { [weak panel] in panel?.orderOut(nil) },
            openSetup: openSetup,
            openSettings: openSettings
        ))
        panel.setContentSize(panel.contentView!.fittingSize)
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameTopLeftPoint(NSPoint(x: screen.midX - panel.frame.width / 2,
                                               y: screen.maxY - screen.height * 0.2))
        }
        panel.makeKeyAndOrderFront(nil)
    }
}
