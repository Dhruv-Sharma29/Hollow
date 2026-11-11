import AppKit

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
