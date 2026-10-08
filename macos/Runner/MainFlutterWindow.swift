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
  /// The one main window, whose engine owns the session.
  static weak var shared: MainFlutterWindow?

  private var keyObserver: WindowKeyObserver?
  private var channel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    Self.registerClipboard(messenger: flutterViewController.engine.binaryMessenger)

    // Its engine owns the session that conversation windows borrow, so it
    // must outlive a close; see close().
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
      case "setContentSize":
        if let args = call.arguments as? [String: Double],
          let width = args["width"], let height = args["height"]
        {
          self?.setContentSize(NSSize(width: width, height: height))
          self?.center()
        }
        result(nil)
      case "closeConversation":
        ConversationWindow.close(id: call.arguments as? String)
        result(nil)
      case "closeConversations":
        ConversationWindow.closeAll()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    keyObserver = WindowKeyObserver(window: self, channel: channel)
    self.channel = channel
    Self.shared = self

    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      ConversationWindow.attach(to: controller)
    }

    super.awakeFromNib()
  }

  /// With conversation windows open, closing the main window only hides it,
  /// so it never posts willClose: desktop_multi_window would drop the main
  /// engine on that and stop telling it when windows open or close. ⌘0 and
  /// the Dock icon bring it back. Without them it closes, and the app quits
  /// as before.
  override func close() {
    if ConversationWindow.isEmpty {
      super.close()
    } else {
      orderOut(nil)
    }
  }

  /// Tells the main engine that conversation window [id] closed, then runs
  /// [done] once it has forgotten the window (and saved that), so a quit
  /// that follows cannot bring the window back on the next launch.
  func conversationClosed(id: String?, done: @escaping () -> Void) {
    guard let id, let channel else {
      DispatchQueue.main.async(execute: done)
      return
    }
    channel.invokeMethod("conversationClosed", arguments: id) { _ in done() }
  }

  /// Closes the hidden main window once its last conversation window is
  /// gone, so the app quits as it would have.
  func closeIfHidden() {
    if !isVisible && !isMiniaturized { super.close() }
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

/// The ids of conversation windows the main engine closed before they
/// reported in: an engine reports its window's id when it first shows it,
/// so a window closed earlier closes then instead of showing.
struct PendingCloses {
  private var ids: Set<String> = []

  mutating func remember(_ id: String) { ids.insert(id) }

  /// Whether [id] was closed early; forgets it.
  mutating func take(_ id: String) -> Bool { ids.remove(id) != nil }
}

/// A window desktop_multi_window opened for one chat, with its own engine.
final class ConversationWindow: NSObject {
  private static var open: [ObjectIdentifier: ConversationWindow] = [:]

  private weak var window: NSWindow?
  private weak var controller: FlutterViewController?

  /// The plugin's id for the window, which its engine reports when it shows
  /// the window.
  private var windowId: String?

  static var isEmpty: Bool { open.isEmpty }

  private static var closeOnPresent = PendingCloses()

  static func close(id: String?) {
    guard let id else { return }
    if let conversation = open.values.first(where: { $0.windowId == id }) {
      conversation.window?.close()
    } else {
      closeOnPresent.remember(id)
    }
  }

  static func closeAll() {
    for conversation in open.values { conversation.window?.close() }
  }
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
    ) { [weak self] _ in
      let id = self?.windowId
      ConversationWindow.open.removeValue(forKey: ObjectIdentifier(window))
      let last = ConversationWindow.open.isEmpty
      MainFlutterWindow.shared?.conversationClosed(id: id) {
        if last { MainFlutterWindow.shared?.closeIfHidden() }
      }
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
      windowId = args["window_id"] as? String
      if let windowId, Self.closeOnPresent.take(windowId) {
        window.close()
        return result(nil)
      }
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
