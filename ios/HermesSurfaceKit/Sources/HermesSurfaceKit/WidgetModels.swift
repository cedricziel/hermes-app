import Foundation

// What each Home Screen widget shows, worked out from a snapshot and a date
// without any UI. The views only draw these models.
//
// A row or part whose title is `nil` is redacted: the snapshot holds no
// title (App Lock is on), and the view draws a placeholder rather than an
// invented title. Ages, kind labels, counts and links stay.

/// The size a widget is drawn in.
public enum SurfaceFamily: Equatable, Sendable {
  case small
  case medium
  case large
}

/// The `hermes://` links a widget falls back to when the snapshot holds no
/// link of its own. Every other link comes from the snapshot verbatim.
public enum SurfaceFallbackURL {
  public static let newChat = URL(string: "hermes://new")!
  public static let requests = URL(string: "hermes://requests")!
  public static let kanban = URL(string: "hermes://kanban")!
  public static let schedules = URL(string: "hermes://schedules")!
}

/// How long a snapshot may go unwritten before the widgets say it may be behind.
public let surfaceStaleAfter: TimeInterval = 6 * 3600

/// What every widget needs to know before it draws content.
public struct WidgetStatus: Equatable, Sendable {
  /// There is no snapshot, it is unreadable, or it says the user signed out.
  public let isSignedOut: Bool

  /// The snapshot is older than `surfaceStaleAfter`.
  public let isStale: Bool

  public init(snapshot: SurfaceSnapshot?, now: Date) {
    guard let snapshot, snapshot.signedIn else {
      isSignedOut = true
      isStale = false
      return
    }
    isSignedOut = false
    isStale = now.timeIntervalSince(snapshot.updatedAt) > surfaceStaleAfter
  }
}

private func shownTitle(_ title: String) -> String? { title.isEmpty ? nil : title }

/// The Recent chats widget.
public struct RecentChatsModel: Equatable, Sendable {
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: String

    /// `nil` when redacted.
    public let title: String?

    /// Set only when the snapshot holds chats of more than one profile.
    public let profile: String?

    /// Medium and large only; `nil` when redacted or the chat has none.
    public let snippet: String?
    public let updatedAt: Date
    public let url: URL

    public var isRedacted: Bool { title == nil }
  }

  public let status: WidgetStatus
  public let rows: [Row]

  /// A large widget with fewer chats than it has room for ends in a row
  /// that opens the app.
  public let showsOpenRow: Bool

  /// What a tap on the widget opens (small widgets have only this); `nil`
  /// when signed out, which opens the app as it is.
  public let url: URL?

  public var isEmpty: Bool { rows.isEmpty }

  public init(snapshot: SurfaceSnapshot?, family: SurfaceFamily, now: Date) {
    status = WidgetStatus(snapshot: snapshot, now: now)
    guard let snapshot, !status.isSignedOut else {
      rows = []
      showsOpenRow = false
      url = nil
      return
    }
    let capacity =
      switch family {
      case .small: 1
      case .medium: 3
      case .large: 6
      }
    let severalProfiles = Set(snapshot.recentChats.map(\.profile)).count > 1
    rows = snapshot.recentChats.prefix(capacity).map { chat in
      let title = shownTitle(chat.title)
      return Row(
        id: "\(chat.profile)/\(chat.id)", title: title,
        profile: severalProfiles ? chat.profile : nil,
        snippet: family == .small || title == nil ? nil : chat.snippet,
        updatedAt: chat.updatedAt, url: chat.url)
    }
    showsOpenRow = family == .large && !rows.isEmpty && rows.count < capacity
    url = rows.first?.url ?? SurfaceFallbackURL.newChat
  }
}

/// The Needs you widget.
public struct NeedsYouModel: Equatable, Sendable {
  public struct Row: Equatable, Identifiable, Sendable {
    public let id: String

    /// `nil` when redacted.
    public let title: String?
    public let kind: PendingKind
    public let createdAt: Date
    public let url: URL

    public var isRedacted: Bool { title == nil }
  }

  public let status: WidgetStatus

  /// Every open request, also those in chats the rows leave out.
  public let count: Int

  /// Medium only: up to three chats with open requests, the oldest first.
  public let rows: [Row]

  /// The chat of the oldest open request; the chat list when nothing waits;
  /// `nil` when signed out.
  public let url: URL?

