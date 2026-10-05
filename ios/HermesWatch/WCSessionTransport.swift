import WatchConnectivity
import OSLog

/// Sends requests to the paired phone over WatchConnectivity.
final class WCSessionTransport: NSObject, RelayTransport, WCSessionDelegate {
  private let session = WCSession.default
  private let logger = Logger(subsystem: "app.hermes.watch", category: "connectivity")

  override init() {
    super.init()
    session.delegate = self
    session.activate()
  }

  func request(_ message: [String: Any]) async throws -> [String: Any] {
    let requestedOperation = message["op"] as? String ?? ""
    let operation = ["threads", "messages", "send", "transcribe"].contains(requestedOperation)
      ? requestedOperation : "unknown"
    logger.notice("Request started operation=\(operation, privacy: .public)")
    do {
      try await waitUntilActivated()
      try await waitUntilReachable()
    } catch {
      logger.error("Request unavailable activation=\(self.session.activationState.rawValue) reachable=\(self.session.isReachable)")
      throw error
    }
    return try await withCheckedThrowingContinuation { continuation in
      session.sendMessage(
        message,
        replyHandler: { reply in
          let error = reply["error"] as? String ?? ""
          let result = reply["ok"] as? Bool == true ? "ok"
            : (["signed_out", "unavailable", "bad_request", "failed"].contains(error) ? error : "failed")
          self.logger.notice("Request completed operation=\(operation, privacy: .public) result=\(result, privacy: .public)")
          continuation.resume(returning: reply)
        },
        errorHandler: { error in
          self.logger.error("Delivery failed operation=\(operation, privacy: .public) code=\((error as NSError).code)")
          continuation.resume(throwing: HermesClientError.phoneUnreachable)
        }
      )
    }
  }

  /// Activation finishes shortly after launch, and a request made straight
  /// away would otherwise be refused.
  private func waitUntilActivated() async throws {
    for _ in 0..<15 {
      if session.activationState == .activated { return }
      try await Task.sleep(nanoseconds: 200_000_000)
    }
    throw HermesClientError.phoneUnreachable
  }

  /// The session reports the phone unreachable for a moment after it
  /// activates, even when the phone is right there.
  private func waitUntilReachable() async throws {
    for _ in 0..<25 {
      if session.isReachable { return }
      try await Task.sleep(nanoseconds: 200_000_000)
    }
    throw HermesClientError.phoneUnreachable
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    logger.notice("Activation completed state=\(activationState.rawValue) errorCode=\((error as NSError?)?.code ?? 0)")
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    logger.notice("Reachability changed reachable=\(session.isReachable)")
  }
}
