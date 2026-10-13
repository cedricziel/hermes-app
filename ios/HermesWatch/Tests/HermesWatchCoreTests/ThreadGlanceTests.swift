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
