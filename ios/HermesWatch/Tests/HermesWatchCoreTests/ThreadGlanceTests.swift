import XCTest

@testable import HermesWatchCore

final class ThreadGlanceTests: XCTestCase {
  private let first = Date(timeIntervalSince1970: 100)
  private let later = Date(timeIntervalSince1970: 200)

  func testFirstFreshObservationEstablishesABaseline() {
    let thread = ThreadSummary(id: watchFixtureId("s1"), title: "Chat", updatedAt: first, pinned: false)
    var seen = ThreadSeenMarkers()
    seen.observeFresh([thread])
    XCTAssertFalse(seen.isUpdated(thread))
  }

  func testReadingCapturedUpdateDoesNotClearANewerUpdate() {
    let old = ThreadSummary(id: watchFixtureId("s1"), title: "Chat", updatedAt: first, pinned: false)
    let fresh = ThreadSummary(id: old.id, title: "Chat", updatedAt: later, pinned: false)
    var seen = ThreadSeenMarkers()
    seen.observeFresh([old])
    seen.observeFresh([fresh])
    seen.markRead(threadId: old.id, updatedAt: first)
    XCTAssertTrue(seen.isUpdated(fresh))
    seen.markRead(threadId: fresh.id, updatedAt: later)
    XCTAssertFalse(seen.isUpdated(fresh))
  }

  func testUnknownUpdateTimeDoesNotClaimUpdated() {
    let thread = ThreadSummary(id: watchFixtureId("s1"), title: "Chat", updatedAt: nil, pinned: false)
    var seen = ThreadSeenMarkers()
    seen.observeFresh([thread])
    XCTAssertFalse(seen.isUpdated(thread))
  }

  func testStatusAndAccessibilityNameStateWithoutColor() {
    let thread = ThreadSummary(id: "s1", title: "Backup", updatedAt: nil, pinned: true, status: .approval)
    XCTAssertEqual(ThreadGlancePresentation.status(thread, saved: true), "Saved status: Approval")
    XCTAssertEqual(ThreadGlancePresentation.accessibilityLabel(thread, saved: true, updated: true), "Backup. Pinned. Saved status: Approval. Updated on this watch")
    XCTAssertEqual(ThreadGlancePresentation.status(ThreadSummary(id: "old", title: "Old", updatedAt: nil, pinned: false), saved: false), "Status unknown")
  }

  func testUnknownFreshnessRemainsUnknown() {
    XCTAssertEqual(ThreadGlancePresentation.savedFreshness(nil), "Saved data. Fetch time unknown.")
  }
}

@MainActor
final class ThreadGlanceRelayTests: XCTestCase {
  func testOptionalMetadataDecodesAndUnknownStatusStaysUnknown() async throws {
    let transport = FakeTransport()
    transport.reply = .success(["ok": true, "activeProfile": "work", "fetchedAt": 100,
      "threads": [["id": watchFixtureId("s1"), "title": "Backup", "status": "running"],
        ["id": watchFixtureId("s2"), "title": "Old", "status": "idle"]]])
    let listing = try await RelayClient(transport: transport).threadListing()
    XCTAssertEqual(listing.activeProfile, "work")
    XCTAssertEqual(listing.fetchedAt, Date(timeIntervalSince1970: 100))
    XCTAssertEqual(listing.threads.map(\.status), [.running, nil])
  }

  func testOldPeerMetadataIsUnknownAfterIdentityHandshake() async throws {
    let transport = FakeTransport()
    transport.reply = .success(["ok": true, "threads": [["id": watchFixtureId("s1"), "title": "Old"]]])
    let listing = try await RelayClient(transport: transport).threadListing()
    XCTAssertNil(listing.activeProfile)
    XCTAssertNil(listing.fetchedAt)
    XCTAssertNil(listing.threads.first?.status)
  }
}

