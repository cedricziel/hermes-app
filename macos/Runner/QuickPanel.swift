import Cocoa
import FlutterMacOS
import hermes_speech
import record_macos

/// A panel that takes key focus without activating the app, so typing into
/// it leaves Hermes' other windows where they are.
private final class QuickPanelWindow: NSPanel {
  override var canBecomeKey: Bool { true }
  /// Also keeps the panel out of AppDelegate's windowless check, so showing
  /// it does not count as a window that ends running windowless.
  override var canBecomeMain: Bool { false }

  var onCloseChord: (() -> Void)?

  /// Flutter takes a chord first (the field's ⌘C, ⌘V, ⌘A, ⌘Z and so on).
  /// What it leaves would reach the main menu and act on the main window,
  /// so here ⌘W hides the panel, ⌘Q quits and every other chord does
  /// nothing.
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if super.performKeyEquivalent(with: event) { return true }
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard flags.contains(.command) else { return false }
    if flags == .command {
      switch event.charactersIgnoringModifiers?.lowercased() {
      case "w": onCloseChord?()
      case "q": NSApp.terminate(nil)
      default: break
      }
    }
    return true
  }
}

/// The quick panel: a floating, non-activating panel over every Space and
/// full-screen app. desktop_multi_window makes a plain NSWindow for it, which
/// could only be shown by activating the app (bringing the main window
/// along), so its engine's view controller moves into a panel and the
/// plugin's window stays ordered out, never closed, which would drop the
/// engine. Hiding orders the panel out too, so the engine and its chat
/// survive between presses.
final class QuickPanel: NSObject, NSWindowDelegate {
  private(set) static var shared: QuickPanel?

  /// True while the panel itself takes or gives back key status, so the
  /// window that loses or regains it does not take that for the user
  /// switching windows (which reloads its chats).
  private(set) static var switchingKey = false

  private static let width: CGFloat = 680
  private static let height: CGFloat = 168

  let windowId: String
  private let panel: QuickPanelWindow
  /// The plugin's window, kept so closing the panel closes it too and the
  /// plugin forgets the engine.
  private let hostWindow: NSWindow
  private let channel: FlutterMethodChannel
  private var shown = false
  private weak var controller: FlutterViewController?
  private var activeObservers: [NSObjectProtocol] = []

  /// Moves [controller], which desktop_multi_window showed in [window], into
  /// the panel. Called once, when the panel's engine first reports in.
  static func adopt(
    windowId: String, controller: FlutterViewController, window: NSWindow
  ) {
    shared?.close()
    registerPlugins(controller)
    shared = QuickPanel(windowId: windowId, controller: controller, window: window)
    shared?.show()
  }

  /// Conversation windows leave out the dictation plugins on purpose; the
  /// panel's composer dictates, so its engine gets them. hermes_speech keeps
  /// its event sink per plugin instance, so the panel's listener does not
  /// take the main engine's.
  private static func registerPlugins(_ registry: FlutterPluginRegistry) {
    RecordMacOsPlugin.register(with: registry.registrar(forPlugin: "RecordMacOsPlugin"))
    HermesSpeechPlugin.register(with: registry.registrar(forPlugin: "HermesSpeechPlugin"))
  }

  private init(windowId: String, controller: FlutterViewController, window: NSWindow) {
    self.windowId = windowId
    self.controller = controller
    hostWindow = window
    channel = FlutterMethodChannel(
      name: "hermes_app/window", binaryMessenger: controller.engine.binaryMessenger)
    panel = QuickPanelWindow(
      contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.height),
      styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
      backing: .buffered, defer: false)
    super.init()
    window.orderOut(nil)
    window.contentViewController = nil
    configure(panel)
    panel.contentViewController = controller
    panel.setContentSize(NSSize(width: Self.width, height: Self.height))
    panel.delegate = self
    panel.onCloseChord = { [weak self] in self?.hide(reason: "escape") }
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result) ?? result(nil)
    }
    // desktop_multi_window forwards these through the window it made, whose
    // content this panel has taken over.
    activeObservers = [
      NSApplication.willBecomeActiveNotification, NSApplication.didResignActiveNotification,
    ].map { name in
      NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
        [weak self] notification in
        self?.controller?.engine.handleDidChangeOcclusionState(notification)
      }
    }
  }

  deinit {
    activeObservers.forEach(NotificationCenter.default.removeObserver)
  }

  private func configure(_ panel: NSPanel) {
    panel.isFloatingPanel = true
    panel.level = .floating
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
    panel.hidesOnDeactivate = false
    panel.isMovableByWindowBackground = true
    panel.isReleasedWhenClosed = false
    panel.titlebarAppearsTransparent = true
    panel.titleVisibility = .hidden
    panel.animationBehavior = .utilityWindow
    for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
      panel.standardWindowButton(button)?.isHidden = true
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hidePanel":
      hide(reason: call.arguments as? String ?? "escape")
      result(nil)
    case "resizePanel":
      if let height = call.arguments as? Double { resize(to: CGFloat(height)) }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Shows the panel, or hides it while it is the key window.
  func toggle() {
    if shown && panel.isKeyWindow {
      hide(reason: "shortcut")
    } else {
      show()
    }
  }

  func show() {
    if !shown { place() }
    // A hidden app (⌘H) keeps its windows off screen, the panel too. This
    // brings Hermes' other windows back as well, without activating it.
    if NSApp.isHidden { NSApp.unhideWithoutActivation() }
    switchingKey(panel.makeKeyAndOrderFront)
    shown = panel.isVisible
    if shown { channel.invokeMethod("panelShown", arguments: nil) }
  }

  func hide(reason: String) {
    guard shown else { return }
    shown = false
    // Losing focus already gave the key status to what the user picked.
    if reason == "focus_lost" {
      panel.orderOut(nil)
    } else {
      switchingKey(panel.orderOut)
    }
    channel.invokeMethod("panelHidden", arguments: reason)
  }

  private func switchingKey(_ change: (Any?) -> Void) {
    Self.switchingKey = true
    change(nil)
    // After the key observers, whether they ran inline or were queued.
    DispatchQueue.main.async { Self.switchingKey = false }
  }

  /// Closes the panel and its engine (sign-out, another server).
  func close() {
    shown = false
    activeObservers.forEach(NotificationCenter.default.removeObserver)
    activeObservers = []
    panel.delegate = nil
    panel.orderOut(nil)
    panel.contentViewController = nil
    panel.close()
    hostWindow.close()
    if Self.shared === self { Self.shared = nil }
  }

  func windowDidResignKey(_ notification: Notification) {
    hide(reason: "focus_lost")
  }

  /// Grows or shrinks the panel to [height], at most 60% of its screen,
  /// keeping its top edge where it is.
  private func resize(to height: CGFloat) {
    let limit = (panel.screen ?? NSScreen.main)?.visibleFrame.height ?? height
    let content = min(height, limit * 0.6)
    var frame = panel.frameRect(forContentRect: NSRect(
      origin: .zero, size: NSSize(width: Self.width, height: content)))
    frame.origin = NSPoint(x: panel.frame.minX, y: panel.frame.maxY - frame.height)
    panel.setFrame(frame, display: true, animate: shown)
  }

  /// On the screen with the pointer, centred, in its upper third.
  private func place() {
    let mouse = NSEvent.mouseLocation
    let screen =
      NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    guard let area = screen?.visibleFrame else { return panel.center() }
    let size = panel.frame.size
    let origin = NSPoint(
      x: area.midX - size.width / 2,
      y: area.maxY - area.height / 3 - size.height / 2)
    panel.setFrameOrigin(origin)
  }
}
