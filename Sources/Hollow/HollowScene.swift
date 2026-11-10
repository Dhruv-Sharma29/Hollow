import SwiftUI

/// Hollow's illustration: layered hills under a moon at dusk, drawn in code so it stays
/// sharp at any size and follows light and dark mode. Used in the palette header and tour.
struct HollowScene: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { ctx, size in
            let dark = scheme == .dark
            let w = size.width, h = size.height

            // Sky
            let sky = dark
                ? [Color(red: 0.08, green: 0.09, blue: 0.20), Color(red: 0.27, green: 0.20, blue: 0.40)]
                : [Color(red: 0.74, green: 0.82, blue: 0.97), Color(red: 0.99, green: 0.87, blue: 0.80)]
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .linearGradient(Gradient(colors: sky), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

            // Stars (fixed positions, so the scene is the same every time)
            if dark {
                for (x, y) in [(0.12, 0.18), (0.27, 0.09), (0.41, 0.22), (0.58, 0.12), (0.66, 0.30), (0.88, 0.16), (0.07, 0.34), (0.50, 0.05)] {
                    ctx.fill(Path(ellipseIn: CGRect(x: w * x, y: h * y, width: 2, height: 2)), with: .color(.white.opacity(0.7)))
                }
            }

            // Moon with a soft glow
            let r = min(w, h) * 0.13
            let moon = CGPoint(x: w * 0.78, y: h * 0.30)
            ctx.fill(Path(ellipseIn: CGRect(x: moon.x - r * 2.2, y: moon.y - r * 2.2, width: r * 4.4, height: r * 4.4)),
                     with: .radialGradient(Gradient(colors: [.white.opacity(dark ? 0.25 : 0.45), .white.opacity(0)]),
                                           center: moon, startRadius: r, endRadius: r * 2.2))
            ctx.fill(Path(ellipseIn: CGRect(x: moon.x - r, y: moon.y - r, width: r * 2, height: r * 2)),
                     with: .color(dark ? Color(red: 0.98, green: 0.95, blue: 0.86) : .white))

            // Three hill layers, back to front
            let hills: [(base: Double, amp: Double, phase: Double, light: Color, dark: Color)] = [
                (0.62, 0.10, 0.3, Color(red: 0.62, green: 0.66, blue: 0.86), Color(red: 0.22, green: 0.20, blue: 0.40)),
                (0.74, 0.08, 1.9, Color(red: 0.47, green: 0.55, blue: 0.80), Color(red: 0.15, green: 0.15, blue: 0.31)),
                (0.86, 0.06, 3.4, Color(red: 0.33, green: 0.42, blue: 0.70), Color(red: 0.10, green: 0.10, blue: 0.22)),
            ]
            for hill in hills {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: h))
                let steps = 48
                for i in 0...steps {
                    let x = w * Double(i) / Double(steps)
                    let t = Double(i) / Double(steps) * .pi * 2
                    let y = h * (hill.base - hill.amp * (sin(t + hill.phase) * 0.6 + sin(t * 2.3 + hill.phase) * 0.4))
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                path.addLine(to: CGPoint(x: w, y: h))
                path.closeSubpath()
                ctx.fill(path, with: .color(dark ? hill.dark : hill.light))
            }
        }
        .accessibilityHidden(true)
    }
}