@MainActor
final class ThreadGlanceCacheTests: XCTestCase {
  private var directory: URL!
  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  }
  override func tearDownWithError() throws { try? FileManager.default.removeItem(at: directory) }

  func testSavedMetadataAndSeenBaselineSurviveReopening() {
    let cache = FileChatCache(directory: directory)
    let thread = ThreadSummary(id: watchFixtureId("s1"), title: "Chat", updatedAt: Date(timeIntervalSince1970: 100), pinned: false, status: .question)
    let listing = ThreadListing(threads: [thread], activeProfile: "work", fetchedAt: Date(timeIntervalSince1970: 80))
    var seen = ThreadSeenMarkers()
    seen.observeFresh([thread])
    cache.save(listing: listing)
    cache.save(seenMarkers: seen)
    let reopened = FileChatCache(directory: directory)
    XCTAssertEqual(reopened.listing(), listing)
    let newer = ThreadSummary(id: thread.id, title: thread.title, updatedAt: Date(timeIntervalSince1970: 200), pinned: false)
    XCTAssertTrue(reopened.seenMarkers().isUpdated(newer))
  }

  func testLegacyCacheHasUnknownFreshness() throws {
    let thread = ThreadSummary(id: watchFixtureId("s1"), title: "Old", updatedAt: nil, pinned: false)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try JSONEncoder().encode([thread]).write(to: directory.appendingPathComponent("threads.json"))
    let listing = FileChatCache(directory: directory).listing()
    XCTAssertEqual(listing?.threads, [thread])
    XCTAssertNil(listing?.fetchedAt)
    XCTAssertNil(listing?.activeProfile)
  }

  func testFailedReadKeepsNewerUpdateAndContextResetClearsMetadata() async {
    let cache = FileChatCache(directory: directory)
    let inner = FakeClient()
    let client = CachingClient(inner: inner, cache: cache, session: inner.sessionState)
    let old = ThreadSummary(id: watchFixtureId("s1"), title: "Chat", updatedAt: Date(timeIntervalSince1970: 100), pinned: false)
    inner.threadsResult = .success([old])
    let model = ThreadListModel(client: client)
    await model.load()
    let fresh = ThreadSummary(id: old.id, title: old.title, updatedAt: Date(timeIntervalSince1970: 200), pinned: false)
    inner.threadsResult = .success([fresh])
    await model.load()
    inner.messagesResult = .failure(HermesClientError.phoneUnreachable)
    await ConversationModel(client: client, threadId: old.id).load()
    XCTAssertTrue(model.isUpdated(fresh))
    inner.fixtureSession.acceptContext("other-context", revision: 2)
    XCTAssertFalse(model.isUpdated(fresh))
    XCTAssertNil(cache.listing())
    XCTAssertNil(model.activeProfile)
  }

  func testContextScopedThreadIdsDoNotShareSeenTime() {
    var seen = ThreadSeenMarkers()
    let old = ThreadSummary(id: watchFixtureId("s1"), title: "Chat", updatedAt: Date(timeIntervalSince1970: 100), pinned: false)
    seen.observeFresh([old])
    let other = ThreadSummary(id: WatchThreadId(contextId: "other-context", profile: "work", sessionId: "s1").encode(), title: "Chat", updatedAt: Date(timeIntervalSince1970: 200), pinned: false)
    seen.observeFresh([other])
    XCTAssertFalse(seen.isUpdated(other))
  }

  func testFailedAtomicMessageWriteKeepsOldMessagesAndTheirFetchTime() async throws {
    var cache = FileChatCache(directory: directory)
    let id = watchFixtureId("s1")
    let oldTime = Date(timeIntervalSince1970: 100)
    let old = ChatMessage(id: "old", role: .assistant, content: "Saved reply", at: oldTime)
    cache.save(messages: [old], fetchedAt: oldTime, threadId: id)
    cache.persist = { _, _ in throw CocoaError(.fileWriteOutOfSpace) }
    let inner = FakeClient()
    let fresh = ChatMessage(id: "fresh", role: .assistant, content: "Fresh reply", at: Date(timeIntervalSince1970: 200))
    inner.messagesResult = .success([fresh])
    let client = CachingClient(inner: inner, cache: cache, session: inner.sessionState)

    let loaded = try await client.messages(threadId: id)

    let reopened = FileChatCache(directory: directory)
    XCTAssertEqual(loaded, [fresh])
    XCTAssertEqual(reopened.messages(threadId: id), [old])
    XCTAssertEqual(reopened.messagesFetchedAt(threadId: id), oldTime)
  }

  func testLegacyMessageArrayDoesNotAdoptASeparateFetchTimestamp() throws {
    let id = watchFixtureId("s1")
    let message = ChatMessage(id: "old", role: .assistant, content: "Saved reply", at: .distantPast)
    let messagesDirectory = directory.appendingPathComponent("messages")
    try FileManager.default.createDirectory(at: messagesDirectory, withIntermediateDirectories: true)
    let filename = Data(id.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_") + ".json"
    try JSONEncoder().encode([message]).write(to: messagesDirectory.appendingPathComponent(filename))
    try JSONEncoder().encode([id: Date(timeIntervalSince1970: 200)]).write(to: directory.appendingPathComponent("message-fetch-times.json"))

    let cache = FileChatCache(directory: directory)

    XCTAssertEqual(cache.messages(threadId: id), [message])
    XCTAssertNil(cache.messagesFetchedAt(threadId: id))
  }

  func testLocallyMergedCompletionPreservesLastHistoryFetchTime() async throws {
    let cache = FileChatCache(directory: directory)
    let id = watchFixtureId("s1")
    let oldTime = Date(timeIntervalSince1970: 100)
    let old = ChatMessage(id: "old", role: .assistant, content: "Saved reply", at: oldTime)
    cache.save(messages: [old], fetchedAt: oldTime, threadId: id)
    let inner = FakeClient()
    inner.sendResult = .success(SendResult(threadId: id, text: "Done", failed: false))
    let client = CachingClient(inner: inner, cache: cache, session: inner.sessionState)

    _ = try await client.send(threadId: id, text: "Continue", sendId: "local")

    XCTAssertEqual(cache.messages(threadId: id)?.map(\.content), ["Saved reply", "Continue", "Done"])
    XCTAssertEqual(cache.messagesFetchedAt(threadId: id), oldTime)
  }

  func testClearingCacheForgetsMetadataSeenTimesAndMessageFreshness() {
    let cache = FileChatCache(directory: directory)
    let thread = ThreadSummary(id: watchFixtureId("s1"), title: "Chat", updatedAt: Date(timeIntervalSince1970: 100), pinned: false)
    var seen = ThreadSeenMarkers()
    seen.observeFresh([thread])
    cache.save(listing: ThreadListing(threads: [thread], activeProfile: "work", fetchedAt: .distantPast))
    cache.save(seenMarkers: seen)
    cache.save(messages: [], fetchedAt: .distantPast, threadId: thread.id)
    XCTAssertEqual(cache.messagesFetchedAt(threadId: thread.id), .distantPast)
    cache.clear()
    XCTAssertNil(cache.listing())
    XCTAssertNil(cache.messagesFetchedAt(threadId: thread.id))
    let newer = ThreadSummary(id: thread.id, title: thread.title, updatedAt: Date(timeIntervalSince1970: 200), pinned: false)
    XCTAssertFalse(cache.seenMarkers().isUpdated(newer))
  }
}