  public var isEmpty: Bool { count == 0 }

  /// The fixed word for a kind of request. Never the request's own text.
  public static func label(for kind: PendingKind) -> String {
    switch kind {
    case .approval: "Approval"
    case .question: "Question"
    case .input: "Waiting for you"
    }
  }

  public init(snapshot: SurfaceSnapshot?, family: SurfaceFamily, now: Date) {
    status = WidgetStatus(snapshot: snapshot, now: now)
    guard let snapshot, !status.isSignedOut else {
      count = 0
      rows = []
      url = nil
      return
    }
    let oldestFirst = snapshot.pending.sorted { $0.createdAt < $1.createdAt }
    count = oldestFirst.count
    url = oldestFirst.first?.url ?? SurfaceFallbackURL.requests
    guard family != .small else {
      rows = []
      return
    }
    var seen = Set<String>()
    let perChat = oldestFirst.compactMap { request -> Row? in
      let id = "\(request.profile)/\(request.threadId)"
      guard seen.insert(id).inserted else { return nil }
      return Row(
        id: id, title: shownTitle(request.threadTitle), kind: request.kind,
        createdAt: request.createdAt, url: request.url)
    }
    rows = Array(perChat.prefix(3))
  }
}

/// The Board widget: Kanban counts, the next scheduled run, the last failure.
public struct BoardModel: Equatable, Sendable {
  public enum Part: Equatable, Sendable {
    case kanban(blocked: Int, review: Int, url: URL)

    /// `name` is `nil` when redacted.
    case failedJob(name: String?, at: Date, url: URL)

    /// `name` is `nil` when redacted. `isDue` once `at` has passed.
    case nextRun(name: String?, at: Date, isDue: Bool, url: URL)

    public var url: URL {
      switch self {
      case .kanban(_, _, let url), .failedJob(_, _, let url), .nextRun(_, _, _, let url): url
      }
    }
  }

  public let status: WidgetStatus

  /// The parts the server offers, a failure ahead of the next run; two in
  /// small, three in medium.
  public let parts: [Part]

  /// Why there are no parts, when there are none.
  public let emptyText: String?

  /// What a tap on the widget opens (small widgets have only this).
  public let url: URL?

  public init(snapshot: SurfaceSnapshot?, family: SurfaceFamily, now: Date) {
    status = WidgetStatus(snapshot: snapshot, now: now)
    guard let snapshot, !status.isSignedOut else {
      parts = []
      emptyText = nil
      url = nil
      return
    }
    var all: [Part] = []
    if let kanban = snapshot.kanban {
      all.append(.kanban(blocked: kanban.blocked, review: kanban.review, url: SurfaceFallbackURL.kanban))
    }
    if let failed = snapshot.schedules?.lastFailed {
      all.append(.failedJob(name: shownTitle(failed.name), at: failed.at, url: failed.url))
    }
    if let at = snapshot.schedules?.nextRunAt {
      all.append(
        .nextRun(
          name: snapshot.schedules?.nextJobName.flatMap(shownTitle), at: at, isDue: at <= now,
          url: SurfaceFallbackURL.schedules))
    }
    parts = Array(all.prefix(family == .small ? 2 : 3))
    emptyText =
      parts.isEmpty ? (snapshot.schedules == nil ? "No board or schedules on this server" : "Nothing scheduled") : nil
    // A small widget has one tap target, so a failure it shows is the better one.
    url = parts.first { if case .failedJob = $0 { true } else { false } }?.url ?? parts.first?.url
  }
}

/// When a widget needs a new timeline entry without the app writing a new
/// snapshot.
public enum SurfaceTimeline {
  /// Now; when the snapshot turns stale, so the widget can say so; and, for
  /// the Board, when the next run comes due, so it can read "Due".
  public static func dates(snapshot: SurfaceSnapshot?, now: Date, followsNextRun: Bool) -> [Date] {
    guard let snapshot, snapshot.signedIn else { return [now] }
    var dates = [now]
    let staleAt = snapshot.updatedAt.addingTimeInterval(surfaceStaleAfter)
    if staleAt > now { dates.append(staleAt) }
    if followsNextRun, let next = snapshot.schedules?.nextRunAt, next > now { dates.append(next) }
    return dates.sorted()
  }
}
