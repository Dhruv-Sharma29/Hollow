import SwiftUI

/// One palette row: icon tile, title, optional subtitle and shortcut.
struct PaletteRow: View {
    let item: PaletteItem
    let selected: Bool

    private var isAttention: Bool {
        if case .attention = item.kind { true } else { false }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbol)
                .frame(width: 28, height: 28)
                .foregroundStyle(isAttention ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
                .background(.fill.tertiary, in: .rect(cornerRadius: 8))
                .accessibilityHidden(true)
            Text(item.title)
            if let subtitle = item.subtitle {
                Text(subtitle)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if let shortcut = item.shortcut {
                Text(shortcut)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.fill.tertiary, in: .capsule)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(selected ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 12))
        .contentShape(.rect)
    }
}
