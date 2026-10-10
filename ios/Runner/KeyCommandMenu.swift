import Flutter
import UIKit

/// The app's commands in the iPadOS menu bar and the list shown while ⌘ is
/// held. Dart owns what the menus say and which items are enabled (channel
/// `hermes_app/menu`); this puts them into UIKit's menu system and reports
/// back the item or key the user used.
///
/// An item is a `UIKeyCommand` (or a `UICommand` without a chord) that carries
/// its Dart command name as property list. `AppDelegate` answers
/// `canPerformAction` from `isEnabled`, so UIKit takes the chord of an enabled
/// item and leaves a disabled one's key to the app.
final class KeyCommandMenu {
  static let shared = KeyCommandMenu()

  private struct Item {
    let command: String
    let label: String
    let input: String?
    let modifiers: UIKeyModifierFlags
  }

  private struct Section {
    let id: String
    let label: String
    let groups: [[Item]]
  }

  private var sections: [Section] = []
  private var states: [String: (enabled: Bool, title: String?)] = [:]
  private var channel: FlutterMethodChannel?

  func install(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "hermes_app/menu", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      switch call.method {
      case "setLayout":
        self.sections = Self.parse(layout: call.arguments)
        UIMenuSystem.main.setNeedsRebuild()
        result(nil)
      case "setState":
        self.states = Self.parse(states: call.arguments)
        UIMenuSystem.main.setNeedsRevalidate()
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func isEnabled(_ command: String) -> Bool { states[command]?.enabled ?? false }

  func title(of command: String) -> String? { states[command]?.title }

  func invoke(_ command: String) {
    channel?.invokeMethod("invoke", arguments: command)
  }

  /// Takes out the system menus Hermes has no use for (Find would claim ⌘F),
  /// then adds the layout Dart sent.
  func build(with builder: UIMenuBuilder, action: Selector) {
    builder.remove(menu: .find)
    builder.remove(menu: .format)
    builder.remove(menu: .newScene)
    builder.remove(menu: .sidebar)
    builder.remove(menu: .toolbar)
    for section in sections {
      let groups = section.groups.map { group in
        UIMenu(
          title: "", options: .displayInline,
          children: group.map { command(for: $0, action: action) })
      }
      switch section.id {
      case "hermes":
        builder.remove(menu: .about)
        builder.remove(menu: .preferences)
        for group in groups.reversed() {
          builder.insertChild(group, atStartOfMenu: .application)
        }
      case "file":
        for group in groups.reversed() { builder.insertChild(group, atStartOfMenu: .file) }
      case "view":
        for group in groups.reversed() { builder.insertChild(group, atStartOfMenu: .view) }
      case "chat":
        builder.insertSibling(
          UIMenu(title: section.label, children: groups), afterMenu: .view)
      case "help":
        for group in groups.reversed() { builder.insertChild(group, atStartOfMenu: .help) }
      default: break
      }
    }
  }

  private func command(for item: Item, action: Selector) -> UICommand {
    if let input = item.input {
      return UIKeyCommand(
        title: item.label, image: nil, action: action, input: input,
        modifierFlags: item.modifiers, propertyList: item.command)
    }
    return UICommand(title: item.label, image: nil, action: action, propertyList: item.command)
  }

  private static func parse(layout arguments: Any?) -> [Section] {
    let sections = (arguments as? [String: Any])?["sections"] as? [[String: Any]] ?? []
    return sections.compactMap { section in
      guard let id = section["id"] as? String, let label = section["label"] as? String else {
        return nil
      }
      let groups = (section["groups"] as? [[[String: Any]]] ?? []).map { group in
        group.compactMap { item -> Item? in
          guard let command = item["command"] as? String, let label = item["label"] as? String
          else { return nil }
          let names = item["modifiers"] as? [String] ?? []
          return Item(
            command: command, label: label, input: item["input"] as? String,
            modifiers: names.reduce(into: UIKeyModifierFlags()) { flags, name in
              switch name {
              case "command": flags.insert(.command)
              case "shift": flags.insert(.shift)
              case "alternate": flags.insert(.alternate)
              case "control": flags.insert(.control)
              default: break
              }
            })
        }
      }
      return Section(id: id, label: label, groups: groups)
    }
  }

  private static func parse(states arguments: Any?) -> [String: (enabled: Bool, title: String?)] {
    let raw = (arguments as? [String: Any])?["states"] as? [String: [String: Any]] ?? [:]
    return raw.mapValues { ($0["enabled"] as? Bool ?? false, $0["title"] as? String) }
  }
}
