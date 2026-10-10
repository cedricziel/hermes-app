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
/// The panel is driven directly: `QuickLookPanel` makes itself the panel's data
/// source and delegate when a file is shown. That is the documented fallback
/// for code that cannot join the responder chain, and conversation windows,
/// which `desktop_multi_window` creates, have no window class of ours to do it
/// in. If the system hands the panel to another controller, the list shown
/// here is dropped, which costs nothing because there is nothing else to keep.
///
/// - `preview(path)` shows the file, replacing what the open panel shows, and
///   answers whether it could: false when the file is gone or unreadable.
/// - `toggle(path)` closes the panel when it shows that file and answers
///   `"closed"`; otherwise it shows it as `preview` does and answers `"shown"`,
///   or false when it could not.
/// - `close()` closes the panel if it is ours.
///
/// Closing by Space, Escape or the close button, and the return of focus to
/// the window behind, are the panel's own.
final class QuickLookPanel: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
  static let channelName = "hermes_app/quick_look"
  static let shared = QuickLookPanel()

  /// The file the panel shows, if it is ours.
  private(set) var item: URL?

  override private init() {
    super.init()
  }

  /// Answers this engine's `hermes_app/quick_look` calls.
  static func register(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        shared.handle(call, result: result)
      }
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
      panel.orderOut(nil)
      return "closed"
    }
    return show(url) ? "shown" : false
  }

  func close() {
    guard QLPreviewPanel.sharedPreviewPanelExists(), let panel = QLPreviewPanel.shared(),
      owns(panel)
    else { return }
    panel.orderOut(nil)
    item = nil
  }

  private func owns(_ panel: QLPreviewPanel) -> Bool {
    (panel.dataSource as AnyObject?) === self
  }

  private func isShowing(_ url: URL, in panel: QLPreviewPanel) -> Bool {
    panel.isVisible && owns(panel) && item == url
  }

  private func show(_ url: URL) -> Bool {
    guard let panel = QLPreviewPanel.shared() else { return false }
    item = url
    panel.dataSource = self
    panel.delegate = self
    panel.reloadData()
    panel.currentPreviewItemIndex = 0
    panel.makeKeyAndOrderFront(nil)
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
