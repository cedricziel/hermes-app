import Cocoa

/// The "Ask Hermes" entry in the Services menu (`NSServices` in Info.plist).
///
/// The system hands the selected text over on a pasteboard. It is queued in
/// memory as an entry the Dart `MacosShareInbox` parses (`intent: ask`) and
/// returned with the share extension's entries by the `take` call of the
/// `hermes_app/share` channel. A service runs inside the app, so unlike the
/// share extension it needs no file in the App Group container, and the
/// selection is never written to disk.
final class AskHermesService: NSObject {
    /// The longest selection that is passed on, in characters.
    static let characterLimit = 20_000

    private var queue: [[String: Any]] = []

    /// Brings the main window to the front. Set by the app delegate.
    var showWindow: () -> Void = {}

    /// Tells Dart to `take`. Set by the app delegate; nothing happens while
    /// the channel does not exist yet, and the first `take` finds the entry.
    var notify: () -> Void = {}

    /// The service's `NSMessage`.
    @objc func askHermes(
        _ pasteboard: NSPasteboard, userData _: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        if let message = enqueue(from: pasteboard) {
            error.pointee = message as NSString
        }
    }

    /// Queues the text on [pasteboard]. Returns an error message when there
    /// is nothing usable, after queuing a `dropped` entry for Dart's
    /// breadcrumb.
    func enqueue(from pasteboard: NSPasteboard) -> String? {
        let drop = { (reason: String, message: String) -> String in
            self.queue.append(["type": "dropped", "reason": reason])
            self.notify()
            return message
        }
        guard let selection = pasteboard.string(forType: .string) else {
            return drop("no_text", "Hermes needs selected text.")
        }
        let text = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return drop("empty", "The selection is empty.")
        }
        let truncated = text.count > Self.characterLimit
        queue.append([
            "type": "text",
            "text": truncated ? String(text.prefix(Self.characterLimit)) : text,
            "intent": "ask",
            "truncated": truncated,
        ])
        showWindow()
        notify()
        return nil
    }

    /// Returns the queued entries and clears them.
    func takeQueued() -> [[String: Any]] {
        defer { queue = [] }
        return queue
    }
}
