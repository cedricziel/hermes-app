import XCTest
@testable import HermesWatchCore

@MainActor
final class WatchSessionContextTests: XCTestCase {
  func testChangingContextClearsPrivateStateAndRejectsDelayedRevision() {
    let session = WatchSessionState()
    session.acceptContext("owner-a", revision: 7)
    var cleared = 0
    _ = session.register { cleared += 1 }
    XCTAssertTrue(session.acceptContext("owner-b", revision: 8))
    XCTAssertEqual(cleared, 1)
    XCTAssertFalse(session.acceptContext("owner-a", revision: 7))
    XCTAssertEqual(session.contextId, "owner-b")
    XCTAssertFalse(session.owns(WatchThreadId(contextId: "owner-a", profile: "p", sessionId: "s1").encode()))
  }
  func testNativeOwnerChangeRequiresFreshHandshake() {
    let session = WatchSessionState()
    session.acceptContext("owner-a", revision: 7)
    session.receive(["watchSession": ["usable": true, "revision": 8, "protocolVersion": 2, "contextId": "owner-b"]])
    XCTAssertFalse(session.handshaken)
  }
  func testSignedOutRevisionCannotBeRestoredByEqualRevisionReadyPublication() {
    let session = WatchSessionState()
    session.acceptContext("owner-a", revision: 7)
    session.receive(["watchSession": ["usable": false, "revision": 8]])
    session.receive(["watchSession": ["usable": true, "revision": 8, "protocolVersion": 2, "contextId": "owner-a"]])
    XCTAssertNil(session.contextId)
    XCTAssertFalse(session.usable)
  }
  func testOfflineRestartRetainsContextButRequiresHandshake() {
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    WatchSessionState(defaults: defaults).acceptContext("owner-a", revision: 7)
    let restored = WatchSessionState(defaults: defaults)
    XCTAssertEqual(restored.contextId, "owner-a")
    XCTAssertFalse(restored.handshaken)
  }
}

private final class ContextTransport: RelayTransport {
  var replies: [[String: Any]]
  var requests: [[String: Any]] = []
  init(_ replies: [[String: Any]]) { self.replies = replies }
  func request(_ message: [String: Any]) async throws -> [String: Any] {
    requests.append(message)
    return replies.removeFirst()
  }
}

@MainActor
final class ContextRelayTests: XCTestCase {
  func testHandshakeScopesNewChatBeforeSubmission() async throws {
    let id = WatchThreadId(contextId: "owner-a", profile: nil, sessionId: "new").encode()
    let transport = ContextTransport([
      ["ok": true, "protocolVersion": 2, "contextId": "owner-a", "revision": 7, "sendState": true],
      ["ok": true, "contextId": "owner-a", "revision": 7, "threadId": id, "text": "Done"],
    ])
    _ = try await RelayClient(transport: transport).send(threadId: nil, text: "Hi", sendId: "x", retry: false)
    XCTAssertEqual(transport.requests.first?["op"] as? String, "session")
    XCTAssertEqual(transport.requests.last?["contextId"] as? String, "owner-a")
    XCTAssertEqual(transport.requests.last?["revision"] as? Int, 7)
  }

  func testOfflineDraftCannotSubmitAfterHandshakeChangesOwner() async {
    let session = WatchSessionState()
    session.acceptContext("owner-a", revision: 7, confirmed: false)
    let transport = ContextTransport([["ok": true, "protocolVersion": 2, "contextId": "owner-b", "revision": 8]])
    do {
      _ = try await RelayClient(transport: transport, session: session).send(threadId: nil, text: "Private old draft", sendId: "x", retry: false)
      XCTFail("Expected draft owner rejection")
    } catch { XCTAssertEqual(error as? HermesClientError, .contextChanged) }
    XCTAssertEqual(transport.requests.count, 1)
  }

  func testOldPhoneRequiresUpdateWithoutSendingContent() async {
    let transport = ContextTransport([["ok": false, "error": "bad_request"]])
    do {
      _ = try await RelayClient(transport: transport).threads()
      XCTFail("Expected update guidance")
    } catch {
      XCTAssertEqual(error as? HermesClientError, .updateRequired)
    }
    XCTAssertEqual(transport.requests.count, 1)
  }

  func testSuccessFromDifferentContextCannotReplaceCurrentData() async {
    let transport = ContextTransport([
      ["ok": true, "protocolVersion": 2, "contextId": "owner-a", "revision": 7, "sendState": true],
      ["ok": true, "contextId": "owner-b", "revision": 8, "threads": []],
    ])
    do {
      _ = try await RelayClient(transport: transport).threads()
      XCTFail("Expected stale context rejection")
    } catch {
      XCTAssertEqual(error as? HermesClientError, .contextChanged)
    }
  }
}

@MainActor
final class ContextRevisionPrivacyTests: XCTestCase {
  func testSameContextAdvancedRevisionClearsOldGeneration() {
    let session = WatchSessionState()
    session.acceptContext("owner-a", revision: 7)
    var cleaned = 0
    _ = session.register { cleaned += 1 }
    let generation = session.generation
    session.receive(["watchSession": ["usable": true, "protocolVersion": 2, "contextId": "owner-a", "revision": 8]])
    XCTAssertEqual(cleaned, 1)
    XCTAssertEqual(session.generation, generation + 1)
    XCTAssertFalse(session.handshaken)
  }
}
