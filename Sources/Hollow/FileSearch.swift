import Foundation

enum FileSearch {
    /// Name search under the mount. Off the main actor because every directory read
    /// goes through rclone to Google. Returns up to `limit` matches, folders included.
    @concurrent
    static func run(_ query: String, in root: URL, limit: Int = 40) async -> [URL] {
        guard !query.isEmpty,
              let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles, .skipsPackageDescendants])
        else { return [] }
        var hits: [URL] = []
        // ponytail: walks the whole tree per keystroke; fine for drive.file's small tree,
        // swap for rclone's cached listing if trees get big.
        while let url = walker.nextObject() as? URL {
            if Task.isCancelled { return [] }
            if url.lastPathComponent.localizedStandardContains(query) {
                hits.append(url)
                if hits.count == limit { break }
            }
        }
        return hits
    }
}
