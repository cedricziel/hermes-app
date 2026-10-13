import Foundation

enum WatchContextualAction: String, CaseIterable, Identifiable {
  case planDay, explain, continueReply, summarize

  var id: Self { self }

  var label: String {
    switch self {
    case .planDay: return "Plan my day"
    case .explain: return "Explain something"
    case .continueReply: return "Continue"
    case .summarize: return "Summarize"
    }
  }

  var draft: String? {
    switch self {
    case .planDay: return "Help me plan my day."
    case .explain: return "Help me understand this topic: "
    case .continueReply, .summarize: return nil
    }
  }

  var followUp: String? {
    switch self {
    case .continueReply, .summarize: return label
    case .planDay, .explain: return nil
    }
  }

  var accessibilityHint: String {
    draft == nil ? "Sends this follow-up to Hermes" : "Inserts an editable draft without sending"
  }
}

enum WatchContextualActions {
  @MainActor
  static func activate(_ action: WatchContextualAction,
    available: () -> [WatchContextualAction], fillDraft: (String) -> Void,
    send: (String) async -> Void) async {
    guard available().contains(action) else { return }
    if let text = action.draft { fillDraft(text) }
    else if let text = action.followUp { await send(text) }
  }

  static func select(newChat: Bool, empty: Bool, successfulReply: Bool, idle: Bool,
    draft: String, voiceIdle: Bool, recording: Bool, pendingRequest: Bool,
    unresolvedDelivery: Bool) -> [WatchContextualAction] {
    guard idle, draft.isEmpty, voiceIdle, !recording, !pendingRequest, !unresolvedDelivery else { return [] }
    if newChat, empty { return [.planDay, .explain] }
    return successfulReply ? [.continueReply, .summarize] : []
  }
}
