import XCTest
@testable import HermesWatchCore

@MainActor
final class StartupMigrationTests: XCTestCase {
  func testLegacyStartupPurgesEveryPrivateSurfaceBeforeFirstContextAcceptance() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let session = WatchSessionState(defaults: defaults)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = FileChatCache(directory: directory)
    cache.save(threads: [ThreadSummary(id: "legacy/s", title: "Private A", updatedAt: nil, pinned: false)])
    let store = ComplicationStore(defaults: defaults)
    store.apply(.show(ComplicationStatus(state: .ready, updatedAt: .distantPast, title: "Private A", threadId: "legacy/s")))
    var pending: String? = "legacy/s"
    var cleaned = false
    var ownerDuringCleanup: String?
    let generation = session.generation

    session.start(receivedSession: ["watchSession": ["usable": true, "protocolVersion": 2, "contextId": "owner-b", "revision": 8]]) {
      cleaned = true
      ownerDuringCleanup = session.contextId
      cache.clear()
      store.apply(.clear)
      pending = nil
    }

    XCTAssertTrue(cleaned)
    XCTAssertNil(ownerDuringCleanup)
    XCTAssertNil(cache.threads())
    XCTAssertNil(store.status())
    XCTAssertNil(pending)
    XCTAssertEqual(session.contextId, "owner-b")
    XCTAssertEqual(session.generation, generation)
  }

  func testKnownOwnerStartupRegistersCleanupBeforeChangedPublication() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    defaults.set("owner-a", forKey: "watch.session.context")
    defaults.set(7, forKey: "watch.session.revision")
    let session = WatchSessionState(defaults: defaults)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let cache = FileChatCache(directory: directory)
    cache.save(threads: [ThreadSummary(id: "old/s", title: "Private A", updatedAt: nil, pinned: false)])
    let store = ComplicationStore(defaults: defaults)
    store.apply(.show(ComplicationStatus(state: .ready, updatedAt: .distantPast, title: "Private A", threadId: "old/s")))
    var pending: String? = "old/s"
    var ownerDuringCleanup: String?
    let generation = session.generation

    session.start(receivedSession: ["watchSession": ["usable": true, "protocolVersion": 2, "contextId": "owner-b", "revision": 8]]) {
      ownerDuringCleanup = session.contextId
      cache.clear()
      store.apply(.clear)
      pending = nil
    }

    XCTAssertEqual(ownerDuringCleanup, "owner-a")
    XCTAssertNil(cache.threads())
    XCTAssertNil(store.status())
    XCTAssertNil(pending)
    XCTAssertEqual(session.contextId, "owner-b")
    XCTAssertEqual(session.generation, generation + 1)
  }

  func testUnchangedKnownOwnerStartupPreservesScopedSavedData() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    defaults.set("owner-a", forKey: "watch.session.context")
    defaults.set(7, forKey: "watch.session.revision")
    let session = WatchSessionState(defaults: defaults)
    var cleaned = false

    session.start(receivedSession: ["watchSession": ["usable": true, "protocolVersion": 2, "contextId": "owner-a", "revision": 7]]) {
      cleaned = true
    }

    XCTAssertFalse(cleaned)
    XCTAssertEqual(session.contextId, "owner-a")
    XCTAssertEqual(session.generation, 0)
    XCTAssertFalse(session.handshaken)
  }
}
