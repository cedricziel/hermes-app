import Cocoa
import FlutterMacOS
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
  /// No default chord: the user records one in Settings.
  static let quickPanel = Self("quickPanel")
}

/// The quick panel's global shortcut, in the main engine only. Each press
/// goes to Dart, which decides whether it shows the panel or the main
/// window. KeyboardShortcuts keeps the chord in user defaults; Dart only
/// learns whether one is set.
@MainActor
final class QuickPanelShortcut: NSObject {
  private static var shared: QuickPanelShortcut?

  private let channel: FlutterMethodChannel

  static func register(with registrar: FlutterPluginRegistrar) {
    let shortcut = QuickPanelShortcut(messenger: registrar.messenger)
    registrar.register(
      ShortcutRecorderFactory(shortcut), withId: "hermes_app/shortcut_recorder")
    shared = shortcut
  }

  private init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "hermes_app/quick_panel", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isSet":
        result(KeyboardShortcuts.getShortcut(for: .quickPanel) != nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    KeyboardShortcuts.onKeyDown(for: .quickPanel) { [weak self] in
      self?.channel.invokeMethod("pressed", arguments: nil)
    }
  }

  fileprivate func changed(set: Bool) {
    channel.invokeMethod("changed", arguments: set)
  }
}

/// Makes the package's recorder for Settings' Quick panel row. The recorder
/// stores the chord itself and warns about clashes with system shortcuts and
/// the menu bar.
private final class ShortcutRecorderFactory: NSObject, FlutterPlatformViewFactory {
  private weak var shortcut: QuickPanelShortcut?

  init(_ shortcut: QuickPanelShortcut) {
    self.shortcut = shortcut
  }

  /// Flutter asks for platform views on the main thread.
  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    MainActor.assumeIsolated {
      KeyboardShortcuts.RecorderCocoa(for: .quickPanel) { [weak shortcut] chord in
        shortcut?.changed(set: chord != nil)
      }
    }
  }

  func createArgsCodec() -> (any FlutterMessageCodec & NSObjectProtocol)? { nil }
}
