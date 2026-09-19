import Foundation

/// The on-disk hand-off between the share extension and the app, kept in
/// the App Group container. Compiled into both targets so the path and the
/// entry format live in one place.
///
/// Each entry is what `MacosShareInbox` parses on the Dart side:
/// `{type: "text", text}` or `{type: "file", path, name, mimeType?, isImage}`.
enum ShareHandoff {
    static let urlScheme = "hermes-share"

    private static let staleAfter: TimeInterval = 7 * 24 * 60 * 60

    private static var shareDirectory: URL? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "AppGroupId") as? String,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
        else { return nil }
        return container.appendingPathComponent("share", isDirectory: true)
    }

    private static var pendingFile: URL? {
        shareDirectory?.appendingPathComponent("pending.json")
    }

    /// A fresh directory to copy one shared file into.
    static func makeFileDirectory() -> URL? {
        guard let directory = shareDirectory?.appendingPathComponent(UUID().uuidString, isDirectory: true)
        else { return nil }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func append(_ entries: [[String: Any]]) {
        guard let file = pendingFile, !entries.isEmpty else { return }
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let all = read(file) + entries
        if let data = try? JSONSerialization.data(withJSONObject: all) {
            try? data.write(to: file, options: .atomic)
        }
    }

    /// Returns the pending entries and clears them.
    static func take() -> [[String: Any]] {
        guard let file = pendingFile else { return [] }
        let entries = read(file)
        try? FileManager.default.removeItem(at: file)
        removeStaleFiles()
        return entries
    }

    private static func read(_ file: URL) -> [[String: Any]] {
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return [] }
        return json
    }

    private static func removeStaleFiles() {
        guard let directory = shareDirectory,
              let children = try? FileManager.default.contentsOfDirectory(
                  at: directory, includingPropertiesForKeys: [.creationDateKey]
              )
        else { return }
        let cutoff = Date().addingTimeInterval(-staleAfter)
        for child in children where child.hasDirectoryPath {
            let created = (try? child.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            if let created, created < cutoff {
                try? FileManager.default.removeItem(at: child)
            }
        }
    }
}
