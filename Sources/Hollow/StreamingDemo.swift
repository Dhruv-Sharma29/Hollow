import SwiftUI

/// Tour page 2: a big film whose bar only ever holds the slice being watched.
struct StreamingDemo: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            // Loops every 6 s; with Reduce Motion the slice sits still mid-bar.
            let playhead = reduceMotion ? 0.4 : (t / 6).truncatingRemainder(dividingBy: 1)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "film")
                    Text("summer-film.mov")
                    Spacer()
                    Text("48 GB").foregroundStyle(.secondary)
                }
                .font(.callout)

                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(.fill.tertiary)
                        Capsule()
                            .fill(.tint)
                            .frame(width: w * 0.12)
                            .offset(x: (w * 0.88) * playhead)
                    }
                }
                .frame(height: 8)

                Text("0 bytes on disk. Only this slice is downloaded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(width: 300)
            .background(.regularMaterial, in: .rect(cornerRadius: 12))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A 48 gigabyte film where only the part being watched is downloaded.")
    }
}
