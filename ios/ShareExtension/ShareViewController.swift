import UIKit
import UniformTypeIdentifiers
import receive_sharing_intent

/// Copies whatever was shared into the App Group container and opens Hermes,
/// where the chat composer picks it up.
///
/// This replaces the plugin's `RSIShareViewController`, which never finishes
/// when an image arrives as `Data` instead of a file URL or `UIImage`, and
/// leaves the sheet stalled. It writes the same record the plugin's app side
/// reads.
class ShareViewController: UIViewController {
    private let spinner = UIActivityIndicatorView(style: .large)

    override func viewDidLoad() {
        super.viewDidLoad()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        spinner.startAnimating()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let container = Self.inboxDirectory() else {
            extensionContext?.cancelRequest(withError: CocoaError(.fileNoSuchFile))
            return
        }
        collectFiles(into: container) { [weak self] files in
            guard let self else { return }
            if !files.isEmpty {
                Self.save(files)
                self.openHostApp()
            }
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }

    private func collectFiles(into container: URL, _ done: @escaping ([SharedMediaFile]) -> Void) {
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }

        let lock = NSLock()
        var found: [(index: Int, file: SharedMediaFile)] = []
        let group = DispatchGroup()
        for (index, provider) in providers.enumerated() {
            group.enter()
            load(provider, into: container) { file in
                if let file {
                    lock.lock()
                    found.append((index, file))
                    lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            done(found.sorted { $0.index < $1.index }.map { $0.file })
        }
    }

    private func load(
        _ provider: NSItemProvider, into container: URL,
        completion: @escaping (SharedMediaFile?) -> Void
    ) {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, _ in
                completion(Self.url(from: item).flatMap { Self.copy($0, into: container) })
            }
        } else if let type = [UTType.image, .movie].first(where: {
            provider.hasItemConformingToTypeIdentifier($0.identifier)
        }) {
            loadFile(provider, type: type, into: container, completion: completion)
        } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
                completion(Self.url(from: item).map { SharedMediaFile(path: $0.absoluteString, type: .url) })
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
                completion((item as? String).map {
                    SharedMediaFile(path: $0, mimeType: "text/plain", type: .text)
                })
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier) {
            loadFile(provider, type: .data, into: container, completion: completion)
        } else {
            completion(nil)
        }
    }

    private func loadFile(
        _ provider: NSItemProvider, type: UTType, into container: URL,
        completion: @escaping (SharedMediaFile?) -> Void
    ) {
        // The file handed to this closure is deleted when it returns, so the
        // copy has to happen inside it.
        provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
            if let file = url.flatMap({ Self.copy($0, into: container, name: provider.suggestedName) }) {
                return completion(file)
            }
            // Some apps share an in-memory image with no file behind it.
            let format = provider.registeredContentTypes.first { $0.conforms(to: type) }
            provider.loadItem(forTypeIdentifier: type.identifier) { item, _ in
                completion(Self.write(
                    item, into: container, name: provider.suggestedName,
                    fileExtension: format?.preferredFilenameExtension ?? "bin"))
            }
        }
    }

    private static func url(from item: NSSecureCoding?) -> URL? {
        switch item {
        case let url as URL: return url
        case let data as Data: return URL(dataRepresentation: data, relativeTo: nil)
        default: return nil
        }
    }

    private static func copy(_ source: URL, into container: URL, name: String? = nil) -> SharedMediaFile? {
        guard let destination = destination(in: container, name: name, fallback: source.lastPathComponent)
        else { return nil }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        do {
            try FileManager.default.copyItem(at: source, to: destination)
        } catch {
            return nil
        }
        return mediaFile(at: destination)
    }

    private static func write(
        _ item: NSSecureCoding?, into container: URL, name: String?, fileExtension: String
    ) -> SharedMediaFile? {
        let data: Data?
        var name = name
        var fallback = "Shared.\(fileExtension)"
        switch item {
        case let url as URL: return copy(url, into: container, name: name)
        case let image as UIImage:
            data = image.pngData()
            // The bytes are PNG now, whatever the suggested name says.
            name = name.map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
            fallback = "Image.png"
        case let bytes as Data: data = bytes
        default: data = nil
        }
        guard let data, let destination = destination(in: container, name: name, fallback: fallback)
        else { return nil }
        do {
            try data.write(to: destination)
        } catch {
            return nil
        }
        return mediaFile(at: destination)
    }

    /// A fresh directory per file, so two shares named `image.jpeg` don't collide.
    private static func destination(in container: URL, name: String?, fallback: String) -> URL? {
        let directory = container.appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        var fileName = name.flatMap { $0.isEmpty ? nil : $0 } ?? fallback
        let fallbackExtension = URL(fileURLWithPath: fallback).pathExtension
        if URL(fileURLWithPath: fileName).pathExtension.isEmpty, !fallbackExtension.isEmpty {
            fileName += "." + fallbackExtension
        }
        return directory.appendingPathComponent(fileName)
    }

    private static func mediaFile(at url: URL) -> SharedMediaFile {
        let type = UTType(filenameExtension: url.pathExtension)
        let kind: SharedMediaType =
            type?.conforms(to: .image) == true ? .image
            : type?.conforms(to: .movie) == true ? .video
            : .file
        return SharedMediaFile(
            path: url.absoluteString.removingPercentEncoding ?? url.absoluteString,
            mimeType: type?.preferredMIMEType ?? "application/octet-stream",
            type: kind
        )
    }

    private static var appGroupId: String? {
        Bundle.main.object(forInfoDictionaryKey: kAppGroupIdKey) as? String
    }

    /// Where shared files wait for the app. Shares older than a week were either
    /// picked up or abandoned, so they are cleared here.
    private static func inboxDirectory() -> URL? {
        guard let appGroupId,
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
        else { return nil }
        let inbox = root.appendingPathComponent("SharedInbox", isDirectory: true)
        let fileManager = FileManager.default
        let cutoff = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let old = (try? fileManager.contentsOfDirectory(
            at: inbox, includingPropertiesForKeys: [.creationDateKey])) ?? []
        for entry in old {
            let created = (try? entry.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            if let created, created < cutoff {
                try? fileManager.removeItem(at: entry)
            }
        }
        return inbox
    }

    private static func save(_ files: [SharedMediaFile]) {
        guard let appGroupId, let defaults = UserDefaults(suiteName: appGroupId),
              let data = try? JSONEncoder().encode(files)
        else { return }
        defaults.set(data, forKey: kUserDefaultsKey)
        defaults.removeObject(forKey: kUserDefaultsMessageKey)
        // The app reads this from another process as soon as it opens.
        defaults.synchronize()
    }

    /// Extensions can't call `UIApplication.shared`, but the instance is still
    /// reachable through the responder chain.
    private func openHostApp() {
        let extensionId = Bundle.main.bundleIdentifier ?? ""
        guard let dot = extensionId.lastIndex(of: "."),
              let url = URL(string: "\(kSchemePrefix)-\(extensionId[..<dot]):share")
        else { return }
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
            responder = current.next
        }
    }
}
