import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

/// What Dart hands over for a promised file: the bytes, or a local file to copy.
/// A file on disk never crosses the channel, so a large attachment costs no
/// memory here; bytes are only for content that has no file (an attachment the
/// message embedded, a Kanban download).
enum DragOutPayload {
  case data(Data)
  case file(URL)
}

/// What a drag out of the app needs from Dart. The channel implements it; tests
/// stand in for it.
protocol DragOutBackend: AnyObject {
  /// Asks Dart for the content of the file promised under `id`. Called on the
  /// main thread, when the receiver asks for the file.
  func readFile(id: Int, completion: @escaping (Result<DragOutPayload, Error>) -> Void)

  /// Dart did not answer `readFile` in time; the promise was failed.
  func readTimedOut(id: Int)

  /// The promised file was written, or writing it failed with `error`.
  func fileWritten(id: Int, error: Error?)

  /// The drag session of `id` ended; `copied` is whether a receiver took it.
  func ended(id: Int, copied: Bool)
}

/// What Finder and other receivers show when a promise fails.
enum DragOutError: LocalizedError {
  case unknownPromise
  case fetchFailed
  case timedOut

  var errorDescription: String? {
    switch self {
    case .unknownPromise, .fetchFailed:
      return NSLocalizedString(
        "Hermes could not get this file. It may have been removed, or you may be signed out.",
        comment: "Shown when a file dragged out of Hermes cannot be fetched")
    case .timedOut:
      return NSLocalizedString(
        "Hermes did not receive this file in time. Try dragging it again.",
        comment: "Shown when fetching a file dragged out of Hermes takes too long")
    }
  }
}

/// Runs a completion handler at most once, from any thread.
private final class Once {
  private let lock = NSLock()
  private var handler: ((Error?) -> Void)?

  init(_ handler: @escaping (Error?) -> Void) {
    self.handler = handler
  }

  var isDone: Bool {
    lock.lock()
    defer { lock.unlock() }
    return handler == nil
  }

  /// Runs the handler unless it already ran; whether this call ran it.
  @discardableResult
  func finish(_ error: Error?) -> Bool {
    lock.lock()
    let run = handler
    handler = nil
    lock.unlock()
    run?(error)
    return run != nil
  }
}

/// Delivers promised files: the receiver names the folder, and the content is
/// fetched from Dart only then.
final class DragOutFilePromises: NSObject, NSFilePromiseProviderDelegate {
  private static let idKey = "id"
  private static let nameKey = "name"

  private weak var backend: DragOutBackend?

  /// How long Dart has to answer `readFile` before the promise fails.
  let readTimeout: TimeInterval

  private let queue: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "hermes.drag-out.write"
    queue.maxConcurrentOperationCount = 1
    return queue
  }()

  init(backend: DragOutBackend, readTimeout: TimeInterval = 60) {
    self.backend = backend
    self.readTimeout = readTimeout
  }

  /// A name that cannot leave the receiver's folder or hide: the last path
  /// component, without leading dots, never empty. Dart sanitizes names too;
  /// this does not trust the channel.
  static func safeName(_ name: String) -> String {
    var clean = (name.replacingOccurrences(of: "\\", with: "/") as NSString).lastPathComponent
    clean = clean.replacingOccurrences(of: ":", with: "_")
    while clean.hasPrefix(".") { clean.removeFirst() }
    clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
    return clean.isEmpty ? "File" : clean
  }

  /// A promise for the file `name` of type `fileType` (a UTI), numbered `id`.
  func provider(id: Int, name: String, fileType: String) -> NSFilePromiseProvider {
    let provider = NSFilePromiseProvider(fileType: fileType, delegate: self)
    provider.userInfo = [Self.idKey: id, Self.nameKey: Self.safeName(name)]
    return provider
  }

  func filePromiseProvider(
    _ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String
  ) -> String {
    let info = filePromiseProvider.userInfo as? [String: Any]
    return Self.safeName(info?[Self.nameKey] as? String ?? "")
  }

  func filePromiseProvider(
    _ filePromiseProvider: NSFilePromiseProvider,
    writePromiseTo url: URL,
    completionHandler: @escaping (Error?) -> Void
  ) {
    let info = filePromiseProvider.userInfo as? [String: Any]
    guard let id = info?[Self.idKey] as? Int else {
      completionHandler(DragOutError.unknownPromise)
      return
    }
    let once = Once(completionHandler)
    // The channel belongs to the main thread; the write happens on the queue.
    DispatchQueue.main.async { [weak self] in
      guard let self, let backend = self.backend else {
        once.finish(DragOutError.unknownPromise)
        return
      }
      let deadline = DispatchWorkItem {
        if once.finish(DragOutError.timedOut) { backend.readTimedOut(id: id) }
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + self.readTimeout, execute: deadline)
      backend.readFile(id: id) { result in
        deadline.cancel()
        switch result {
        case .failure(let error):
          // Dart has already logged the failed fetch.
          once.finish(error)
        case .success(let payload):
          // Too late: the promise was failed already, so write nothing.
          if once.isDone { return }
          self.queue.addOperation {
            var failure: Error?
            do {
              try Self.write(payload, to: url)
            } catch {
              failure = error
            }
            once.finish(failure)
            DispatchQueue.main.async { backend.fileWritten(id: id, error: failure) }
          }
        }
      }
    }
  }

  private static func write(_ payload: DragOutPayload, to url: URL) throws {
    switch payload {
    case .data(let data):
      try data.write(to: url)
    case .file(let source):
      let files = FileManager.default
      if files.fileExists(atPath: url.path) { try files.removeItem(at: url) }
      try files.copyItem(at: source, to: url)
    }
  }

  func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
    queue
  }
}

