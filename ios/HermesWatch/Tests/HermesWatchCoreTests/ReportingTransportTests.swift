import XCTest

@testable import HermesWatchCore

final class ScriptedTransport: RelayTransport {
  var requests: [[String: Any]] = []
  var replies: [Result<[String: Any], Error>] = []

  func request(_ message: [String: Any]) async throws -> [String: Any] {
    requests.append(message)
    return try replies.removeFirst().get()
  }
}

final class ReportingTransportTests: XCTestCase {
  private var inner: ScriptedTransport!
  private var defaults: UserDefaults!
  private var transport: ReportingTransport!

  override func setUp() {
    inner = ScriptedTransport()
    defaults = UserDefaults(suiteName: UUID().uuidString)
    transport = ReportingTransport(
      inner: inner,
      reports: DeliveryReports(defaults: defaults),
      now: { Date(timeIntervalSince1970: 1_000) }
    )
  }

  func testAFailureIsHandedOverWithTheNextRequestThatArrives() async throws {
    inner.replies = [.failure(RelayFailure.notReachable), .success(["ok": true]), .success(["ok": true])]

    do {
      _ = try await transport.request(["op": "send", "text": "private"])
      XCTFail("expected a throw")
    } catch {
      XCTAssertEqual(error as? HermesClientError, .phoneUnreachable)
    }
    _ = try await transport.request(["op": "threads"])
    _ = try await transport.request(["op": "threads"])

    let handedOver = inner.requests[1]["diagnostics"] as? [[String: Any]]
    XCTAssertEqual(handedOver?.count, 1)
    XCTAssertEqual(handedOver?.first?["op"] as? String, "send")
    XCTAssertEqual(handedOver?.first?["reason"] as? String, "not_reachable")
    XCTAssertEqual(handedOver?.first?["at"] as? Int, 1_000)
    XCTAssertNil(handedOver?.first?["text"])
    XCTAssertNil(inner.requests[2]["diagnostics"])
  }

  func testFailuresAreKeptUntilOneRequestArrives() async {
    inner.replies = [.failure(RelayFailure.notActivated), .failure(RelayFailure.delivery(code: 7012))]

    _ = try? await transport.request(["op": "threads"])
    _ = try? await transport.request(["op": "messages"])

    let reasons = DeliveryReports(defaults: defaults).pending.map(\.reason)
    XCTAssertEqual(reasons, ["not_activated", "delivery:7012"])
  }

  func testOnlyTheLatestFailuresAreKept() {
    let reports = DeliveryReports(defaults: defaults)
    for i in 0..<30 {
      reports.add(DeliveryReport(op: "threads", reason: "not_reachable", at: i))
    }

    XCTAssertEqual(reports.pending.count, DeliveryReports.limit)
    XCTAssertEqual(reports.pending.last?.at, 29)
  }
}
