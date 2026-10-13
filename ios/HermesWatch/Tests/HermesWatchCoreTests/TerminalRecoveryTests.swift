import XCTest
@testable import HermesWatchCore

private final class DiscardFailingStore: PendingSendStore {
  let inner: FilePendingSendStore
  var failDiscard = true
  init(directory: URL) { inner = FilePendingSendStore(directory: directory) }
  func records(contextId: String, revision: Int) throws -> [PendingSendRecord] { try inner.records(contextId: contextId, revision: revision) }
  func save(_ record: PendingSendRecord) throws { try inner.save(record) }
  func discard(sendId: String, contextId: String, revision: Int) throws {
    if failDiscard { throw CocoaError(.fileWriteNoPermission) }
    try inner.discard(sendId: sendId, contextId: contextId, revision: revision)
  }
  func invalidate(contextId: String, revision: Int) throws { try inner.invalidate(contextId: contextId, revision: revision) }
}

private final class PersistFailingStore: PendingSendStore {
  let inner: FilePendingSendStore
  var failSave = false
  init(directory: URL) { inner = FilePendingSendStore(directory: directory) }
  func records(contextId: String, revision: Int) throws -> [PendingSendRecord] { try inner.records(contextId: contextId, revision: revision) }
  func save(_ record: PendingSendRecord) throws {
    if failSave { throw CocoaError(.fileWriteNoPermission) }
    try inner.save(record)
  }
  func discard(sendId: String, contextId: String, revision: Int) throws { try inner.discard(sendId: sendId, contextId: contextId, revision: revision) }
  func invalidate(contextId: String, revision: Int) throws { try inner.invalidate(contextId: contextId, revision: revision) }
}

@MainActor
private final class TerminalDeferredClient: HermesClient {
  let session = recoveryFixtureSession()
  var sessionState: WatchSessionState? { session }
  var requested: (() -> Void)?
  var answer: CheckedContinuation<SendResult, Error>?
  func prepareRecovery() async throws {}
  func threads() async throws -> [ThreadSummary] { [] }
  func messages(threadId: String) async throws -> [ChatMessage] { [] }
  func transcribe(audio: Data, mimeType: String) async throws -> String { "" }
  func send(threadId: String?, text: String, sendId: String, retry: Bool) async throws -> SendResult {
    try await withCheckedThrowingContinuation { answer = $0; requested?() }
  }
}

@MainActor
final class TerminalRecoveryTests: XCTestCase {
  func testRestoredPendingReplyWithPersistenceFailureCannotEnableResend() async throws {
    try await assertRestoredProofSurvivesPersistenceFailure(SendResult(threadId: nil, text: "", failed: false, recoveryState: .pending), expected: .pending)
  }

  func testRestoredApprovalWaitWithPersistenceFailureCannotEnableResend() async throws {
    try await assertRestoredProofSurvivesPersistenceFailure(SendResult(threadId: nil, text: "", failed: false, waiting: .approval), expected: .pending)
  }

  func testRestoredNotSentReplyWithPersistenceFailureRetainsTerminalProof() async throws {
    try await assertRestoredProofSurvivesPersistenceFailure(SendResult(threadId: nil, text: "", failed: false, recoveryState: .notSent), expected: .notSent)
  }

  private func assertRestoredProofSurvivesPersistenceFailure(_ reply: SendResult, expected: SendRecoveryState) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = PersistFailingStore(directory: directory)
    let original = PendingSendRecord(sendId: "restored", contextId: "test-context", revision: 1, profile: nil, threadId: nil,
      text: "Original", localMessageId: "local-restored", createdAt: Date(timeIntervalSince1970: 100), recoveryState: .uncertain)
    try store.save(original)
    let client = FakeClient()
    client.sendResult = .success(reply)
    let model = ConversationModel(client: client, threadId: nil, store: store)
    await model.load()
    store.failSave = true

    await model.checkResult()

