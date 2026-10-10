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
import UserNotifications

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
    NotificationCategories.install(messenger: flutterViewController.engine.binaryMessenger)
    QuickPanelShortcut.register(
      with: flutterViewController.registrar(forPlugin: "QuickPanelShortcut"))

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
        if self?.isMiniaturized == true { self?.deminiaturize(nil) }
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
      case "togglePanel":
        // False while there is no panel yet, so Dart creates one.
        guard let panel = QuickPanel.shared else { return result(false) }
        panel.toggle()
        result(true)
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

  /// Closing the main window only hides it, so it never posts willClose:
  /// desktop_multi_window would drop the main engine on that and stop telling
  /// it when windows open or close. The app keeps running without a window
  /// (see AppDelegate); ⌘0 and the Dock icon bring the window back. A
  /// full-screen window leaves full screen first, or its empty Space stays.
  override func close() {
    guard styleMask.contains(.fullScreen) else { return hide() }
    var observer: NSObjectProtocol?
    observer = NotificationCenter.default.addObserver(
      forName: NSWindow.didExitFullScreenNotification, object: self, queue: .main
    ) { [weak self] _ in
      if let observer { NotificationCenter.default.removeObserver(observer) }
      self?.hide()
    }
    toggleFullScreen(nil)
  }

  private func hide() {
    orderOut(nil)
    (NSApp.delegate as? AppDelegate)?.refreshWindowless()
  }

  /// Tells the main engine that conversation window [id] closed.
  func conversationClosed(id: String?) {
    guard let id, let channel else { return }
    channel.invokeMethod("conversationClosed", arguments: id)
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
      ) { _ in
        if !QuickPanel.switchingKey { channel.invokeMethod("keyChanged", arguments: true) }
      },
      center.addObserver(
        forName: NSWindow.didResignKeyNotification, object: window, queue: .main
      ) { _ in
        if !QuickPanel.switchingKey { channel.invokeMethod("keyChanged", arguments: false) }
      },
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

  private static var closeOnPresent = PendingCloses()

  static func close(id: String?) {
    guard let id else { return }
    if let panel = QuickPanel.shared, panel.windowId == id {
      return panel.close()
    }
    if let conversation = open.values.first(where: { $0.windowId == id }) {
      conversation.window?.close()
    } else {
      closeOnPresent.remember(id)
    }
  }

  static func closeAll() {
    for conversation in open.values { conversation.window?.close() }
    QuickPanel.shared?.close()
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
      MainFlutterWindow.shared?.conversationClosed(id: id)
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
    case "presentPanel":
      // The quick panel's engine: it leaves the conversation windows and
      // moves into a panel of its own.
      guard let controller, let windowId = args["window_id"] as? String else {
        return result(nil)
      }
      Self.open.removeValue(forKey: ObjectIdentifier(window))
      if Self.closeOnPresent.take(windowId) {
        window.close()
        return result(nil)
      }
      QuickPanel.adopt(windowId: windowId, controller: controller, window: window)
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

/// The same as the iOS Runner's: registers the request notification categories with their hidden-preview
/// placeholders, which flutter_local_notifications cannot set. Every launch
/// the plugin replaces the whole set, so the categories made for single
/// questions are remembered and added again, or a question still on screen
/// would lose its buttons. Calls run one at a time, since each reads the set
/// and writes it back.
enum NotificationCategories {
  private static let rememberedKey = "hermes.requestCategories"
  private static let questionPrefix = "hermes.request.question."
  private static let remembered = 20
  private static var busy = false
  private static var queued: [(@escaping () -> Void) -> Void] = []

  static func install(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "hermes_app/notification_categories", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "register":
          guard let specs = (call.arguments as? [String: Any])?["categories"] as? [[String: Any]]
          else { result(FlutterMethodNotImplemented); return }
          enqueue { done in register(specs) { result(nil); done() } }
        case "forget":
          enqueue { done in forget { result(nil); done() } }
        default: result(FlutterMethodNotImplemented)
        }
      }
  }

  private static func enqueue(_ work: @escaping (@escaping () -> Void) -> Void) {
    queued.append(work)
    runNext()
  }

  private static func runNext() {
    guard !busy, !queued.isEmpty else { return }
    busy = true
    queued.removeFirst()({
      busy = false
      runNext()
    })
  }

  private static func register(_ specs: [[String: Any]], done: @escaping () -> Void) {
    let defaults = UserDefaults.standard
    var kept = defaults.array(forKey: rememberedKey) as? [[String: Any]] ?? []
    let questions = specs.filter { ($0["id"] as? String)?.hasPrefix(questionPrefix) == true }
    let ids = Set(questions.compactMap { $0["id"] as? String })
    kept.removeAll { ids.contains($0["id"] as? String ?? "") }
    kept = Array((kept + questions).suffix(remembered))
    defaults.set(kept, forKey: rememberedKey)
    let center = UNUserNotificationCenter.current()
    center.getNotificationCategories { current in
      var byId = [String: UNNotificationCategory]()
      for category in current { byId[category.identifier] = category }
      for spec in kept + specs {
        if let category = category(spec) { byId[category.identifier] = category }
      }
      center.setNotificationCategories(Set(byId.values))
      DispatchQueue.main.async(execute: done)
    }
  }

  /// Drops the remembered question categories, whose buttons carry the
  /// choices the agent offered.
  private static func forget(done: @escaping () -> Void) {
    UserDefaults.standard.removeObject(forKey: rememberedKey)
    let center = UNUserNotificationCenter.current()
    center.getNotificationCategories { current in
      center.setNotificationCategories(current.filter { !$0.identifier.hasPrefix(questionPrefix) })
      DispatchQueue.main.async(execute: done)
    }
  }

  private static func category(_ spec: [String: Any]) -> UNNotificationCategory? {
    guard let id = spec["id"] as? String else { return nil }
    let actions: [UNNotificationAction] = (spec["actions"] as? [[String: Any]] ?? []).compactMap { action in
      guard let id = action["id"] as? String, let title = action["title"] as? String else { return nil }
      let options = UNNotificationActionOptions(rawValue: (action["options"] as? NSNumber)?.uintValue ?? 0)
      if let button = action["buttonTitle"] as? String {
        return UNTextInputNotificationAction(
          identifier: id, title: title, options: options,
          textInputButtonTitle: button,
          textInputPlaceholder: action["placeholder"] as? String ?? "")
      }
      return UNNotificationAction(identifier: id, title: title, options: options)
    }
    return UNNotificationCategory(
      identifier: id, actions: actions, intentIdentifiers: [],
      hiddenPreviewsBodyPlaceholder: spec["placeholder"] as? String ?? "",
      options: [])
  }
}
