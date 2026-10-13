import XCTest
@testable import HermesWatchCore

private final class RecoveryTransport: RelayTransport {
  var handshake: [String: Any] = ["ok": true, "protocolVersion": 2, "contextId": "test-context", "revision": 1, "sendState": true]
  var response: [String: Any] = ["ok": true, "contextId": "test-context", "revision": 1, "recoveryState": "pending"]
  var requests: [[String: Any]] = []
  func request(_ message: [String: Any]) async throws -> [String: Any] {
    requests.append(message)
    return message["op"] as? String == "session" ? handshake : response
  }
}

@MainActor
final class RelayRecoveryTests: XCTestCase {
  func testMissingCapabilityRefusesEvenStatusContentRequest() async {
    let transport = RecoveryTransport()
    transport.handshake.removeValue(forKey: "sendState")
    do {
      _ = try await RelayClient(transport: transport).send(threadId: nil, text: "Private", sendId: "original", retry: true, createdAt: .distantPast)
      XCTFail("Expected update required")
    } catch { XCTAssertEqual(error as? HermesClientError, .updateRequired) }
    XCTAssertEqual(transport.requests.count, 1)
    XCTAssertNil(transport.requests.first?["text"])
  }

  func testModernPhoneWithUnavailableJournalShowsReadinessGuidance() async {
    let transport = RecoveryTransport()
    transport.handshake["sendState"] = false
    do {
      try await RelayClient(transport: transport).prepareRecovery()
      XCTFail("Expected journal readiness guidance")
    } catch { XCTAssertEqual(error as? HermesClientError, .unavailable) }
    XCTAssertEqual(transport.requests.count, 1)
  }

  func testUnsupportedProtocolRefusesRecovery() async {
    let transport = RecoveryTransport()
    transport.handshake["protocolVersion"] = 1
    do {
      try await RelayClient(transport: transport).prepareRecovery()
      XCTFail("Expected update required")
    } catch { XCTAssertEqual(error as? HermesClientError, .updateRequired) }
    XCTAssertEqual(transport.requests.count, 1)
  }

  func testPendingStatusHasNoCompletedAnswerAndPreservesCreatedAt() async throws {
    let transport = RecoveryTransport()
    let result = try await RelayClient(transport: transport).send(threadId: nil, text: "Original", sendId: "original", retry: true, createdAt: Date(timeIntervalSince1970: 100))
    XCTAssertEqual(result.recoveryState, .pending)
    XCTAssertEqual(result.text, "")
    XCTAssertEqual(transport.requests.last?["retry"] as? Bool, true)
    XCTAssertEqual(transport.requests.last?["createdAt"] as? Int64, 100000)
  }

  func testUncertainStatusWithoutThreadIsAccepted() async throws {
    let transport = RecoveryTransport()
    transport.response["recoveryState"] = "uncertain"
    let result = try await RelayClient(transport: transport).send(threadId: nil, text: "Original", sendId: "original", retry: true, createdAt: .distantPast)
    XCTAssertEqual(result.recoveryState, .uncertain)
    XCTAssertNil(result.threadId)
  }

  func testUnknownStateCannotBecomeAssistantAnswer() async {
    let transport = RecoveryTransport()
    transport.response["recoveryState"] = "unknown"
    transport.response["text"] = "Hermes is still replying."
    do {
      _ = try await RelayClient(transport: transport).send(threadId: nil, text: "Original", sendId: "original", retry: true, createdAt: .distantPast)
      XCTFail("Expected unknown status rejection")
    } catch { XCTAssertEqual(error as? HermesClientError, .failed) }
  }

  func testMismatchedIdentityCannotCompleteSend() async {
    let transport = RecoveryTransport()
    transport.response = ["ok": true, "contextId": "test-context", "revision": 1, "sendId": "other", "threadId": watchFixtureId("chat"), "text": "Other answer"]
    do {
      _ = try await RelayClient(transport: transport).send(threadId: nil, text: "Original", sendId: "original", retry: true, createdAt: .distantPast)
      XCTFail("Expected mismatched identity rejection")
    } catch { XCTAssertEqual(error as? HermesClientError, .failed) }
  }

  func testSavedCompletionReturnedTwiceIsCachedOnce() async throws {
    let transport = RecoveryTransport()
    transport.response = ["ok": true, "contextId": "test-context", "revision": 1, "threadId": watchFixtureId("chat"), "text": "Saved answer"]
    let cache = MemoryChatCache()
    let session = WatchSessionState()
    let client = CachingClient(inner: RelayClient(transport: transport, session: session), cache: cache, session: session)
    _ = try await client.send(threadId: nil, text: "Original", sendId: "original", retry: true, createdAt: .distantPast)
    _ = try await client.send(threadId: nil, text: "Original", sendId: "original", retry: true, createdAt: .distantPast)
    XCTAssertEqual(cache.savedMessages[watchFixtureId("chat")]?.map(\.content), ["Original", "Saved answer"])
  }
}
