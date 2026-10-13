import Foundation

func relayOperation(_ raw: String?) -> String {
  guard let operation = raw,
    ["session", "threads", "messages", "send", "forgetSend", "request_details", "request_answer", "transcribe"].contains(operation)
  else { return "unknown" }
  return operation
}

func waitForRelayActivation(
  activated: () -> Bool,
  sleep: () async throws -> Void
) async throws {
  for _ in 0..<15 {
    if activated() { return }
    try await sleep()
  }
  throw RelayFailure.notActivated
}

/// Failures before dispatch or while delivery was in progress.
enum RelayFailure: Error, Equatable {
  /// The watch's WatchConnectivity session never activated.
  case notActivated
  /// The phone was out of reach.
  case notReachable
  /// WatchConnectivity gave up on the message with this error code.
  case delivery(code: Int)

  var reason: String {
    switch self {
    case .notActivated: "not_activated"
    case .notReachable: "not_reachable"
    case .delivery(let code): "delivery:\(code)"
    }
  }
}

/// One request that never reached the phone: what it asked for, why and
/// when. Never what the user wrote.
struct DeliveryReport: Codable, Equatable {
  let op: String
  let reason: String
  /// Seconds since 1970.
  let at: Int
}

/// The failures not yet handed to the phone, kept across launches and capped
/// at [limit], dropping the oldest.
struct DeliveryReports {
  static let limit = 20
  private static let key = "watch.deliveryReports"

  let defaults: UserDefaults

  var pending: [DeliveryReport] {
    guard let data = defaults.data(forKey: Self.key) else { return [] }
    let decoded = (try? JSONDecoder().decode([DeliveryReport].self, from: data)) ?? []
    return decoded.map { DeliveryReport(op: relayOperation($0.op), reason: $0.reason, at: $0.at) }
  }

  func add(_ report: DeliveryReport) {
    let sanitized = DeliveryReport(op: relayOperation(report.op), reason: report.reason, at: report.at)
    store(Array((pending + [sanitized]).suffix(Self.limit)))
  }

  /// Drops the [count] oldest, which reached the phone.
  func removeFirst(_ count: Int) {
    store(Array(pending.dropFirst(count)))
  }

  private func store(_ reports: [DeliveryReport]) {
    defaults.set(try? JSONEncoder().encode(reports), forKey: Self.key)
  }
}

/// Delivery errors cannot prove that a dispatched request was never accepted.
struct ReportingTransport: RelayTransport {
  let inner: RelayTransport
  let reports: DeliveryReports
  var now: () -> Date = Date.init

  func request(_ message: [String: Any]) async throws -> [String: Any] {
    let pending = reports.pending
    var message = message
    if !pending.isEmpty {
      message["diagnostics"] = pending.map { ["op": $0.op, "reason": $0.reason, "at": $0.at] }
    }
    do {
      let reply = try await inner.request(message)
      if !pending.isEmpty { reports.removeFirst(pending.count) }
      return reply
    } catch let failure as RelayFailure {
      reports.add(
        DeliveryReport(
          op: relayOperation(message["op"] as? String),
          reason: failure.reason,
          at: Int(now().timeIntervalSince1970)
        )
      )
      switch failure {
      case .notActivated, .notReachable: throw HermesClientError.notDelivered
      case .delivery: throw HermesClientError.phoneUnreachable
      }
    }
  }
}
