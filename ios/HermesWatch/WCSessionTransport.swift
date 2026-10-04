import WatchConnectivity

/// Sends requests to the paired phone over WatchConnectivity.
final class WCSessionTransport: NSObject, RelayTransport, WCSessionDelegate {
  private let session = WCSession.default

  override init() {
    super.init()
    session.delegate = self
    session.activate()
  }

  func request(_ message: [String: Any]) async throws -> [String: Any] {
    try await waitUntilActivated()
    try await waitUntilReachable()
    return try await withCheckedThrowingContinuation { continuation in
      session.sendMessage(
        message,
        replyHandler: { continuation.resume(returning: $0) },
        errorHandler: { _ in continuation.resume(throwing: HermesClientError.phoneUnreachable) }
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
  ) {}
}
