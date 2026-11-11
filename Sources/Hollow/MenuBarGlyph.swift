import AppKit

/// The logo's ring as a one-colour menu-bar template: thick at the lower left, thin at the
/// upper right, with the inner fold as a cut-out arc. macOS tints templates to match the bar.
@MainActor
enum MenuBarGlyph {
    /// Drawn once; the menu-bar label reads these on every update.
    static let mounted = make(mounted: true)
    static let unmounted = make(mounted: false)

    static func image(mounted: Bool) -> NSImage { mounted ? Self.mounted : unmounted }

    /// `mounted` draws the solid ring; otherwise an outline, so the state reads at a glance.
    private static func make(mounted: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let outer = NSRect(x: 1.5, y: 1.5, width: 15, height: 15)
            let hole = NSRect(x: 5.6, y: 5.0, width: 9.4, height: 9.4)    // shifted up-right: thin side there
            let fold = NSRect(x: 4.4, y: 3.6, width: 11.2, height: 11.2)  // the inner band's edge

            NSColor.black.set()
            if mounted {
                let ring = NSBezierPath(ovalIn: outer)
                ring.append(NSBezierPath(ovalIn: hole))
                ring.windingRule = .evenOdd
                ring.fill()
                // Cut the fold line so the overlapping band shows, like the logo.
                NSGraphicsContext.current?.compositingOperation = .clear
                let cut = NSBezierPath()
                cut.appendArc(withCenter: NSPoint(x: fold.midX, y: fold.midY), radius: fold.width / 2,
                              startAngle: 110, endAngle: 250)
                cut.lineWidth = 0.9
                cut.stroke()
            } else {
                let ring = NSBezierPath(ovalIn: outer.insetBy(dx: 0.6, dy: 0.6))
                ring.lineWidth = 1.2
                ring.stroke()
                let inner = NSBezierPath(ovalIn: hole)
                inner.lineWidth = 1.2
                inner.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = mounted ? "Hollow, mounted" : "Hollow, not mounted"
        return image
    }
}