    XCTAssertTrue(model.checkAttempted)
    XCTAssertEqual(model.recovery?.recoveryState, expected)
    XCTAssertEqual(model.recovery?.sendId, original.sendId)
    XCTAssertEqual(model.recovery?.createdAt, original.createdAt)
    XCTAssertEqual(model.messages.map(\.role), [.user])
    XCTAssertEqual(model.phase, .failed(.recoveryStorage))
    XCTAssertEqual(model.canSendAgain, expected == .notSent)
    XCTAssertEqual(client.sends.count, 1)
  }

  func testRestoredStoredPendingAloneDoesNotProveAcceptance() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FilePendingSendStore(directory: directory)
    try store.save(PendingSendRecord(sendId: "restored", contextId: "test-context", revision: 1, profile: nil, threadId: nil,
      text: "Original", localMessageId: "local-restored", createdAt: Date(timeIntervalSince1970: 100), recoveryState: .pending))
    let client = FakeClient()
    client.sendResult = .failure(HermesClientError.phoneUnreachable)
    let model = ConversationModel(client: client, threadId: nil, store: store)
    await model.load()
    await model.checkResult()
    XCTAssertEqual(model.recovery?.recoveryState, .uncertain)
    XCTAssertTrue(model.canSendAgain)
  }

  func testConfirmedResendRetainsBothDurableIdentitiesAndOriginalTimestampsAcrossRestart() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let client = FakeClient()
    client.sendResult = .failure(HermesClientError.phoneUnreachable)
    let model = ConversationModel(client: client, threadId: nil, store: FilePendingSendStore(directory: directory))
    await model.send("Original")
    let original = try XCTUnwrap(model.recovery)
    client.sendResult = .success(SendResult(threadId: nil, text: "", failed: false, recoveryState: .uncertain))
    await model.checkResult()
    await model.requestSendAgain()
    await model.confirmSendAgain()
    let replacement = try XCTUnwrap(model.recovery)

    let restarted = FilePendingSendStore(directory: directory)
    let records = try restarted.records(contextId: "test-context", revision: 1)
    let restoredOriginal = try XCTUnwrap(records.first { $0.sendId == original.sendId })
    let restoredReplacement = try XCTUnwrap(records.first { $0.sendId == replacement.sendId })
    XCTAssertNotEqual(original.sendId, replacement.sendId)
    XCTAssertEqual(records.count, 2)
    XCTAssertEqual(restoredOriginal.createdAt, original.createdAt)
    XCTAssertEqual(restoredOriginal.text, original.text)
    XCTAssertEqual(restoredOriginal.localMessageId, original.localMessageId)
    XCTAssertEqual(restoredReplacement.createdAt, replacement.createdAt)
    XCTAssertEqual(restoredReplacement.text, replacement.text)
    XCTAssertEqual(restoredReplacement.localMessageId, replacement.localMessageId)

    let restoredModel = ConversationModel(client: client, threadId: nil, store: restarted)
    await restoredModel.load()
    XCTAssertEqual(restoredModel.recovery?.sendId, original.sendId)
    XCTAssertEqual(client.sends.count, 3)
  }

  func testDiscardFailureKeepsProvenCompletionIdleAndRetriesOnlyLocalCleanup() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = DiscardFailingStore(directory: directory)
    let client = FakeClient()
    client.sendResult = .success(SendResult(threadId: nil, text: "Proven answer", failed: false))
    let model = ConversationModel(client: client, threadId: nil, store: store)

    await model.send("Original")
    await model.requestSendAgain()
    await model.checkResult()

    XCTAssertEqual(model.phase, .idle)
    XCTAssertEqual(model.messages.map(\.content), ["Original", "Proven answer"])
    XCTAssertNil(model.recovery)
    XCTAssertFalse(model.canSendAgain)
    XCTAssertFalse(model.resendConfirmation)
    XCTAssertEqual(client.sends.count, 1)
    XCTAssertEqual(try FilePendingSendStore(directory: directory).records(contextId: "test-context", revision: 1), [])

    store.failDiscard = false
    await model.load()

    XCTAssertEqual(client.sends.count, 1)
    XCTAssertNil(model.recovery)
    let remaining = try JSONDecoder().decode([PendingSendRecord].self, from: Data(contentsOf: directory.appendingPathComponent("pending.json")))
    XCTAssertTrue(remaining.isEmpty)
  }

  func testTerminalPersistenceFailureCannotReopenKnownCompletion() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    var failTerminal = true
    let store = FilePendingSendStore(directory: directory, write: { data, file in
      if failTerminal && file.lastPathComponent == "terminal.json" { throw CocoaError(.fileWriteNoPermission) }
      try FilePendingSendStore.protectedWrite(data, file)
    })
    let client = FakeClient()
    client.sendResult = .success(SendResult(threadId: nil, text: "Proven answer", failed: false))
    let model = ConversationModel(client: client, threadId: nil, store: store)
    await model.send("Original")
    await model.load()
    XCTAssertEqual(model.messages.map(\.content), ["Original", "Proven answer"])
    XCTAssertEqual(model.phase, .idle)
    XCTAssertNil(model.recovery)
    XCTAssertFalse(model.canSendAgain)
    XCTAssertEqual(client.sends.count, 1)

    failTerminal = false
    await model.load()
    XCTAssertEqual(try store.records(contextId: "test-context", revision: 1), [])
    XCTAssertEqual(client.sends.count, 1)
  }

  func testTwoModelsCannotReviveCompletedIdentityFromLatePendingStatus() async throws {
    try await assertLateStatusDoesNotRevive(.success(SendResult(threadId: nil, text: "", failed: false, recoveryState: .pending)))
  }

  func testLateTransportFailureCannotReviveAnotherModelsCompletion() async throws {
    try await assertLateStatusDoesNotRevive(.failure(HermesClientError.phoneUnreachable))
  }

  private func assertLateStatusDoesNotRevive(_ late: Result<SendResult, Error>) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FilePendingSendStore(directory: directory)
    let client = TerminalDeferredClient()
    let first = ConversationModel(client: client, threadId: nil, store: store)
    let firstRequest = expectation(description: "Original submission")
    client.requested = { firstRequest.fulfill() }
    let submission = Task { await first.send("Original") }
    await fulfillment(of: [firstRequest], timeout: 1)
    let originalAnswer = try XCTUnwrap(client.answer)
    let original = try XCTUnwrap(first.recovery)

    let second = ConversationModel(client: client, threadId: nil, store: FilePendingSendStore(directory: directory))
    await second.load()
    let statusRequest = expectation(description: "Second model status request")
    client.requested = { statusRequest.fulfill() }
    let lookup = Task { await second.checkResult() }
    await fulfillment(of: [statusRequest], timeout: 1)
    let statusAnswer = try XCTUnwrap(client.answer)

    originalAnswer.resume(returning: SendResult(threadId: nil, text: "Proven answer", failed: false))
    await submission.value
    statusAnswer.resume(with: late)
    await lookup.value

    XCTAssertEqual(first.messages.filter { $0.content == "Proven answer" }.count, 1)
    XCTAssertNil(second.recovery)
    XCTAssertEqual(second.phase, .idle)
    XCTAssertFalse(second.canSendAgain)
    XCTAssertEqual(try FilePendingSendStore(directory: directory).records(contextId: "test-context", revision: 1), [])
    XCTAssertThrowsError(try FilePendingSendStore(directory: directory).save(original))
  }
}
