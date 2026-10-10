import Foundation

struct ThreadSummary: Identifiable, Equatable, Codable {
  let id: String
  let title: String
  /// Nil when the phone knows no time for the chat.
  let updatedAt: Date?
  let pinned: Bool
  /// Nil when the phone could not name the server or the profile.
  var handoff: HandoffTarget?
}

/// Where a chat lives, so the iPhone or Mac can continue it through Handoff.
/// The watch never uses the address: it only passes it on.
struct HandoffTarget: Hashable, Codable {
  let serverUrl: String
  let profile: String
  /// The raw session id, not the id the watch uses for the chat.
  let sessionId: String

  /// The payload the apps' `HandoffActivity.parse` accepts.
  static let requiredKeys: Set<String> = ["version", "serverUrl", "profile", "threadId"]

  var userInfo: [String: Any] {
    ["version": 1, "serverUrl": serverUrl, "profile": profile, "threadId": sessionId]
  }

  init(serverUrl: String, profile: String, sessionId: String) {
    self.serverUrl = serverUrl
    self.profile = profile
    self.sessionId = sessionId
  }

  /// Nil unless the row has all three fields, non-blank.
  init?(row: [String: Any]) {
    guard let serverUrl = row["serverUrl"] as? String, let profile = row["profile"] as? String,
      let sessionId = row["sessionId"] as? String,
      ![serverUrl, profile, sessionId].contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
    else { return nil }
    self.init(serverUrl: serverUrl, profile: profile, sessionId: sessionId)
  }
}

struct ChatMessage: Identifiable, Equatable, Codable {
  enum Role: String, Equatable, Codable {
    case user
    case assistant
  }

  let id: String
  let role: Role
  let content: String
  let at: Date
  /// The tools Hermes called since the text before this one.
  var tools: [String] = []
}

struct SendResult: Equatable {
  /// The thread the message went to; set when a new thread was started.
  let threadId: String?
  let text: String
  /// The turn ended in an error and [text] is the message.
  let failed: Bool
  var tools: [String] = []
  /// Set while the turn is not over yet and the send must be asked again.
  var waiting: Waiting?
  /// Where the chat lives, so a chat started here can be handed off at once.
  var handoff: HandoffTarget?

  enum Waiting: String, Equatable {
    /// Hermes waits on the user's approval, which the notification asks for.
    case approval
    /// Hermes asked a question, answered from the notification.
    case question
    /// The turn went on and Hermes is replying.
    case working
  }
}
