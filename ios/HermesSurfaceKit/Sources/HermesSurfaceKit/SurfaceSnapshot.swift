import Foundation

/// What the app shares with its widgets and other system surfaces: a short
/// picture of the user's Hermes state, written as one JSON string by the
/// Flutter app (`lib/src/surfaces/surface_snapshot.dart`, contract version 1).
///
/// It holds no token, server address or identity, and never the text of a
/// request. While App Lock is on the app writes it without titles, snippets
/// and job names: those arrive here as empty strings or `nil`.
///
/// Decoding is lenient like the app's own repositories: unreadable input,
/// or a `version` other than 1, yields `nil`; a malformed row is skipped;
/// a missing section is unavailable.
public struct SurfaceSnapshot: Equatable, Sendable {
  /// The UserDefaults key, in the App Group, the JSON is stored under.
  public static let key = "hermes.surface.v1"

  public let updatedAt: Date
  public let signedIn: Bool

  /// The profile the app shows.
  public let profile: String?

  /// The names of the server's profiles, in its order.
  public let profiles: [String]

  /// Newest first.
  public let recentChats: [RecentChat]
  public let pending: [PendingRequest]

  /// `nil` when the server has no Kanban plugin enabled.
  public let kanban: KanbanSummary?

  /// `nil` when the server has no scheduled tasks.
  public let schedules: ScheduleSummary?

  init(
    updatedAt: Date, signedIn: Bool, profile: String?, profiles: [String],
    recentChats: [RecentChat], pending: [PendingRequest], kanban: KanbanSummary?,
    schedules: ScheduleSummary?
  ) {
    self.updatedAt = updatedAt
    self.signedIn = signedIn
    self.profile = profile
    self.profiles = profiles
    self.recentChats = recentChats
    self.pending = pending
    self.kanban = kanban
    self.schedules = schedules
  }

  /// The snapshot in the App Group's UserDefaults, or `nil` when there is
  /// none or it is unreadable.
  public static func load(appGroup: String) -> SurfaceSnapshot? {
    decode(UserDefaults(suiteName: appGroup)?.string(forKey: key))
  }

  /// The snapshot in [json], or `nil` when it is missing, unreadable or of
  /// another version.
  public static func decode(_ json: String?) -> SurfaceSnapshot? {
    guard let data = json?.data(using: .utf8),
      let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
      root["version"] as? Int == 1,
      let updatedAt = SurfaceTime.parse(root["updatedAt"])
    else { return nil }
    return SurfaceSnapshot(
      updatedAt: updatedAt,
      signedIn: root["signedIn"] as? Bool ?? false,
      profile: root["profile"] as? String,
      profiles: (root["profiles"] as? [Any])?.compactMap { $0 as? String } ?? [],
      recentChats: rows(root["recentChats"], RecentChat.init(json:))
        .sorted { $0.updatedAt > $1.updatedAt },
      pending: rows(root["pending"], PendingRequest.init(json:)),
      kanban: KanbanSummary(json: root["kanban"]),
      schedules: ScheduleSummary(json: root["schedules"]))
  }

  private static func rows<T>(_ json: Any?, _ read: ([String: Any]) -> T?) -> [T] {
    (json as? [Any])?.compactMap { ($0 as? [String: Any]).flatMap(read) } ?? []
  }
}

/// One chat in `SurfaceSnapshot.recentChats`.
public struct RecentChat: Equatable, Sendable {
  public let profile: String
  public let id: String

  /// Empty while App Lock is on.
  public let title: String

  /// The start of the latest message; `nil` when there is none, or while
  /// App Lock is on.
  public let snippet: String?
  public let updatedAt: Date

  /// The `hermes://` link that opens the chat.
  public let url: URL

  init?(json: [String: Any]) {
    guard let profile = json["profile"] as? String,
      let id = json["id"] as? String,
      let title = json["title"] as? String,
      let updatedAt = SurfaceTime.parse(json["updatedAt"]),
      let url = SurfaceLink.parse(json["url"])
    else { return nil }
    self.init(
      profile: profile, id: id, title: title, snippet: json["snippet"] as? String,
      updatedAt: updatedAt, url: url)
  }

  init(profile: String, id: String, title: String, snippet: String?, updatedAt: Date, url: URL) {
    self.profile = profile
    self.id = id
    self.title = title
    self.snippet = snippet
    self.updatedAt = updatedAt
    self.url = url
  }
}

