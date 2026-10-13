import XCTest
@testable import HermesWatchCore

@MainActor
final class SessionPrivacyTests: XCTestCase {
  func testLogoutClearsOpenConversationAndList() async {
    let cache = MemoryChatCache()
    let inner = FakeClient()
    let session = WatchSessionState()
    let client = CachingClient(inner: inner, cache: cache, session: session)
    inner.messagesResult = .success([ChatMessage(id: "m", role: .assistant, content: "Private", at: .distantPast)])
    inner.threadsResult = .success([ThreadSummary(id: "p/s", title: "Private", updatedAt: nil, pinned: false)])
    let conversation = ConversationModel(client: client, threadId: "p/s")
    let list = ThreadListModel(client: client)
    await conversation.load()
    await list.load()

    session.invalidate()

    XCTAssertTrue(conversation.messages.isEmpty)
    XCTAssertNil(conversation.threadId)
    XCTAssertNil(conversation.handoff)
    XCTAssertFalse(conversation.permitsOriginalTitle)
    XCTAssertEqual(conversation.phase, .failed(.signedOut))
    XCTAssertEqual(list.state, .failed(.signedOut))
  }

  func testSessionRevisionSurvivesRestartAndRejectsDelayedLogout() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let first = WatchSessionState(defaults: defaults)
    first.receive(["watchSession": ["revision": 2, "usable": true, "protocolVersion": 2, "contextId": "test-context"]])
    let restarted = WatchSessionState(defaults: defaults)

    restarted.receive(["watchSession": ["revision": 1, "usable": false]])

    XCTAssertTrue(restarted.usable)
    XCTAssertEqual(restarted.revision, 2)
    XCTAssertEqual(restarted.generation, 0)
  }

  func testCleanupTombstoneBlocksPrivateReadsAndWritesUntilRetrySucceeds() {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let original = FileChatCache(directory: directory)
    original.save(threads: [ThreadSummary(id: "p/s", title: "Private", updatedAt: nil, pinned: false)])
    let blocked = FileChatCache(directory: directory, remove: { _ in throw CocoaError(.fileWriteNoPermission) })

    blocked.clear()
    blocked.save(threads: [])

    XCTAssertNil(blocked.threads())
    XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathExtension("cleanup-pending").path))
    let restarted = FileChatCache(directory: directory)
    restarted.retryCleanup()
    XCTAssertNil(restarted.threads())
    XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathExtension("cleanup-pending").path))
  }
}

@MainActor
private final class PrivacyDeferredClient: HermesClient {
  let fixtureSession = recoveryFixtureSession()
  var sessionState: WatchSessionState? { fixtureSession }
  let recoveryStore: PendingSendStore = MemoryPendingSendStore()
  func prepareRecovery() async throws {}
  func forgetSend(sendId: String) async throws {}
  var messageReply: CheckedContinuation<[ChatMessage], Error>?
  var transcriptReply: CheckedContinuation<String, Error>?
  let messagesRequested = XCTestExpectation(description: "messages continuation installed")
  let transcriptionRequested = XCTestExpectation(description: "transcription continuation installed")
  var sends = 0
  func threads() async throws -> [ThreadSummary] { [] }
  func messages(threadId: String) async throws -> [ChatMessage] {
    try await withCheckedThrowingContinuation {
      messageReply = $0
      messagesRequested.fulfill()
    }
  }
  func send(threadId: String?, text: String, sendId: String, retry: Bool) async throws -> SendResult {
    sends += 1
    return SendResult(threadId: threadId, text: "Late", failed: false)
  }
  func transcribe(audio: Data, mimeType: String) async throws -> String {
    try await withCheckedThrowingContinuation {
      transcriptReply = $0
      transcriptionRequested.fulfill()
    }
  }
}

extension SessionPrivacyTests {
  func testLateLoadedMessagesCannotRestoreClearedCacheOrConversation() async throws {
    let inner = PrivacyDeferredClient()
    let session = WatchSessionState()
    let cache = MemoryChatCache()
    let client = CachingClient(inner: inner, cache: cache, session: session)
    let model = ConversationModel(client: client, threadId: "p/s")
    let load = Task { await model.load() }
    defer { load.cancel() }
    await fulfillment(of: [inner.messagesRequested], timeout: 2)
    let messageReply = try XCTUnwrap(inner.messageReply)
    session.invalidate()
    messageReply.resume(returning: [ChatMessage(id: "m", role: .assistant, content: "Private", at: .distantPast)])
    await load.value

    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertTrue(cache.savedMessages.isEmpty)
    XCTAssertEqual(model.phase, .failed(.signedOut))
  }