enum DragOutPasteboard {
  static let markdown = NSPasteboard.PasteboardType("net.daringfireball.markdown")

  /// Text as plain text and as Markdown, both carrying the same string: a text
  /// field takes the first, a notes app can pick the second.
  static func textItem(_ text: String) -> NSPasteboardItem {
    let item = NSPasteboardItem()
    item.setString(text, forType: .string)
    item.setString(text, forType: markdown)
    return item
  }
}

/// The platform calls the controller makes, so tests can stand in for them.
struct DragOutEnvironment {
  var pressedMouseButtons: () -> Int
  var ownsEvent: (NSEvent, NSView) -> Bool
  var beginSession: (NSView, [NSDraggingItem], NSEvent, NSDraggingSource) -> Void
  var deliverMouseUp: (NSEvent) -> Void

  /// `deliverMouseUp` goes to the Flutter view controller, which tracks the
  /// button state of the view.
  static func live(deliverMouseUp: @escaping (NSEvent) -> Void) -> DragOutEnvironment {
    DragOutEnvironment(
      pressedMouseButtons: { Int(NSEvent.pressedMouseButtons) },
      ownsEvent: { event, view in event.window != nil && event.window === view.window },
      beginSession: { view, items, event, source in
        _ = view.beginDraggingSession(with: items, event: event, source: source)
      },
      deliverMouseUp: deliverMouseUp)
  }
}

/// Starts native drags for the main window's Flutter view.
///
/// Flutter hands pointer events to Dart, not to AppKit, so there is no
/// `NSEvent` to start a dragging session with when Dart decides a drag has
/// begun. A local event monitor remembers the latest left-button events of the
/// window instead, and the session starts from those. Nothing is consumed or
/// altered, so clicks, selection, drops (desktop_drop) and window dragging by
/// the toolbar behave as before.
final class DragOutController: NSObject, NSDraggingSource {
  private static var shared: DragOutController?

