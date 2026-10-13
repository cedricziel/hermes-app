import Foundation

struct ThreadListing: Equatable, Codable {
  let threads: [ThreadSummary]
  var activeProfile: String?
  var fetchedAt: Date?
}

enum ThreadStatus: String, Equatable, Codable {
  case running, approval, question

  var label: String {
    switch self {
    case .running: return "Running"
    case .approval: return "Approval"
    case .question: return "Question"
    }
  }
}

struct ThreadSeenMarkers: Codable {
  private var readTimes: [String: Date] = [:]

  mutating func observeFresh(_ threads: [ThreadSummary]) {
    for thread in threads where readTimes[thread.id] == nil {
      if let updatedAt = thread.updatedAt { readTimes[thread.id] = updatedAt }
    }
  }

  mutating func markRead(threadId: String, updatedAt: Date?) {
    guard let updatedAt else { return }
    readTimes[threadId] = max(readTimes[threadId] ?? updatedAt, updatedAt)
  }

  func isUpdated(_ thread: ThreadSummary) -> Bool {
    guard let updatedAt = thread.updatedAt, let readAt = readTimes[thread.id] else { return false }
    return updatedAt > readAt
  }
}

enum ThreadGlancePresentation {
  static func status(_ thread: ThreadSummary, saved: Bool) -> String {
    guard let status = thread.status else { return "Status unknown" }
    return saved ? "Saved status: \(status.label)" : status.label
  }

  static func accessibilityLabel(_ thread: ThreadSummary, saved: Bool, updated: Bool) -> String {
    var parts = [thread.title]
    if thread.pinned { parts.append("Pinned") }
    parts.append(status(thread, saved: saved))
    if updated { parts.append("Updated on this watch") }
    return parts.joined(separator: ". ")
  }

  static func savedFreshness(_ fetchedAt: Date?) -> String {
    guard let fetchedAt else { return "Saved data. Fetch time unknown." }
    return "Saved data. Fetched \(fetchedAt.formatted(date: .abbreviated, time: .shortened))."
  }
}
