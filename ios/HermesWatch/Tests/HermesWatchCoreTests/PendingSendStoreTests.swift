import XCTest
@testable import HermesWatchCore

final class PendingSendStoreTests: XCTestCase {
  private var directory: URL!
  override func setUp() {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  }
  override func tearDown() { try? FileManager.default.removeItem(at: directory) }

  private func record(_ id: String = "send", revision: Int = 4) -> PendingSendRecord {
    PendingSendRecord(sendId: id, contextId: "owner", revision: revision, profile: "default", threadId: nil,
      text: "hello", localMessageId: "local-\(id)", createdAt: Date(timeIntervalSince1970: 100), recoveryState: .pending)
  }

  func testRestartRetainsOriginalIdentityTimestampAndText() throws {
    try FilePendingSendStore(directory: directory).save(record())
    XCTAssertEqual(try FilePendingSendStore(directory: directory).records(contextId: "owner", revision: 4), [record()])
  }

  func testRevisionMismatchCannotRestorePrivateRecord() throws {
    let store = FilePendingSendStore(directory: directory)
    try store.save(record())
    XCTAssertEqual(try store.records(contextId: "owner", revision: 5), [])
    XCTAssertEqual(try store.records(contextId: "other", revision: 4), [])
  }

  func testExistingIdentityCannotRefreshTimestamp() throws {
    let store = FilePendingSendStore(directory: directory)
    try store.save(record())
    let altered = PendingSendRecord(sendId: "send", contextId: "owner", revision: 4, profile: "default", threadId: nil,
      text: "hello", localMessageId: "local-send", createdAt: Date(timeIntervalSince1970: 200), recoveryState: .pending)
    XCTAssertThrowsError(try store.save(altered))
    XCTAssertEqual(try store.records(contextId: "owner", revision: 4), [record()])
  }

  func testWriteFailureDoesNotCreateRecoverableRecord() throws {
    let store = FilePendingSendStore(directory: directory, write: { _, _ in throw CocoaError(.fileWriteNoPermission) })
    XCTAssertThrowsError(try store.save(record()))
    XCTAssertEqual(try FilePendingSendStore(directory: directory).records(contextId: "owner", revision: 4), [])
  }

  func testPurgeTombstoneBlocksRestartAndLateWritesWhenDeletionFails() throws {
    let store = FilePendingSendStore(directory: directory, remove: { _ in throw CocoaError(.fileWriteNoPermission) })
    try store.save(record())
    try store.invalidate(contextId: "owner", revision: 4)
    let restarted = FilePendingSendStore(directory: directory)
    XCTAssertEqual(try restarted.records(contextId: "owner", revision: 4), [])
    XCTAssertThrowsError(try restarted.save(record("late")))
  }

  func testInvalidatedRecordsCannotConsumeNewRevisionCapacity() throws {
    let store = FilePendingSendStore(directory: directory, capacity: 1, remove: { _ in throw CocoaError(.fileWriteNoPermission) })
    try store.save(record())
    try store.invalidate(contextId: "owner", revision: 4)
    try store.save(record("next", revision: 5))
    XCTAssertEqual(try store.records(contextId: "owner", revision: 5), [record("next", revision: 5)])
  }

  func testCompletedIdentityCannotBecomePendingAgain() throws {
    let store = FilePendingSendStore(directory: directory)
    var completed = record()
    completed.recoveryState = .completed
    try store.save(completed)
    XCTAssertThrowsError(try store.save(record()))
    XCTAssertEqual(try store.records(contextId: "owner", revision: 4), [])
  }

  func testDiscardedIdentityCannotReturnPendingAfterRestart() throws {
    let store = FilePendingSendStore(directory: directory)
    let original = record()
    try store.save(original)
    try store.discard(sendId: original.sendId, contextId: original.contextId, revision: original.revision)
    let restarted = FilePendingSendStore(directory: directory)
    XCTAssertThrowsError(try restarted.save(original))
    XCTAssertEqual(try restarted.records(contextId: "owner", revision: 4), [])
  }

  func testTerminalMarkerHidesPayloadWhenCleanupWriteFails() throws {
    let store = FilePendingSendStore(directory: directory)
    try store.save(record())
    let failing = FilePendingSendStore(directory: directory, write: { data, file in
      if file.lastPathComponent == "pending.json" { throw CocoaError(.fileWriteNoPermission) }
      try FilePendingSendStore.protectedWrite(data, file)
    })
    XCTAssertThrowsError(try failing.discard(sendId: "send", contextId: "owner", revision: 4))
    let restarted = FilePendingSendStore(directory: directory)
    XCTAssertEqual(try restarted.records(contextId: "owner", revision: 4), [])
    XCTAssertThrowsError(try restarted.save(record()))
  }

  func testDiscardReleasesCapacityWithoutEvictingPendingRecord() throws {
    let store = FilePendingSendStore(directory: directory, capacity: 1)
    try store.save(record())
    XCTAssertThrowsError(try store.save(record("next")))
    try store.discard(sendId: "send", contextId: "owner", revision: 4)
    try store.save(record("next"))
    XCTAssertEqual(try store.records(contextId: "owner", revision: 4), [record("next")])
  }
  func testCompletedSendsRemovePrivatePayloadAndReleaseCapacity() throws {
    let store = FilePendingSendStore(directory: directory, capacity: 1)
    for index in 0..<25 {
      var completed = record("completed-\(index)")
      try store.save(completed)
      completed.recoveryState = .completed
      try store.save(completed)
    }
    let data = try Data(contentsOf: directory.appendingPathComponent("pending.json"))
    XCTAssertEqual(try JSONDecoder().decode([PendingSendRecord].self, from: data), [])
    try store.save(record("next"))
    XCTAssertEqual(try store.records(contextId: "owner", revision: 4), [record("next")])
    XCTAssertThrowsError(try store.save(record("completed-0")))
  }

  func testExistingThreadCannotChangeUnderSameIdentity() throws {
    let store = FilePendingSendStore(directory: directory)
    var original = PendingSendRecord(sendId: "existing", contextId: "owner", revision: 4,
      profile: "default", threadId: "thread-a", text: "hello", localMessageId: "local",
      createdAt: Date(timeIntervalSince1970: 100), recoveryState: .pending)
    XCTAssertEqual(original.originalThreadId, "thread-a")
    try store.save(original)
    original.threadId = "thread-b"
    XCTAssertThrowsError(try store.save(original))
  }

  func testNewChatCanBindOnceWithoutChangingOriginalTarget() throws {
    let store = FilePendingSendStore(directory: directory)
    var pending = record()
    try store.save(pending)
    pending.threadId = "bound-thread"
    try store.save(pending)
    XCTAssertNil(pending.originalThreadId)
    pending.threadId = "another-thread"
    XCTAssertThrowsError(try store.save(pending))
  }

}
