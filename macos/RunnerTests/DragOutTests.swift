import Cocoa
import XCTest

@testable import Hermes

/// A stand-in for Dart: serves the bytes of the promised files and notes what
/// was reported back.
private final class FakeBackend: DragOutBackend {
  var files: [Int: Result<Data, Error>] = [:]
  var read: [Int] = []
  var written: [(id: Int, error: Error?)] = []
  var onWritten: (() -> Void)?

  func readFile(id: Int, completion: @escaping (Result<Data, Error>) -> Void) {
    read.append(id)
    completion(files[id] ?? .failure(DragOutError.unknownPromise))
  }

  func fileWritten(id: Int, error: Error?) {
    written.append((id, error))
    onWritten?()
  }

  func ended(id: Int, copied: Bool) {}
}

class DragOutTests: XCTestCase {
  private var backend: FakeBackend!
  private var promises: DragOutFilePromises!
  private var directory: URL!

  override func setUpWithError() throws {
    backend = FakeBackend()
    promises = DragOutFilePromises(backend: backend)
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  override func tearDown() {
    try? FileManager.default.removeItem(at: directory)
  }

  func testPromiseNamesTheFileAsTheItemProposes() {
    let provider = promises.provider(id: 1, name: "report.pdf", fileType: "com.adobe.pdf")

    XCTAssertEqual(provider.fileType, "com.adobe.pdf")
    XCTAssertEqual(
      promises.filePromiseProvider(provider, fileNameForType: "com.adobe.pdf"), "report.pdf")
  }

  func testNothingIsReadUntilTheReceiverAsks() {
    _ = promises.provider(id: 1, name: "a.txt", fileType: "public.data")

    XCTAssertTrue(backend.read.isEmpty)
  }

  func testTheReceiversFolderGetsTheBytesFromDart() throws {
    backend.files[7] = .success(Data([1, 2, 3, 0, 255]))
    let provider = promises.provider(id: 7, name: "a.bin", fileType: "public.data")
    let url = directory.appendingPathComponent("a.bin")
    let done = expectation(description: "completion")
    let reported = expectation(description: "reported")
    var completionError: Error?
    backend.onWritten = { reported.fulfill() }

    promises.filePromiseProvider(provider, writePromiseTo: url) { error in
      completionError = error
      done.fulfill()
    }
    wait(for: [done, reported], timeout: 5)

    XCTAssertNil(completionError)
    XCTAssertEqual(try Data(contentsOf: url), Data([1, 2, 3, 0, 255]))
    XCTAssertEqual(backend.read, [7])
    XCTAssertEqual(backend.written.count, 1)
    XCTAssertNil(backend.written[0].error)
  }

  func testAFailedFetchProducesNoFileAndIsNotReportedAsWritten() {
    backend.files[2] = .failure(DragOutError.fetchFailed("fetch"))
    let provider = promises.provider(id: 2, name: "gone.pdf", fileType: "com.adobe.pdf")
    let url = directory.appendingPathComponent("gone.pdf")
    let done = expectation(description: "completion")
    var completionError: Error?

    promises.filePromiseProvider(provider, writePromiseTo: url) { error in
      completionError = error
      done.fulfill()
    }
    wait(for: [done], timeout: 5)

    XCTAssertNotNil(completionError)
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    XCTAssertTrue(backend.written.isEmpty)
  }

  func testAFailedWriteIsReportedToDart() {
    backend.files[3] = .success(Data([9]))
    let provider = promises.provider(id: 3, name: "a.bin", fileType: "public.data")
    let url = directory.appendingPathComponent("missing-folder/a.bin")
    let done = expectation(description: "completion")
    let reported = expectation(description: "reported")
    var completionError: Error?
    backend.onWritten = { reported.fulfill() }

    promises.filePromiseProvider(provider, writePromiseTo: url) { error in
      completionError = error
      done.fulfill()
    }
    wait(for: [done, reported], timeout: 5)

    XCTAssertNotNil(completionError)
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

  func testTextGoesOutAsPlainTextAndMarkdown() {
    let item = DragOutPasteboard.textItem("# Hello\n\n**bold**")

    XCTAssertEqual(item.string(forType: .string), "# Hello\n\n**bold**")
    XCTAssertEqual(item.string(forType: DragOutPasteboard.markdown), "# Hello\n\n**bold**")
    XCTAssertEqual(
      item.writableTypes(for: NSPasteboard.withUniqueName()).count, 2)
  }
}
