import Foundation

enum HermesClientError: Error, Equatable {
  /// The phone is not signed in to a Hermes dashboard.
  case signedOut
  /// The phone app cannot answer right now.
  case unavailable
  /// The phone cannot be reached from the watch.
  case phoneUnreachable
  case failed
}

/// What the watch UI needs from Hermes. It has one implementation that relays
/// through the phone; a later one can talk to the dashboard directly without
/// the UI changing.
protocol HermesClient {
  func threads() async throws -> [ThreadSummary]
  func messages(threadId: String) async throws -> [ChatMessage]
  func send(threadId: String?, text: String) async throws -> SendResult
}
