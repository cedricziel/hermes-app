import Foundation

struct ThreadSummary: Identifiable, Equatable {
  let id: String
  let title: String
  let updatedAt: Date
  let pinned: Bool
}

struct ChatMessage: Identifiable, Equatable {
  enum Role: Equatable {
    case user
    case assistant
  }

  let id: String
  let role: Role
  let content: String
  let at: Date
}

struct SendResult: Equatable {
  /// The thread the message went to; set when a new thread was started.
  let threadId: String?
  let text: String
  /// The turn ended in an error and [text] is the message.
  let failed: Bool
}
