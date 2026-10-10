import Cocoa
import XCTest

@testable import Hermes

/// A stand-in for Dart: serves the content of the promised files and notes what
/// was reported back.
private final class FakeBackend: DragOutBackend {
  var files: [Int: Result<DragOutPayload, Error>] = [:]
  /// Ids Dart never answers.
  var silent: Set<Int> = []
  var lateReplies: [(Result<DragOutPayload, Error>) -> Void] = []
  var read: [Int] = []
  var written: [(id: Int, error: Error?)] = []
  var timedOut: [Int] = []
  var endedSessions: [(id: Int, copied: Bool)] = []
  var onWritten: (() -> Void)?

  func readFile(id: Int, completion: @escaping (Result<DragOutPayload, Error>) -> Void) {
    read.append(id)
    if silent.contains(id) {
      lateReplies.append(completion)
      return
    }
    completion(files[id] ?? .failure(DragOutError.unknownPromise))
  }

  func readTimedOut(id: Int) {
    timedOut.append(id)
  }

  func fileWritten(id: Int, error: Error?) {
    written.append((id, error))
    onWritten?()
  }

  func ended(id: Int, copied: Bool) {
    endedSessions.append((id, copied))
  }
}

class DragOutTests: XCTestCase {
  private var backend: FakeBackend!
  private var promises: DragOutFilePromises!
  private var directory: URL!

