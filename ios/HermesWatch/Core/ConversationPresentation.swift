import Foundation

enum ConversationPresentation {
  static let requestGuidance = "Answer in the Hermes notification, or open Hermes on your iPhone."
  static let leaveWaitingLabel = "Leave waiting view"
  static let leaveWaitingHint = "Hermes will keep waiting for your answer."
  enum DeliveryEvidence: Equatable { case unknown, submitting, accepted }
  static func canRestoreUnsentDraft(composer: String, handoffInProgress: Bool) -> Bool {
    composer.isEmpty && !handoffInProgress
  }
  static func messageLabel(role: ChatMessage.Role, content: String) -> String {
    "\(role == .user ? "You" : "Hermes"): \(content)"
  }

  static func deliveryLabel(_ state: SendRecoveryState, evidence: DeliveryEvidence = .unknown) -> String {
    switch state {
    case .notSent: return "Not sent"
    case .uncertain: return "Delivery unconfirmed"
    case .pending:
      switch evidence {
      case .unknown: return "Delivery unconfirmed"
      case .submitting: return "Sending, awaiting confirmation"
      case .accepted: return "Accepted, awaiting reply"
      }
    case .completed: return "Completed"
    case .discarded: return "Discarded locally"
    }
  }
}

struct ConversationReadingPosition {
  private(set) var following = true
  private(set) var newReplyId: String?
  private var lastCompletionId: String?

  mutating func completedReply(id: String?, preservingFocus: Bool) -> String? {
    guard let id, id != lastCompletionId else { return nil }
    lastCompletionId = id
    return replyArrived(id: id, preservingFocus: preservingFocus)
  }

  mutating func setFollowing(_ value: Bool) { following = value }

  mutating func replyArrived(id: String, preservingFocus: Bool) -> String? {
    guard following, !preservingFocus else {
      newReplyId = id
      return nil
    }
    newReplyId = nil
    return id
  }

  mutating func revealReply() -> String? {
    let id = newReplyId
    newReplyId = nil
    following = true
    return id
  }
}
