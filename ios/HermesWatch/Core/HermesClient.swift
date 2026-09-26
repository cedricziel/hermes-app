import Foundation

enum HermesClientError: Error, Equatable {
  /// The phone is not signed in to a Hermes dashboard.
  case signedOut
  /// The phone app cannot answer right now.
  case unavailable
  /// The phone cannot be reached from the watch.
  case phoneUnreachable
  case failed
  /// The dashboard ended the turn in failure and said why.
  case replyFailed(String)
  /// A voice message had no speech the dashboard could make out.
  case noSpeech
}

/// What the watch UI needs from Hermes. It has one implementation that relays
/// through the phone; a later one can talk to the dashboard directly without
/// the UI changing.
protocol HermesClient {
  func threads() async throws -> [ThreadSummary]
  func messages(threadId: String) async throws -> [ChatMessage]
  func send(threadId: String?, text: String) async throws -> SendResult
  /// What the dashboard heard in a recording, empty when it heard no speech.
  func transcribe(audio: Data, mimeType: String) async throws -> String
}
