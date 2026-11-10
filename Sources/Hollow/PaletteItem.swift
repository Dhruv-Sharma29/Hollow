import Foundation

/// One row in the command palette: an action or a file.
struct PaletteItem: Identifiable {
    enum Kind { case attention, action, file(URL) }

    let id: String
    let kind: Kind
    let title: String
    var subtitle: String?
    let symbol: String
    var shortcut: String?
    let run: @MainActor () -> Void
}
