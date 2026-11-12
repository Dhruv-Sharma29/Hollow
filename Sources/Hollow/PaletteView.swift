import SwiftUI

/// ⌃⌥H: search the Drive or run an action, keyboard first.
struct PaletteView: View {
    let drive: Drive
    let close: () -> Void
    let openSetup: () -> Void
    let openSettings: () -> Void

    @State private var query = ""
    @State private var files: [URL] = []
    @State private var selection = 0
    @State private var importing = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            results
            Divider()
            footer
        }
        .frame(width: 640, height: 460)
        .background(.background)
        .clipShape(.rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.separator))   // edge for a borderless panel
        .onAppear { searchFocused = true }
        .onChange(of: query) { selection = 0 }
        .task(id: query) {
            guard let root = drive.rclone?.mountPoint, drive.phase == .mounted else { files = []; return }
            try? await Task.sleep(for: .milliseconds(150))   // let typing settle
            files = await FileSearch.run(query, in: root)
        }
        .onKeyPress(.downArrow) { move(1) }
        .onKeyPress(.upArrow) { move(-1) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { Task { await drive.add(urls) } }
        }
    }

    // MARK: Pieces

    private var header: some View {
        ZStack {
            HollowScene()
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.8), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                TextField("Search your Drive or run a command", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .focused($searchFocused)
                    .onSubmit { runSelected(revealing: false) }
            }
            .padding(.horizontal, 20)
            .frame(height: 52)
            .background(.regularMaterial, in: .capsule)
            .padding(.horizontal, 16)
        }
        .frame(height: 104)
    }

    private var results: some View {
        let sections = self.sections
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(sections, id: \.title) { section in
                        Text(section.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.fill.tertiary, in: .capsule)
                            .padding(.horizontal, 8)
                            .padding(.top, 8)
                        ForEach(section.rows, id: \.item.id) { row in
                            // A real button, so VoiceOver and Full Keyboard Access can use each row.
                            Button {
                                selection = row.index
                                runSelected(revealing: false)
                            } label: {
                                PaletteRow(item: row.item, selected: row.index == selection)
                            }
                            .buttonStyle(.plain)
                            .id(row.item.id)
                        }
                    }
                    if sections.isEmpty {
                        Text("Nothing matches \u{201C}\(query)\u{201D}")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selection) { _, i in
                let flat = sections.flatMap(\.rows)
                if flat.indices.contains(i) { proxy.scrollTo(flat[i].item.id) }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(drive.phase == .mounted ? .green : .orange)
                .frame(width: 8, height: 8)
            Text(drive.status)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button { runSelected(revealing: false) } label: {
                HStack(spacing: 8) {
                    Text(primaryLabel)
                    Image(systemName: "return")
                }
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(flat.isEmpty)
            Divider().frame(height: 20)
            Group {
                Button("Settings", systemImage: "gearshape") { close(); openSettings() }
                    .help("Settings")
                Button("Quit Hollow", systemImage: "power") {
                    Task { if await drive.unmount() { NSApp.terminate(nil) } }
                }
                .help("Quit Hollow")
            }
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)   // VoiceOver still reads the titles
        }
        .font(.body)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            // Hidden buttons give the palette its keyboard shortcuts.
            Group {
                Button("") { runSelected(revealing: true) }   // ⌘↩ reveals instead of opening
                    .keyboardShortcut(.return, modifiers: .command)
                Button("") { if drive.phase == .mounted { close(); drive.openInFinder() } }
                    .keyboardShortcut("o")
                Button("") { close(); openSettings() }
                    .keyboardShortcut(",")
            }
            .hidden()
        }
    }

    /// The footer button names what Return will do to the selected row.
    private var primaryLabel: String {
        guard flat.indices.contains(selection) else { return "Open" }
        return switch flat[selection].id {
        case "connect": "Connect"
        case "retry": "Retry"
        case "quit": "Quit"
        default: "Open"
        }
    }

    // MARK: Data

    private struct Row { let index: Int; let item: PaletteItem }
    private struct Section { let title: String; let rows: [Row] }

    /// Built once per update. Each row knows its position, so selection needs no searching.
    private var sections: [Section] {
        let q = query
        let matches: (PaletteItem) -> Bool = { q.isEmpty || $0.title.localizedStandardContains(q) }
        let groups: [(String, [PaletteItem])] = [
            ("Needs attention", attentionItems.filter(matches)),
            ("Files", files.map(fileItem)),
            ("Actions", actionItems.filter(matches)),
        ]
        var out: [Section] = []
        var next = 0
        for (title, items) in groups where !items.isEmpty {
            out.append(Section(title: title, rows: items.enumerated().map { Row(index: next + $0.offset, item: $0.element) }))
            next += items.count
        }
        return out
    }

    private var flat: [PaletteItem] { sections.flatMap(\.rows).map(\.item) }

    private var attentionItems: [PaletteItem] {
        if !drive.signedIn {
            return [PaletteItem(id: "connect", kind: .attention, title: "Connect Google Drive",
                                subtitle: "Hollow isn't connected yet", symbol: "exclamationmark.icloud") {
                close(); openSetup()
            }]
        }
        if case .failed(let why) = drive.phase {
            return [PaletteItem(id: "retry", kind: .attention, title: "Mount again", subtitle: why,
                                symbol: "exclamationmark.icloud") { Task { await drive.mount() } }]
        }
        return []
    }

    private var actionItems: [PaletteItem] {
        var items: [PaletteItem] = []
        if drive.phase == .mounted {
            items.append(PaletteItem(id: "finder", kind: .action, title: "Open Hollow in Finder",
                                     symbol: "folder", shortcut: "⌘O") { close(); drive.openInFinder() })
            items.append(PaletteItem(id: "add", kind: .action, title: "Add files…",
                                     subtitle: "Copy files into your Drive", symbol: "plus") { importing = true })
        }
        items.append(PaletteItem(id: "settings", kind: .action, title: "Settings…",
                                 symbol: "gearshape", shortcut: "⌘,") { close(); openSettings() })
        items.append(PaletteItem(id: "tour", kind: .action, title: "Take the tour again",
                                 symbol: "sparkles") { close(); openSetup() })
        if drive.signedIn {
            items.append(PaletteItem(id: "log", kind: .action, title: "Show log",
                                     symbol: "doc.text") { close(); drive.openLog() })
        }
        items.append(PaletteItem(id: "quit", kind: .action, title: "Quit Hollow", symbol: "power") {
            Task { if await drive.unmount() { NSApp.terminate(nil) } }
        })
        return items
    }

    private func fileItem(_ url: URL) -> PaletteItem {
        let parent = url.deletingLastPathComponent().path.replacing(drive.rclone?.mountPoint.path ?? "", with: "Hollow")
        return PaletteItem(id: url.path, kind: .file(url), title: url.lastPathComponent, subtitle: parent,
                           symbol: url.hasDirectoryPath ? "folder" : "doc") {
            close(); NSWorkspace.shared.open(url)
        }
    }

    // MARK: Actions

    private func move(_ delta: Int) -> KeyPress.Result {
        guard !flat.isEmpty else { return .handled }
        selection = min(max(selection + delta, 0), flat.count - 1)
        return .handled
    }

    private func runSelected(revealing: Bool) {
        guard flat.indices.contains(selection) else { return }
        let item = flat[selection]
        if revealing, case .file(let url) = item.kind {
            close()
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            item.run()
        }
    }
}