  /// Wires drag-out into the main window; one line in `awakeFromNib`.
  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "hermes_app/drag_out", binaryMessenger: controller.engine.binaryMessenger)
    let drag = DragOutController(
      view: controller.view,
      backend: ChannelDragOutBackend(channel: channel),
      environment: .live { [weak controller] event in controller?.mouseUp(with: event) })
    channel.setMethodCallHandler { [weak drag] call, result in
      guard call.method == "startDrag" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(drag?.startDrag(call.arguments as? [String: Any] ?? [:]) ?? false)
    }
    drag.installMonitor()
    shared = drag
  }

  /// Copy for a receiver in another app; none within this one, so a drop back
  /// on the window (where desktop_drop would attach the file to the chat) is
  /// refused.
  static func operationMask(for context: NSDraggingContext) -> NSDragOperation {
    context == .outsideApplication ? .copy : []
  }

  private weak var view: NSView?
  private let backend: DragOutBackend
  private let environment: DragOutEnvironment
  private var monitor: Any?
  private var latestEvent: NSEvent?
  private(set) var activeId: Int?
  private lazy var promises = DragOutFilePromises(backend: backend)

  init(view: NSView, backend: DragOutBackend, environment: DragOutEnvironment) {
    self.view = view
    self.backend = backend
    self.environment = environment
    super.init()
  }

  deinit {
    if let monitor { NSEvent.removeMonitor(monitor) }
  }

  func installMonitor() {
    monitor = NSEvent.addLocalMonitorForEvents(matching: [
      .leftMouseDown, .leftMouseDragged, .leftMouseUp,
    ]) { [weak self] event in
      self?.record(event)
      return event
    }
  }

  /// Remembers the latest left-button event of the window; a button up clears
  /// it.
  func record(_ event: NSEvent) {
    guard let view, environment.ownsEvent(event, view) else { return }
    latestEvent = event.type == .leftMouseUp ? nil : event
  }

  /// Begins a session for the gesture in progress; whether one began.
  func startDrag(_ arguments: [String: Any]) -> Bool {
    guard let view, let event = latestEvent,
      environment.pressedMouseButtons() & 1 != 0,
      let id = arguments["id"] as? Int, activeId == nil
    else { return false }

    let writer: NSPasteboardWriting
    let icon: NSImage
    switch arguments["type"] as? String {
    case "file":
      guard let name = arguments["name"] as? String else { return false }
      let fileType = arguments["fileType"] as? String ?? UTType.data.identifier
      writer = promises.provider(id: id, name: name, fileType: fileType)
      icon = NSWorkspace.shared.icon(for: UTType(fileType) ?? .data)
    case "text":
      guard let text = arguments["text"] as? String else { return false }
      writer = DragOutPasteboard.textItem(text)
      icon = NSWorkspace.shared.icon(for: .plainText)
    default:
      return false
    }

    let item = NSDraggingItem(pasteboardWriter: writer)
    let point = view.convert(event.locationInWindow, from: nil)
    let size: CGFloat = 48
    item.setDraggingFrame(
      NSRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size),
      contents: icon)
    activeId = id
    environment.beginSession(view, [item], event, self)
    return true
  }

  // MARK: NSDraggingSource

  func draggingSession(
    _ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    Self.operationMask(for: context)
  }

  func draggingSession(
    _ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation
  ) {
    sessionEnded(at: screenPoint, operation: operation)
  }

  func sessionEnded(at screenPoint: NSPoint, operation: NSDragOperation) {
    releaseMouse(at: screenPoint)
    guard let id = activeId else { return }
    activeId = nil
    backend.ended(id: id, copied: !operation.isEmpty)
  }

  /// The dragging session swallows the real button up, so the Flutter view
  /// would believe the button is still down: hover would stop, a selection
  /// would keep growing and the next click would be lost. Tell it.
  private func releaseMouse(at screenPoint: NSPoint) {
    guard let window = view?.window,
      let up = NSEvent.mouseEvent(
        with: .leftMouseUp,
        location: window.convertPoint(fromScreen: screenPoint),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 0)
    else { return }
    latestEvent = nil
    environment.deliverMouseUp(up)
  }
}

/// `DragOutBackend` over the `hermes_app/drag_out` channel.
final class ChannelDragOutBackend: DragOutBackend {
  private let channel: FlutterMethodChannel

  init(channel: FlutterMethodChannel) {
    self.channel = channel
  }

  func readFile(id: Int, completion: @escaping (Result<DragOutPayload, Error>) -> Void) {
    channel.invokeMethod("readFile", arguments: id) { reply in
      switch reply {
      case let data as FlutterStandardTypedData:
        completion(.success(.data(data.data)))
      case let path as String:
        completion(.success(.file(URL(fileURLWithPath: path))))
      default:
        completion(.failure(DragOutError.fetchFailed))
      }
    }
  }

  func readTimedOut(id: Int) {
    channel.invokeMethod("readTimedOut", arguments: id)
  }

  func fileWritten(id: Int, error: Error?) {
    channel.invokeMethod("fileWritten", arguments: ["id": id, "ok": error == nil])
  }

  func ended(id: Int, copied: Bool) {
    channel.invokeMethod("ended", arguments: ["id": id, "copied": copied])
  }
}
