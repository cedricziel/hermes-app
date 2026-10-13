import Foundation

enum HermesClientError: Error, Equatable {
  /// The phone is not signed in to a Hermes dashboard.
  case signedOut
  /// The phone app cannot answer right now.
  case unavailable
  /// The phone cannot be reached from the watch.
  case phoneUnreachable
  case notDelivered
  case contextChanged
  case updateRequired
  case failed
  case recoveryCapacity
  case recoveryStorage
  case sendExpired
  case clockSkew
  /// The dashboard ended the turn in failure and said why.
  case replyFailed(String)
  /// A voice message had no speech the dashboard could make out.
  case noSpeech
}

/// What the watch UI needs from Hermes. It has one implementation that relays
/// through the phone; a later one can talk to the dashboard directly without
/// the UI changing.
@MainActor
protocol HermesClient: WatchRequestServing {
  var sessionState: WatchSessionState? { get }
  var recoveryStore: PendingSendStore { get }
  func prepareRecovery() async throws
  func forgetSend(sendId: String) async throws
  func send(threadId: String?, text: String, sendId: String, retry: Bool, createdAt: Date) async throws -> SendResult
  func threads() async throws -> [ThreadSummary]
  func messages(threadId: String) async throws -> [ChatMessage]
  /// Recovery requests use the original identity and timestamp with retry true.
  /// A status request never authorizes a new submission.
  func send(threadId: String?, text: String, sendId: String, retry: Bool) async throws -> SendResult
  /// What the dashboard heard in a recording, empty when it heard no speech.
  func transcribe(audio: Data, mimeType: String) async throws -> String
  /// The chat list saved last time, shown until [threads] answers.
  func savedThreads() -> [ThreadSummary]?
  /// A chat's messages saved last time, shown until [messages] answers.
  func savedMessages(threadId: String) -> [ChatMessage]?
}

extension HermesClient {
  var sessionState: WatchSessionState? { nil }
  var recoveryStore: PendingSendStore { FilePendingSendStore.standard }
  func prepareRecovery() async throws { throw HermesClientError.updateRequired }
  func forgetSend(sendId: String) async throws { throw HermesClientError.updateRequired }
  func send(threadId: String?, text: String, sendId: String, retry: Bool, createdAt: Date) async throws -> SendResult {
    try await send(threadId: threadId, text: text, sendId: sendId, retry: retry)
  }
  func send(threadId: String?, text: String, sendId: String) async throws -> SendResult {
    try await send(threadId: threadId, text: text, sendId: sendId, retry: false)
  }

  func savedThreads() -> [ThreadSummary]? { nil }
  func savedMessages(threadId: String) -> [ChatMessage]? { nil }
}
