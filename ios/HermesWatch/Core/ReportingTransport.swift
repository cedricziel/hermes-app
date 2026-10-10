import Foundation

/// Why a request never reached the phone.
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
    return (try? JSONDecoder().decode([DeliveryReport].self, from: data)) ?? []
  }

  func add(_ report: DeliveryReport) {
    store(Array((pending + [report]).suffix(Self.limit)))
  }

  func remove(_ handedOver: [DeliveryReport]) {
    store(Array(pending.dropFirst(handedOver.count)))
  }

  private func store(_ reports: [DeliveryReport]) {
    defaults.set(try? JSONEncoder().encode(reports), forKey: Self.key)
  }
}

/// Reports to the phone, which logs them, the requests that never got there:
/// it notes each [RelayFailure] and sends the notes along with the next
/// request that arrives. The UI sees any such failure as
/// [HermesClientError.phoneUnreachable].
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
      if !pending.isEmpty { reports.remove(pending) }
      return reply
    } catch let failure as RelayFailure {
      reports.add(
        DeliveryReport(
          op: message["op"] as? String ?? "unknown",
          reason: failure.reason,
          at: Int(now().timeIntervalSince1970)
        )
      )
      throw HermesClientError.phoneUnreachable
    }
  }
}
