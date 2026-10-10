import Cocoa
import FlutterMacOS
import Quartz

/// Shows files in the system's Quick Look panel for Dart, over the
/// `hermes_app/quick_look` channel.
///
/// One panel serves the whole app. Every engine (the main window's and each
/// conversation window's) installs its own channel handler with `register`,
/// and all of them reach `shared`.
///
/// The panel is controlled the way AppKit wants it: each engine's Flutter view
/// controller has a `QuickLookResponder` after it in the responder chain, which
/// accepts control of the panel and makes `QuickLookPanel` its data source and
/// delegate. A responder on the view controller, not on a window class of ours,
/// because conversation windows come from `desktop_multi_window` and the quick
/// panel's engine moves from one window to another. The panel shows one file at
/// a time and keeps no list, so a hand-over between windows loses nothing.
///
/// - `preview(path)` shows the file, replacing what the open panel shows, and
///   answers whether it could: false when the file is gone or unreadable.
/// - `toggle(path)` closes the panel when it shows that file and answers
///   `"closed"`; otherwise it shows it as `preview` does and answers `"shown"`,
///   or false when it could not.
/// - `close()` closes the panel if it is ours.
/// - `doubleClickInterval()` answers the system's double-click time in seconds.
///
/// While the panel is key, Space and Escape close it (`previewPanel(_:handle:)`),
/// and so does its close button; AppKit returns the focus to the window behind.
final class QuickLookPanel: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
  static let channelName = "hermes_app/quick_look"
  static let shared = QuickLookPanel()

  /// The file the panel shows, if it is ours.
  private(set) var item: URL?

  /// The panel was ordered out and is still fading: it reports itself visible
  /// for a moment, which must not count as open.
  private var closing = false

  override private init() {
    super.init()
  }

  /// Answers `controller`'s engine's `hermes_app/quick_look` calls, and puts a
  /// responder that can control the panel after `controller` in its responder
  /// chain.
  static func register(with controller: FlutterViewController) {
    FlutterMethodChannel(name: channelName, binaryMessenger: controller.engine.binaryMessenger)
      .setMethodCallHandler { call, result in
        shared.handle(call, result: result)
      }
    QuickLookResponder.install(after: controller)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "preview":
      result(preview(path: Self.path(of: call)))
    case "toggle":
      result(toggle(path: Self.path(of: call)))
    case "close":
      close()
      result(nil)
    case "doubleClickInterval":
      result(NSEvent.doubleClickInterval)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func path(of call: FlutterMethodCall) -> String? {
    (call.arguments as? [String: Any])?["path"] as? String
  }

  /// The file at `path` when it is there and can be read.
  static func readableFile(at path: String?) -> URL? {
    guard let path, !path.isEmpty else { return nil }
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
      !isDirectory.boolValue,
      FileManager.default.isReadableFile(atPath: path)
    else { return nil }
    return URL(fileURLWithPath: path)
  }

  func preview(path: String?) -> Bool {
    guard let url = Self.readableFile(at: path) else { return false }
    return show(url)
  }

  /// `"closed"`, `"shown"`, or false.
  func toggle(path: String?) -> Any {
    guard let url = Self.readableFile(at: path) else { return false }
    if QLPreviewPanel.sharedPreviewPanelExists(), let panel = QLPreviewPanel.shared(),
      isShowing(url, in: panel)
    {
      orderOut(panel)
      return "closed"
    }
    return show(url) ? "shown" : false
  }

  func close() {
    guard QLPreviewPanel.sharedPreviewPanelExists(), let panel = QLPreviewPanel.shared(),
      owns(panel)
    else { return }
    orderOut(panel)
    item = nil
  }

  private func orderOut(_ panel: QLPreviewPanel) {
    closing = true
    panel.orderOut(nil)
  }

  private func owns(_ panel: QLPreviewPanel) -> Bool {
    (panel.dataSource as AnyObject?) === self
  }

  private func isShowing(_ url: URL, in panel: QLPreviewPanel) -> Bool {
    panel.isVisible && !closing && owns(panel) && item == url
  }

  private func show(_ url: URL) -> Bool {
    guard let panel = QLPreviewPanel.shared() else { return false }
    item = url
    if panel.isVisible && !closing {
      panel.updateController()
    } else {
      closing = false
      // Ordering it in finds the responder that takes control of it.
      panel.makeKeyAndOrderFront(nil)
    }
    // No responder in the key window's chain took it: there is nothing to
    // show it for.
    guard owns(panel) else {
      orderOut(panel)
      item = nil
      return false
    }
    panel.reloadData()
    panel.currentPreviewItemIndex = 0
    panel.refreshCurrentPreviewItem()
    return true
  }

  /// Called by `QuickLookResponder` when the panel starts to be controlled
  /// from a window of this app.
  func take(control panel: QLPreviewPanel) {
    panel.dataSource = self
    panel.delegate = self
  }

  /// Called when another responder takes the panel, or the last window goes.
  func release(control panel: QLPreviewPanel) {
    guard owns(panel) else { return }
    panel.dataSource = nil
    panel.delegate = nil
  }

  /// Whether a key press closes the panel while it is key: a bare Space or
  /// Escape. The first press only: holding the key does not toggle it again.
  static func closesPanel(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, isRepeat: Bool) -> Bool {
    let space: UInt16 = 49
    let escape: UInt16 = 53
    guard !isRepeat, modifiers.intersection([.command, .control, .option, .shift]).isEmpty
    else { return false }
    return keyCode == space || keyCode == escape
  }

  // MARK: QLPreviewPanelDelegate

  func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
    guard event.type == .keyDown else { return false }
    if event.isARepeat { return true }
    guard Self.closesPanel(keyCode: event.keyCode, modifiers: event.modifierFlags, isRepeat: false)
    else { return false }
    orderOut(panel)
    return true
  }

  // MARK: QLPreviewPanelDataSource

  func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
    item == nil ? 0 : 1
  }

  func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
    item as NSURL?
  }
}

/// What `QLPreviewPanel` looks for in the responder chain of the key window: a
/// responder that accepts control of the panel. It puts `QuickLookPanel` in
/// charge of it, whichever window asked.
final class QuickLookResponder: NSResponder {
  private static var installedKey = 0

  /// Inserts a responder after `controller`, once. The chain does not retain
  /// it, so the controller does.
  static func install(after controller: NSViewController) {
    guard objc_getAssociatedObject(controller, &installedKey) == nil else { return }
    let responder = QuickLookResponder()
    responder.nextResponder = controller.nextResponder
    controller.nextResponder = responder
    objc_setAssociatedObject(controller, &installedKey, responder, .OBJC_ASSOCIATION_RETAIN)
  }

  override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
    true
  }

  override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
    QuickLookPanel.shared.take(control: panel)
  }

  override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
    QuickLookPanel.shared.release(control: panel)
  }
}
