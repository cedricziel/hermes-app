import Foundation

struct ThreadSummary: Identifiable, Equatable, Codable {
  let id: String
  let title: String
  /// Nil when the phone knows no time for the chat.
  let updatedAt: Date?
  let pinned: Bool
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

  enum Waiting: String, Equatable {
    /// Hermes waits on the user's approval, which the notification asks for.
    case approval
    /// Hermes asked a question, answered from the notification.
    case question
    /// The turn went on and Hermes is replying.
    case working
  }
}