  override func setUpWithError() throws {
    backend = FakeBackend()
    promises = DragOutFilePromises(backend: backend, readTimeout: 0.3)
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: directory)
  }

  // MARK: Promises

  func testPromiseNamesTheFileAsTheItemProposes() {
    let provider = promises.provider(id: 1, name: "report.pdf", fileType: "com.adobe.pdf")

    XCTAssertEqual(provider.fileType, "com.adobe.pdf")
    XCTAssertEqual(
      promises.filePromiseProvider(provider, fileNameForType: "com.adobe.pdf"), "report.pdf")
  }

  func testNamesCannotLeaveTheFolderOrHide() {
    XCTAssertEqual(DragOutFilePromises.safeName("../../etc/passwd"), "passwd")
    XCTAssertEqual(DragOutFilePromises.safeName("a\\b\\c.txt"), "c.txt")
    XCTAssertEqual(DragOutFilePromises.safeName(".hidden"), "hidden")
    XCTAssertEqual(DragOutFilePromises.safeName("..."), "File")
    XCTAssertEqual(DragOutFilePromises.safeName(""), "File")
    XCTAssertEqual(DragOutFilePromises.safeName("  "), "File")
    XCTAssertEqual(DragOutFilePromises.safeName("a:b.txt"), "a_b.txt")
    XCTAssertEqual(DragOutFilePromises.safeName("report.pdf"), "report.pdf")
  }

  func testAPromiseKeepsOnlyASafeName() {
    let provider = promises.provider(id: 1, name: "../x/.secret", fileType: "public.data")

    XCTAssertEqual(
      promises.filePromiseProvider(provider, fileNameForType: "public.data"), "secret")
  }

  func testNothingIsReadUntilTheReceiverAsks() {
    _ = promises.provider(id: 1, name: "a.txt", fileType: "public.data")

    XCTAssertTrue(backend.read.isEmpty)
  }

  private func write(id: Int, name: String = "a.bin", to url: URL? = nil) -> (
    url: URL, error: Error?
  ) {
    let provider = promises.provider(id: id, name: name, fileType: "public.data")
    let target = url ?? directory.appendingPathComponent(name)
    let done = expectation(description: "completion")
    var failure: Error?
    promises.filePromiseProvider(provider, writePromiseTo: target) { error in
      failure = error
      done.fulfill()
    }
    wait(for: [done], timeout: 5)
    return (target, failure)
  }

  func testTheReceiversFolderGetsTheBytesFromDart() throws {
    backend.files[7] = .success(.data(Data([1, 2, 3, 0, 255])))
    let reported = expectation(description: "reported")
    backend.onWritten = { reported.fulfill() }

    let result = write(id: 7)
    wait(for: [reported], timeout: 5)

    XCTAssertNil(result.error)
    XCTAssertEqual(try Data(contentsOf: result.url), Data([1, 2, 3, 0, 255]))
    XCTAssertEqual(backend.read, [7])
    XCTAssertEqual(backend.written.count, 1)
    XCTAssertNil(backend.written[0].error)
  }

  func testALocalFileIsCopiedNotSentThroughTheChannel() throws {
    let source = directory.appendingPathComponent("source.bin")
    try Data([4, 5, 6]).write(to: source)
    backend.files[8] = .success(.file(source))
    let reported = expectation(description: "reported")
    backend.onWritten = { reported.fulfill() }
    let target = directory.appendingPathComponent("copy/a.bin")
    try FileManager.default.createDirectory(
      at: target.deletingLastPathComponent(), withIntermediateDirectories: true)

    let result = write(id: 8, to: target)
    wait(for: [reported], timeout: 5)

    XCTAssertNil(result.error)
    XCTAssertEqual(try Data(contentsOf: target), Data([4, 5, 6]))
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "the original stays")
  }

  func testCopyingOverAFileTheReceiverAlreadyMadeWorks() throws {
    let source = directory.appendingPathComponent("source.bin")
    try Data([1]).write(to: source)
    let target = directory.appendingPathComponent("a.bin")
    try Data([9, 9]).write(to: target)
    backend.files[9] = .success(.file(source))

    let result = write(id: 9, to: target)

    XCTAssertNil(result.error)
    XCTAssertEqual(try Data(contentsOf: target), Data([1]))
  }

  func testAMissingLocalFileFailsTheWriteAndIsReported() {
    backend.files[4] = .success(.file(directory.appendingPathComponent("gone.bin")))
    let reported = expectation(description: "reported")
    backend.onWritten = { reported.fulfill() }

    let result = write(id: 4)
    wait(for: [reported], timeout: 5)

    XCTAssertNotNil(result.error)
    XCTAssertNotNil(backend.written[0].error)
  }

  func testAFailedFetchProducesNoFileAndIsNotReportedAsWritten() {
    backend.files[2] = .failure(DragOutError.fetchFailed)

    let result = write(id: 2, name: "gone.pdf")

    XCTAssertNotNil(result.error)
    XCTAssertFalse(FileManager.default.fileExists(atPath: result.url.path))
    XCTAssertTrue(backend.written.isEmpty)
  }

  func testAFailedWriteIsReportedToDart() {
    backend.files[3] = .success(.data(Data([9])))
    let reported = expectation(description: "reported")
    backend.onWritten = { reported.fulfill() }

    let result = write(id: 3, to: directory.appendingPathComponent("missing-folder/a.bin"))
    wait(for: [reported], timeout: 5)

    XCTAssertNotNil(result.error)
    XCTAssertEqual(backend.written.count, 1)
    XCTAssertNotNil(backend.written[0].error)
  }

  func testAPromiseWithoutAnIdFails() {
    let provider = NSFilePromiseProvider(fileType: "public.data", delegate: promises)
    let done = expectation(description: "completion")
    var completionError: Error?

    promises.filePromiseProvider(
      provider, writePromiseTo: directory.appendingPathComponent("x")
    ) { error in
      completionError = error
      done.fulfill()
    }
    wait(for: [done], timeout: 5)

    XCTAssertNotNil(completionError)
  }

  func testAPromiseDartNeverAnswersTimesOutAndIsReported() {
    backend.silent = [5]

    let result = write(id: 5)

    XCTAssertNotNil(result.error)
    XCTAssertEqual(backend.timedOut, [5])
    XCTAssertFalse(FileManager.default.fileExists(atPath: result.url.path))
  }

  func testAnAnswerAfterTheTimeoutWritesNothing() {
    backend.silent = [6]
    let result = write(id: 6)
    XCTAssertNotNil(result.error)

    backend.lateReplies.first?(.success(.data(Data([1]))))
    let settled = expectation(description: "settled")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { settled.fulfill() }
    wait(for: [settled], timeout: 5)

    XCTAssertFalse(FileManager.default.fileExists(atPath: result.url.path))
    XCTAssertTrue(backend.written.isEmpty)
  }

  func testErrorsReadAsSentencesToAPerson() {
    for error in [DragOutError.fetchFailed, .timedOut, .unknownPromise] {
      let message = (error as NSError).localizedDescription
      XCTAssertTrue(message.hasPrefix("Hermes"), message)
      XCTAssertFalse(message.contains("DragOutError"), message)
    }
  }

  func testTextGoesOutAsPlainTextAndMarkdown() {
    let item = DragOutPasteboard.textItem("# Hello\n\n**bold**")

    XCTAssertEqual(item.string(forType: .string), "# Hello\n\n**bold**")
    XCTAssertEqual(item.string(forType: DragOutPasteboard.markdown), "# Hello\n\n**bold**")
    XCTAssertEqual(
      item.writableTypes(for: NSPasteboard.withUniqueName()).count, 2)
  }

  // MARK: Controller

  func testAFileCanLeaveTheAppButNotLandBackInIt() {
    XCTAssertEqual(DragOutController.operationMask(for: .outsideApplication), .copy)
    XCTAssertEqual(DragOutController.operationMask(for: .withinApplication), [])
  }

  private final class Harness {
    let controller: DragOutController
    let window: NSWindow
    var began: [(items: [NSDraggingItem], event: NSEvent)] = []
    var mouseUps: [NSEvent] = []
    var pressed = 1
    var ownsEvents = true

    init(backend: DragOutBackend) {
      window = NSWindow(
        contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
        styleMask: [.titled], backing: .buffered, defer: false)
      window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
      var this: Harness!
      let env = DragOutEnvironment(
        pressedMouseButtons: { this.pressed },
        ownsEvent: { _, _ in this.ownsEvents },
        beginSession: { _, items, event, _ in this.began.append((items, event)) },
        deliverMouseUp: { this.mouseUps.append($0) })
      controller = DragOutController(
        view: window.contentView!, backend: backend, environment: env)
      this = self
    }

    func mouse(_ type: NSEvent.EventType) -> NSEvent {
      NSEvent.mouseEvent(
        with: type, location: NSPoint(x: 40, y: 50), modifierFlags: [],
        timestamp: 0, windowNumber: window.windowNumber, context: nil,
        eventNumber: 0, clickCount: 1, pressure: 1)!
    }
  }

  private let fileArguments: [String: Any] = [
    "id": 1, "type": "file", "name": "a.pdf", "fileType": "com.adobe.pdf",
  ]

  func testNoDragStartsWithoutAMouseDownTheWindowSaw() {
    let h = Harness(backend: backend)

    XCTAssertFalse(h.controller.startDrag(fileArguments))
    XCTAssertTrue(h.began.isEmpty)
  }

  func testNoDragStartsOnceTheButtonIsUp() {
    let h = Harness(backend: backend)
    h.controller.record(h.mouse(.leftMouseDown))
    h.pressed = 0

    XCTAssertFalse(h.controller.startDrag(fileArguments))
    XCTAssertTrue(h.began.isEmpty)
  }

  func testEventsOfOtherWindowsAreIgnored() {
    let h = Harness(backend: backend)
    h.ownsEvents = false
    h.controller.record(h.mouse(.leftMouseDown))

    XCTAssertFalse(h.controller.startDrag(fileArguments))
  }

  func testAMouseUpForgetsTheGesture() {
    let h = Harness(backend: backend)
    h.controller.record(h.mouse(.leftMouseDown))
    h.controller.record(h.mouse(.leftMouseUp))

    XCTAssertFalse(h.controller.startDrag(fileArguments))
  }

  func testADragStartsFromTheLatestEventAndOnlyOneAtATime() {
    let h = Harness(backend: backend)
    h.controller.record(h.mouse(.leftMouseDown))
    let dragged = h.mouse(.leftMouseDragged)
    h.controller.record(dragged)

    XCTAssertTrue(h.controller.startDrag(fileArguments))
    XCTAssertEqual(h.began.count, 1)
    XCTAssertEqual(h.began[0].items.count, 1)
    XCTAssertTrue(h.began[0].event === dragged)
    XCTAssertEqual(h.controller.activeId, 1)

    var second = fileArguments
    second["id"] = 2
    XCTAssertFalse(h.controller.startDrag(second))
    XCTAssertEqual(h.began.count, 1)
  }

  func testMalformedRequestsStartNothing() {
    let h = Harness(backend: backend)
    h.controller.record(h.mouse(.leftMouseDown))

    XCTAssertFalse(h.controller.startDrag(["id": 1, "type": "file"]), "no name")
    XCTAssertFalse(h.controller.startDrag(["id": 1, "type": "text"]), "no text")
    XCTAssertFalse(h.controller.startDrag(["id": 1, "type": "folder", "name": "x"]))
    XCTAssertFalse(h.controller.startDrag(["type": "file", "name": "x"]), "no id")
    XCTAssertTrue(h.began.isEmpty)
    XCTAssertNil(h.controller.activeId)
  }

  func testTextStartsADrag() {
    let h = Harness(backend: backend)
    h.controller.record(h.mouse(.leftMouseDown))

    XCTAssertTrue(h.controller.startDrag(["id": 3, "type": "text", "text": "hi"]))
    XCTAssertEqual(h.began.count, 1)
  }

  func testTheEndOfASessionReleasesTheMouseInTheFlutterView() {
    let h = Harness(backend: backend)
    h.controller.record(h.mouse(.leftMouseDown))
    XCTAssertTrue(h.controller.startDrag(fileArguments))
    let screenPoint = h.window.convertPoint(toScreen: NSPoint(x: 120, y: 80))

    h.controller.sessionEnded(at: screenPoint, operation: .copy)

    XCTAssertEqual(h.mouseUps.count, 1)
    XCTAssertEqual(h.mouseUps[0].type, .leftMouseUp)
    let location = h.mouseUps[0].locationInWindow
    XCTAssertEqual(location.x, 120, accuracy: 0.5)
    XCTAssertEqual(location.y, 80, accuracy: 0.5)
    XCTAssertEqual(backend.endedSessions.count, 1)
    XCTAssertEqual(backend.endedSessions[0].id, 1)
    XCTAssertTrue(backend.endedSessions[0].copied)
    XCTAssertNil(h.controller.activeId)
  }

  func testACancelledSessionReleasesTheMouseAndReportsNoReceiver() {
    let h = Harness(backend: backend)
    h.controller.record(h.mouse(.leftMouseDown))
    XCTAssertTrue(h.controller.startDrag(fileArguments))

    h.controller.sessionEnded(at: .zero, operation: [])

    XCTAssertEqual(h.mouseUps.count, 1)
    XCTAssertFalse(backend.endedSessions[0].copied)
  }

  func testAfterASessionANewDragCanStart() {
    let h = Harness(backend: backend)
    h.controller.record(h.mouse(.leftMouseDown))
    XCTAssertTrue(h.controller.startDrag(fileArguments))
    h.controller.sessionEnded(at: .zero, operation: .copy)
    h.controller.record(h.mouse(.leftMouseDown))

    var next = fileArguments
    next["id"] = 2
    XCTAssertTrue(h.controller.startDrag(next))
  }
}