@MainActor
final class ThreadGlanceReadTests: XCTestCase {
  func testSuccessfulFreshReadMarksOnlyTheCapturedListingUpdate() async {
    let client = FakeClient()
    let old = ThreadSummary(id: watchFixtureId("s1"), title: "Chat", updatedAt: Date(timeIntervalSince1970: 100), pinned: false)
    client.threadsResult = .success([old])
    let list = ThreadListModel(client: client)
    await list.load()
    let updated = ThreadSummary(id: old.id, title: old.title, updatedAt: Date(timeIntervalSince1970: 200), pinned: false)
    client.threadsResult = .success([updated])
    await list.load()
    let reading = ConversationModel(client: client, threadId: updated.id,
      onFreshMessagesLoaded: { list.markSeen(threadId: updated.id, updatedAt: updated.updatedAt) })
    await reading.load()
    XCTAssertFalse(list.isUpdated(updated))
  }

  func testFailedFreshReadDoesNotCallReadCallback() async {
    let client = FakeClient()
    client.messagesResult = .failure(HermesClientError.phoneUnreachable)
    var markedRead = false
    let reading = ConversationModel(client: client, threadId: watchFixtureId("s1"),
      onFreshMessagesLoaded: { markedRead = true })
    await reading.load()
    XCTAssertFalse(markedRead)
  }

  func testSavedMessagesKeepTheirFetchTimeWhenRefreshFails() async {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = FileChatCache(directory: directory)
    let client = FakeClient()
    let id = watchFixtureId("s1")
    let fetchedAt = Date(timeIntervalSince1970: 100)
    cache.save(messages: [ChatMessage(id: "m1", role: .assistant, content: "Saved reply", at: fetchedAt)], threadId: id)
    cache.saveMessagesFetchedAt(fetchedAt, threadId: id)
    client.messagesResult = .failure(HermesClientError.phoneUnreachable)
    let reading = ConversationModel(client: CachingClient(inner: client, cache: cache, session: client.sessionState), threadId: id)
    await reading.load()
    XCTAssertTrue(reading.showingSavedMessages)
    XCTAssertEqual(reading.messagesFetchedAt, fetchedAt)
    XCTAssertEqual(cache.messagesFetchedAt(threadId: id), fetchedAt)
  }
}
