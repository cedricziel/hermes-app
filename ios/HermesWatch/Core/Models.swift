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
}