/// What an open request of the agent waits for. Never the command, the
/// question or the name of a secret.
public enum PendingKind: String, Equatable, Sendable {
  case approval
  case question
  case input
}

/// An open request, described by its chat and kind only.
public struct PendingRequest: Equatable, Sendable {
  public let profile: String
  public let threadId: String

  /// Empty while App Lock is on.
  public let threadTitle: String

  /// A kind this version does not know reads as `.input`, so it still counts.
  public let kind: PendingKind
  public let requestId: String

  /// When the app first learned of the request.
  public let createdAt: Date
  public let url: URL

  init?(json: [String: Any]) {
    guard let profile = json["profile"] as? String,
      let threadId = json["threadId"] as? String,
      let title = json["threadTitle"] as? String,
      let requestId = json["requestId"] as? String,
      let createdAt = SurfaceTime.parse(json["createdAt"]),
      let url = SurfaceLink.parse(json["url"])
    else { return nil }
    self.init(
      profile: profile, threadId: threadId, threadTitle: title,
      kind: (json["kind"] as? String).flatMap(PendingKind.init(rawValue:)) ?? .input,
      requestId: requestId, createdAt: createdAt, url: url)
  }

  init(
    profile: String, threadId: String, threadTitle: String, kind: PendingKind,
    requestId: String, createdAt: Date, url: URL
  ) {
    self.profile = profile
    self.threadId = threadId
    self.threadTitle = threadTitle
    self.kind = kind
    self.requestId = requestId
    self.createdAt = createdAt
    self.url = url
  }
}

/// How many Kanban tasks wait for the user.
public struct KanbanSummary: Equatable, Sendable {
  public let blocked: Int
  public let review: Int

  init(blocked: Int, review: Int) {
    self.blocked = blocked
    self.review = review
  }

  init?(json: Any?) {
    guard let json = json as? [String: Any],
      let blocked = json["blocked"] as? Int,
      let review = json["review"] as? Int
    else { return nil }
    self.init(blocked: blocked, review: review)
  }
}

/// The most recent scheduled run that failed.
public struct FailedJob: Equatable, Sendable {
  public let profile: String
  public let jobId: String

  /// Empty while App Lock is on.
  public let name: String
  public let at: Date

  /// The `hermes://` link that opens the job.
  public let url: URL

  init(profile: String, jobId: String, name: String, at: Date, url: URL) {
    self.profile = profile
    self.jobId = jobId
    self.name = name
    self.at = at
    self.url = url
  }

  init?(json: Any?) {
    guard let json = json as? [String: Any],
      let profile = json["profile"] as? String,
      let jobId = json["jobId"] as? String,
      let name = json["name"] as? String,
      let at = SurfaceTime.parse(json["at"]),
      let url = SurfaceLink.parse(json["url"])
    else { return nil }
    self.init(profile: profile, jobId: jobId, name: name, at: at, url: url)
  }
}

/// What the server's scheduled tasks are up to.
public struct ScheduleSummary: Equatable, Sendable {
  public let nextRunAt: Date?

  /// `nil` while App Lock is on, also when a run is due.
  public let nextJobName: String?
  public let lastFailed: FailedJob?

  init(nextRunAt: Date?, nextJobName: String?, lastFailed: FailedJob?) {
    self.nextRunAt = nextRunAt
    self.nextJobName = nextJobName
    self.lastFailed = lastFailed
  }

  init?(json: Any?) {
    guard let json = json as? [String: Any] else { return nil }
    self.init(
      nextRunAt: SurfaceTime.parse(json["nextRunAt"]),
      nextJobName: json["nextJobName"] as? String,
      lastFailed: FailedJob(json: json["lastFailed"]))
  }
}

enum SurfaceTime {
  /// The app writes whole seconds; fractional ones are read too.
  static func parse(_ value: Any?) -> Date? {
    guard let text = value as? String else { return nil }
    let plain = ISO8601DateFormatter()
    if let date = plain.date(from: text) { return date }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: text)
  }
}

enum SurfaceLink {
  /// A link from the snapshot, only when it is one of the app's own.
  static func parse(_ value: Any?) -> URL? {
    guard let text = value as? String, let url = URL(string: text), url.scheme == "hermes"
    else { return nil }
    return url
  }
}
