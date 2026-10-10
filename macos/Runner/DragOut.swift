import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

/// What a drag out of the app needs from Dart. The channel implements it; tests
/// stand in for it.
protocol DragOutBackend: AnyObject {
  /// Asks Dart for the bytes of the file promised under `id`. Called on the
  /// main thread, when the receiver asks for the file.
  func readFile(id: Int, completion: @escaping (Result<Data, Error>) -> Void)

  /// The promised file was written, or writing it failed with `error`.
  func fileWritten(id: Int, error: Error?)

  /// The drag session of `id` ended; `copied` is whether a receiver took it.
  func ended(id: Int, copied: Bool)
}

/// Delivers promised files: the receiver names the folder, and the bytes are
/// fetched from Dart only then.
final class DragOutFilePromises: NSObject, NSFilePromiseProviderDelegate {
  private static let idKey = "id"
  private static let nameKey = "name"

  private weak var backend: DragOutBackend?
  private let queue: OperationQueue = {
    let queue = OperationQueue()
    queue.name = "hermes.drag-out.write"
    queue.maxConcurrentOperationCount = 1
    return queue
  }()

  init(backend: DragOutBackend) {
    self.backend = backend
  }

  /// A promise for the file `name` of type `fileType` (a UTI), numbered `id`.
  func provider(id: Int, name: String, fileType: String) -> NSFilePromiseProvider {
    let provider = NSFilePromiseProvider(fileType: fileType, delegate: self)
    provider.userInfo = [Self.idKey: id, Self.nameKey: name]
    return provider
  }

  func filePromiseProvider(
    _ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String
  ) -> String {
    let info = filePromiseProvider.userInfo as? [String: Any]
    return info?[Self.nameKey] as? String ?? "File"
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
    // The channel belongs to the main thread; the write happens on the queue.
    DispatchQueue.main.async { [weak self] in
      guard let self, let backend = self.backend else {
        completionHandler(DragOutError.unknownPromise)
        return
      }
      backend.readFile(id: id) { result in
        switch result {
        case .failure(let error):
          // Dart has already logged the failed fetch.
          completionHandler(error)
        case .success(let data):
          self.queue.addOperation {
            var failure: Error?
            do {
              try data.write(to: url)
            } catch {
              failure = error
            }
            completionHandler(failure)
            DispatchQueue.main.async { backend.fileWritten(id: id, error: failure) }
          }
        }
      }
    }
  }

  func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
    queue
  }
}

enum DragOutError: Error {
  case unknownPromise
  case fetchFailed(String)
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

/// Starts native drags for the main window's Flutter view.
///
/// Flutter hands pointer events to Dart, not to AppKit, so there is no
/// `NSEvent` to start a dragging session with when Dart decides a drag has
/// begun. A local event monitor remembers the latest left-button events of the
/// window instead, and the session starts from those. Nothing is consumed or
/// altered, so clicks, selection, drops (desktop_drop) and window dragging by
/// the toolbar behave as before.
final class DragOutController: NSObject, NSDraggingSource, DragOutBackend {
  private static var shared: DragOutController?

  /// Wires drag-out into the main window; one line in `awakeFromNib`.
  static func register(with controller: FlutterViewController) {
    shared = DragOutController(
      view: controller.view,
      channel: FlutterMethodChannel(
        name: "hermes_app/drag_out", binaryMessenger: controller.engine.binaryMessenger))
  }

  private weak var view: NSView?
  private let channel: FlutterMethodChannel
  private var monitor: Any?
  private var latestEvent: NSEvent?
  private var activeId: Int?
  private lazy var promises = DragOutFilePromises(backend: self)

  init(view: NSView, channel: FlutterMethodChannel) {
    self.view = view
    self.channel = channel
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "startDrag" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.startDrag(call.arguments as? [String: Any] ?? [:]) ?? false)
    }
    monitor = NSEvent.addLocalMonitorForEvents(matching: [
      .leftMouseDown, .leftMouseDragged, .leftMouseUp,
    ]) { [weak self] event in
      self?.record(event)
      return event
    }
  }

  deinit {
    if let monitor { NSEvent.removeMonitor(monitor) }
  }

  private func record(_ event: NSEvent) {
    guard let window = view?.window, event.window === window else { return }
    latestEvent = event.type == .leftMouseUp ? nil : event
  }

  /// Begins a session for the gesture in progress; whether one began.
  private func startDrag(_ arguments: [String: Any]) -> Bool {
    guard let view, let event = latestEvent,
      NSEvent.pressedMouseButtons & 1 != 0,
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
    view.beginDraggingSession(with: [item], event: event, source: self)
    return true
  }

  // MARK: NSDraggingSource

  func draggingSession(
    _ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    .copy
  }

  func draggingSession(
    _ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation
  ) {
    guard let id = activeId else { return }
    activeId = nil
    ended(id: id, copied: !operation.isEmpty)
  }

  // MARK: DragOutBackend

  func readFile(id: Int, completion: @escaping (Result<Data, Error>) -> Void) {
    channel.invokeMethod("readFile", arguments: id) { reply in
      switch reply {
      case let data as FlutterStandardTypedData:
        completion(.success(data.data))
      case let error as FlutterError:
        completion(.failure(DragOutError.fetchFailed(error.code)))
      default:
        completion(.failure(DragOutError.fetchFailed("unexpected")))
      }
    }
  }

  func fileWritten(id: Int, error: Error?) {
    channel.invokeMethod("fileWritten", arguments: ["id": id, "ok": error == nil])
  }

  func ended(id: Int, copied: Bool) {
    channel.invokeMethod("ended", arguments: ["id": id, "copied": copied])
  }
}
