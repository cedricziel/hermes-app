import Cocoa
import FlutterMacOS
import desktop_drop
import desktop_multi_window
import file_picker_darwin
import file_selector_macos
import open_file_mac
import pasteboard
import shared_preferences_foundation
import url_launcher_macos

class MainFlutterWindow: NSWindow {
  private var keyObserver: WindowKeyObserver?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    Self.registerClipboard(messenger: flutterViewController.engine.binaryMessenger)

    // Closing the main window hides it: its engine owns the session that
    // conversation windows borrow, and ⌘0 brings it back.
    isReleasedWhenClosed = false

    let channel = FlutterMethodChannel(
      name: "hermes_app/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "startDrag":
        if let event = NSApp.currentEvent {
          self?.performDrag(with: event)
        }
        result(nil)
      case "show":
        self?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    keyObserver = WindowKeyObserver(window: self, channel: channel)

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      ConversationWindow.attach(to: controller)
    }

    super.awakeFromNib()
  }

  /// Answers the composer's question for the files on the clipboard, in
  /// every engine that shows one.
  static func registerClipboard(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "hermes_app/clipboard", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "files" else {
          result(FlutterMethodNotImplemented)
          return
        }
        result(clipboardFilePaths(from: .general))
      }
  }

  static func clipboardFilePaths(from pasteboard: NSPasteboard) -> [String] {
    let urls = pasteboard.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]
    ) ?? []
    return urls.compactMap { object in
      guard let url = object as? NSURL, url.isFileURL else { return nil }
      return url.path
    }
  }
}

/// Tells an engine when its window becomes or stops being the key window.
final class WindowKeyObserver {
  private var observers: [NSObjectProtocol] = []

  init(window: NSWindow, channel: FlutterMethodChannel) {
    let center = NotificationCenter.default
    observers = [
      center.addObserver(
        forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
      ) { _ in channel.invokeMethod("keyChanged", arguments: true) },
      center.addObserver(
        forName: NSWindow.didResignKeyNotification, object: window, queue: .main
      ) { _ in channel.invokeMethod("keyChanged", arguments: false) },
    ]
  }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
  }
}

/// A window desktop_multi_window opened for one chat, with its own engine.
final class ConversationWindow: NSObject {
  private static var open: [ObjectIdentifier: ConversationWindow] = [:]

  private weak var window: NSWindow?
  private weak var controller: FlutterViewController?
  private let channel: FlutterMethodChannel
  private var keyObserver: WindowKeyObserver?
  private var closeObserver: NSObjectProtocol?

  static func attach(to controller: FlutterViewController) {
    registerPlugins(controller)
    MainFlutterWindow.registerClipboard(messenger: controller.engine.binaryMessenger)
    guard let window = controller.view.window else { return }
    let conversation = ConversationWindow(window: window, controller: controller)
    open[ObjectIdentifier(window)] = conversation
  }

  /// Only what a conversation needs. Left out on purpose: secure storage
  /// (the window never reads tokens), notifications (the plugin takes the
  /// notification centre's delegate), local_auth, connectivity, device and
  /// package info, and macos_window_utils (a static bound to the main
  /// window).
  private static func registerPlugins(_ registry: FlutterPluginRegistry) {
    DesktopDropPlugin.register(with: registry.registrar(forPlugin: "DesktopDropPlugin"))
    FilePickerPlugin.register(with: registry.registrar(forPlugin: "FilePickerPlugin"))
    FileSelectorPlugin.register(with: registry.registrar(forPlugin: "FileSelectorPlugin"))
    OpenFilePlugin.register(with: registry.registrar(forPlugin: "OpenFilePlugin"))
    PasteboardPlugin.register(with: registry.registrar(forPlugin: "PasteboardPlugin"))
    SharedPreferencesPlugin.register(
      with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
    UrlLauncherPlugin.register(with: registry.registrar(forPlugin: "UrlLauncherPlugin"))
  }

  private init(window: NSWindow, controller: FlutterViewController) {
    self.window = window
    self.controller = controller
    channel = FlutterMethodChannel(
      name: "hermes_app/window", binaryMessenger: controller.engine.binaryMessenger)
    super.init()
    configure(window)
    keyObserver = WindowKeyObserver(window: window, channel: channel)
    closeObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification, object: window, queue: .main
    ) { _ in
      ConversationWindow.open.removeValue(forKey: ObjectIdentifier(window))
    }
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result) ?? result(nil)
    }
  }

  deinit {
    if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
  }

  private func configure(_ window: NSWindow) {
    window.styleMask.insert(.fullSizeContentView)
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    let toolbar = NSToolbar(identifier: "ConversationToolbar")
    toolbar.allowsUserCustomization = false
    toolbar.showsBaselineSeparator = false
    window.toolbar = toolbar
    window.toolbarStyle = .unified
    window.tabbingMode = .disallowed
    window.minSize = NSSize(width: 480, height: 420)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let window else { return result(nil) }
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "titlebarHeight":
      result(window.frame.height - window.contentLayoutRect.height)
    case "present":
      window.title = args["title"] as? String ?? ""
      let name = args["frame_name"] as? String ?? ""
      if name.isEmpty || !window.setFrameUsingName(name) {
        place(window)
      }
      if !name.isEmpty { window.setFrameAutosaveName(name) }
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      result(nil)
    case "setTitle":
      window.title = call.arguments as? String ?? ""
      result(nil)
    case "setAppearance":
      let dark = call.arguments as? Bool ?? false
      window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
      result(nil)
    case "startDrag":
      if let event = NSApp.currentEvent { window.performDrag(with: event) }
      result(nil)
    case "close":
      window.close()
      result(nil)
    case "share":
      share(args)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// A window with no saved frame opens beside the main window.
  private func place(_ window: NSWindow) {
    let size = NSSize(width: 760, height: 760)
    guard let main = NSApp.windows.first(where: { $0 is MainFlutterWindow }) else {
      window.setContentSize(size)
      window.center()
      return
    }
    let cascade = CGFloat(ConversationWindow.open.count - 1) * 24
    let origin = NSPoint(
      x: main.frame.minX + 40 + cascade,
      y: main.frame.maxY - size.height - 40 - cascade)
    window.setFrame(NSRect(origin: origin, size: size), display: true)
  }

  private func share(_ args: [String: Any]) {
    guard let view = controller?.view, let text = args["text"] as? String else { return }
    let x = args["x"] as? Double ?? 0
    let y = args["y"] as? Double ?? 0
    let width = args["width"] as? Double ?? 1
    let height = args["height"] as? Double ?? 1
    let rect = NSRect(
      x: x, y: view.isFlipped ? y : view.bounds.height - y - height, width: width,
      height: height)
    NSSharingServicePicker(items: [text]).show(relativeTo: rect, of: view, preferredEdge: .minY)
  }
}
