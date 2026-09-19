import Cocoa
import UniformTypeIdentifiers

/// Copies whatever was shared into the App Group container and opens Hermes,
/// where the chat composer picks it up.
class ShareViewController: NSViewController {
    override func loadView() {
        view = NSView(frame: .zero)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        collectEntries { [weak self] entries in
            ShareHandoff.append(entries)
            if let url = URL(string: "\(ShareHandoff.urlScheme)://share") {
                NSWorkspace.shared.open(url)
            }
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func collectEntries(_ done: @escaping ([[String: Any]]) -> Void) {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        let lock = NSLock()
        var found: [(index: Int, entry: [String: Any])] = []
        let group = DispatchGroup()
        for (index, provider) in providers.enumerated() {
            group.enter()
            load(provider) { entry in
                if let entry {
                    lock.lock()
                    found.append((index, entry))
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            done(found.sorted { $0.index < $1.index }.map { $0.entry })
        }
    }

    private func load(_ provider: NSItemProvider, completion: @escaping ([String: Any]?) -> Void) {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                guard let url = Self.url(from: item) else { return completion(nil) }
                completion(Self.fileEntry(copying: url))
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                completion(Self.url(from: item).map { ["type": "text", "text": $0.absoluteString] })
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            // The file handed to this closure is deleted when it returns, so the
            // copy has to happen inside it.
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
                completion(url.flatMap { Self.fileEntry(copying: $0) })
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                completion((item as? String).map { ["type": "text", "text": $0] })
            }
        } else {
            completion(nil)
        }
    }

    private static func url(from item: NSSecureCoding?) -> URL? {
        switch item {
        case let url as URL: return url
        case let data as Data: return URL(dataRepresentation: data, relativeTo: nil)
        default: return nil
        }
    }

    private static func fileEntry(copying source: URL) -> [String: Any]? {
        guard let directory = ShareHandoff.makeFileDirectory() else { return nil }
        let destination = directory.appendingPathComponent(source.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            return nil
        }
        let type = UTType(filenameExtension: destination.pathExtension)
        var entry: [String: Any] = [
            "type": "file",
            "path": destination.path,
            "name": destination.lastPathComponent,
            "isImage": type?.conforms(to: .image) ?? false,
        ]
        if let mimeType = type?.preferredMIMEType {
            entry["mimeType"] = mimeType
        }
        return entry
    }
}
