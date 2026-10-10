import Cocoa
import FlutterMacOS

/// The menu of the Dock icon: New Chat, the latest chats, Show Main Window.
///
/// AppKit asks for the menu synchronously, so Dart pushes what it should
/// show (`dockMenu` on the app channel) and this keeps it in memory only.
/// Chat titles are held while the connection is ready and the app unlocked;
/// any other state, or an argument that does not parse, clears them.
final class DockMenu: NSObject {
    enum State: String {
        case off, locked, ready
    }

    struct Chat: Equatable {
        let id: String
        let profile: String
        let title: String
    }

    static let maxChats = 5

    private(set) var state = State.off
    private(set) var chats: [Chat] = []

    /// Brings the main window forward, also when it is closed or hidden.
    var showWindow: () -> Void = {}

    /// Reports a choice to Dart: `dockNewChat` or `dockOpenChat`.
    var send: (String, Any?) -> Void = { _, _ in }

    /// The method Dart calls on the app channel to replace the menu's content.
    static let updateMethod = "dockMenu"

    /// Replaces the menu's content with Dart's snapshot.
    func update(_ arguments: Any?) {
        guard let map = arguments as? [String: Any],
              let name = map["state"] as? String,
              let next = State(rawValue: name)
        else {
            clear()
            return
        }
        guard next == .ready else {
            state = next
            chats = []
            return
        }
        var parsed: [Chat] = []
        for case let entry as [String: Any] in (map["chats"] as? [Any]) ?? [] {
            guard let id = entry["id"] as? String, let profile = entry["profile"] as? String,
                  let title = entry["title"] as? String
            else { continue }
            parsed.append(Chat(id: id, profile: profile, title: title))
        }
        state = next
        chats = Array(parsed.prefix(Self.maxChats))
    }

    func clear() {
        state = .off
        chats = []
    }

    /// Builds the menu from the current snapshot. Titles are plain item
    /// titles: no format string, no key equivalent.
    func menu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        if state != .off {
            menu.addItem(item("New Chat", #selector(newChat(_:))))
        }
        if state == .ready {
            for chat in chats {
                let entry = item(chat.title, #selector(openChat(_:)))
                entry.representedObject = [chat.id, chat.profile]
                menu.addItem(entry)
            }
        }
        if menu.numberOfItems > 0 { menu.addItem(.separator()) }
        menu.addItem(item("Show Main Window", #selector(showMain(_:))))
        return menu
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        return entry
    }

    @objc private func newChat(_: NSMenuItem) {
        // The main window must be up for the unlock prompt and the new chat.
        showWindow()
        send("dockNewChat", nil)
    }

    /// Dart brings up the chat's own window when it has one, else the main
    /// window, so the main window is not raised here.
    @objc private func openChat(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String], pair.count == 2 else { return }
        send("dockOpenChat", ["id": pair[0], "profile": pair[1]])
    }

    @objc private func showMain(_: NSMenuItem) {
        showWindow()
    }
}