  func testInvalidatedTranscriptionCannotSendOrRestoreRetryAudio() async throws {
    let inner = PrivacyDeferredClient()
    let session = WatchSessionState()
    let model = ConversationModel(client: inner, threadId: nil, session: session)
    let recording = Task { await model.sendVoice(Data([1, 2]), mimeType: "audio/mp4") }
    defer { recording.cancel() }
    await fulfillment(of: [inner.transcriptionRequested], timeout: 2)
    let transcriptReply = try XCTUnwrap(inner.transcriptReply)
    session.invalidate()
    transcriptReply.resume(returning: "Private transcript")
    await recording.value

    XCTAssertEqual(inner.sends, 0)
    XCTAssertNil(model.unsentVoice)
    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertEqual(model.phase, .failed(.signedOut))
  }

  func testCleanupDiagnosticsFailureCannotKeepContentVisible() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let state = WatchSessionState(defaults: defaults, diagnostics: { _, _, _ in throw CocoaError(.fileWriteUnknown) })
    var cleaned = false
    _ = state.register { cleaned = true }

    state.invalidate()

    XCTAssertFalse(state.usable)
    XCTAssertTrue(cleaned)
  }
}

extension SessionPrivacyTests {
  func testFailedTombstoneAndDeletionBlockEveryCacheInstanceUntilCleanupSucceeds() {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let original = FileChatCache(directory: directory)
    original.save(threads: [ThreadSummary(id: "p/s", title: "Private", updatedAt: nil, pinned: false)])
    var outcomes = [Bool]()
    let failed = FileChatCache(
      directory: directory,
      remove: { _ in throw CocoaError(.fileWriteNoPermission) },
      persistTombstone: { _ in throw CocoaError(.fileWriteOutOfSpace) },
      diagnostics: { outcomes.append($0) }
    )

    failed.clear()
    failed.save(threads: [])

    XCTAssertTrue(failed.cleanupPending)
    XCTAssertNil(failed.threads())
    XCTAssertTrue(outcomes.allSatisfy { !$0 })
    let second = FileChatCache(directory: directory, remove: { _ in throw CocoaError(.fileWriteNoPermission) })
    XCTAssertNil(second.threads())
    original.retryCleanup()
    XCTAssertFalse(original.cleanupPending)
    XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
  }

  func testTombstoneWriteFailureStillAttemptsDeletionDespiteLoggerFailure() {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    FileChatCache(directory: directory).save(threads: [])
    let cache = FileChatCache(
      directory: directory,
      persistTombstone: { _ in throw CocoaError(.fileWriteOutOfSpace) },
      diagnostics: { _ in throw CocoaError(.fileWriteUnknown) }
    )

    cache.clear()

    XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    XCTAssertFalse(cache.cleanupPending)
  }
}


extension SessionPrivacyTests {
  func testNewerUsableRevisionClearsPrivateStateWhenLogoutDeliveryWasMissed() async {
    let session = WatchSessionState()
    session.receive(["watchSession": ["revision": 1, "usable": true, "protocolVersion": 2, "contextId": "test-context"]])
    let cache = MemoryChatCache()
    let inner = FakeClient()
    inner.messagesResult = .success([ChatMessage(id: "m", role: .assistant, content: "Private", at: .distantPast)])
    let client = CachingClient(inner: inner, cache: cache, session: session)
    let conversation = ConversationModel(client: client, threadId: "p/s")
    await conversation.load()
    let generation = session.generation

    session.receive(["watchSession": ["revision": 3, "usable": true, "protocolVersion": 2, "contextId": "test-context"]])
    session.receive(["watchSession": ["revision": 2, "usable": false]])

    XCTAssertTrue(session.usable)
    XCTAssertEqual(session.revision, 3)
    XCTAssertEqual(session.generation, generation + 1)
    XCTAssertFalse(conversation.permitsOriginalTitle)
    XCTAssertTrue(conversation.messages.isEmpty)
    XCTAssertNil(conversation.threadId)
    XCTAssertTrue(cache.savedMessages.isEmpty)
  }
}


extension SessionPrivacyTests {
  func testOriginalRouteTitleStaysHiddenAfterReloginAndAnotherSend() async {
    let inner = FakeClient()
    let session = WatchSessionState()
    let conversation = ConversationModel(client: inner, threadId: "p/s", session: session)
    XCTAssertTrue(conversation.permitsOriginalTitle)
    session.invalidate()
    session.receive(["watchSession": ["revision": 1, "usable": true, "protocolVersion": 2, "contextId": "test-context"]])
    inner.sendResult = .success(SendResult(threadId: "p/s", text: "New session", failed: false))

    await conversation.send("New message")

    XCTAssertFalse(conversation.permitsOriginalTitle)
    XCTAssertEqual(conversation.threadId, "p/s")
  }
}
