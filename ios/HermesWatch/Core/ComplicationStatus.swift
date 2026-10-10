import Foundation

/// What the phone last said about the latest turn, for the complications and
/// the Smart Stack widget. It never holds anything a reply, a command or a
/// question said: a state, a time, and the chat's title and id when the phone
/// may share them (not while App Lock is on).
struct ComplicationStatus: Codable, Equatable {
  enum State: String, Codable {
    case working
    case waiting
    case ready
    case failed

    /// The word the complication shows.
    var label: String {
      switch self {
      case .working: "Working"
      case .waiting: "Waiting for you"
      case .ready: "Reply ready"
      case .failed: "Failed"
      }
    }

    var finished: Bool { self == .ready || self == .failed }
  }

  /// The most characters of a title a complication takes, more than any face
  /// shows.
  static let titleLimit = 80

  static func clipped(_ title: String) -> String {
    title.count > titleLimit ? String(title.prefix(titleLimit)) + "…" : title
  }

  let state: State
  let updatedAt: Date
  /// Nil under App Lock, or for a chat the gateway has not named yet.
  var title: String?
  /// The watch's id for the chat; nil under App Lock or while the chat is not
  /// stored on the server.
  var threadId: String?
}

/// A message from the phone, decoded.
enum ComplicationUpdate: Equatable {
  case show(ComplicationStatus)
  case clear

  /// Nil for a message this watch does not understand, such as one from a
  /// newer phone app.
  init?(payload: [String: Any], now: Date = Date()) {
    guard payload["v"] as? Int == 1, let name = payload["state"] as? String else { return nil }
    if name == "none" {
      self = .clear
      return
    }
    guard let state = ComplicationStatus.State(rawValue: name) else { return nil }
    func text(_ key: String) -> String? {
      guard let value = (payload[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
        !value.isEmpty
      else { return nil }
      return value
    }
    let title = text("title").map(ComplicationStatus.clipped)
    let updatedAt = (payload["updatedAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) } ?? now
    self = .show(
      ComplicationStatus(state: state, updatedAt: updatedAt, title: title, threadId: text("threadId")))
  }
}

extension ComplicationUpdate {
  /// The message's place in the phone's order, when it says one. The phone
  /// numbers its messages upward (the clock in milliseconds, at least), and
  /// they can arrive out of order.
  static func seq(of payload: [String: Any]) -> Int64? {
    (payload["seq"] as? NSNumber)?.int64Value
  }
}

/// Keeps the status where the watch app and its widget extension both read it,
/// in the App Group's defaults.
struct ComplicationStore {
  static let appGroup = "group.com.cedricziel.hermesApp"
  static let key = "complication.status"
  static let seqKey = "complication.seq"
  /// A day in milliseconds: the lead of a held number over a new one that no
  /// delivery delay explains.
  static let clockJump: Int64 = 24 * 3600 * 1000

  let defaults: UserDefaults

  static var shared: ComplicationStore {
    ComplicationStore(defaults: UserDefaults(suiteName: appGroup) ?? .standard)
  }

  func status() -> ComplicationStatus? {
    guard let data = defaults.data(forKey: Self.key) else { return nil }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return try? decoder.decode(ComplicationStatus.self, from: data)
  }

  /// Stores what [update] says, unless a message with a higher [seq] was
  /// applied before it: the phone can deliver two messages out of order, and a
  /// clear is remembered so a late status does not bring the chat back. A
  /// message without a number is always taken. The numbers are the phone's
  /// clock, so a lower one is taken all the same when the held one is more
  /// than a day ahead, or when its status is newer than the held status: the
  /// clock moved back, and refusing it would freeze the complication. Answers
  /// whether the message was taken.
  @discardableResult
  func apply(_ update: ComplicationUpdate, seq: Int64? = nil) -> Bool {
    if let seq {
      // A Double, since `Int` is 32 bits on the older watches and the number is
      // the clock in milliseconds; a Double holds it exactly.
      let held = Int64(defaults.double(forKey: Self.seqKey))
      var newer = seq > held
      if !newer {
        let clockMovedBack: Bool
        switch update {
        case .show(let status):
          clockMovedBack = held - seq > Self.clockJump || self.status().map { status.updatedAt > $0.updatedAt } ?? false
        case .clear:
          clockMovedBack = held - seq > Self.clockJump
        }
        newer = clockMovedBack
      }
      guard newer else { return false }
      defaults.set(Double(seq), forKey: Self.seqKey)
    }
    switch update {
    case .clear:
      defaults.removeObject(forKey: Self.key)
    case .show(let status):
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .secondsSince1970
      defaults.set(try? encoder.encode(status), forKey: Self.key)
    }
    return true
  }
}

/// One entry of the widget's timeline. The relevance ranks the Smart Stack
/// card among the others for [duration] seconds from [date].
struct ComplicationEntry: Equatable {
  let date: Date
  /// Nil when there is nothing to show.
  let status: ComplicationStatus?
  let relevance: Double
  let duration: TimeInterval?
}

enum ComplicationTimeline {
  /// How long a working or waiting status is believed without news. Hermes has
  /// no push channel, so a phone app that iOS suspended cannot say the turn
  /// ended; showing "Working" for hours would be worse than showing nothing.
  static let staleAfter: TimeInterval = 30 * 60
  /// How long a reply ranks high in the Smart Stack after it ends.
  static let freshReplyWindow: TimeInterval = 10 * 60
  /// How long a finished reply is shown at all.
  static let replyVisibleFor: TimeInterval = 6 * 3600

  static func plan(for status: ComplicationStatus?, now: Date) -> [ComplicationEntry] {
    let idle = { (date: Date) in ComplicationEntry(date: date, status: nil, relevance: 0, duration: nil) }
    guard let status else { return [idle(now)] }
    // A phone clock ahead of the watch's would otherwise delay the end.
    let start = min(status.updatedAt, now)

    if !status.state.finished {
      let end = start.addingTimeInterval(staleAfter)
      guard now < end else { return [idle(now)] }
      let relevance = status.state == .waiting ? 1.0 : 0.5
      return [
        ComplicationEntry(date: now, status: status, relevance: relevance, duration: end.timeIntervalSince(now)),
        idle(end),
      ]
    }

    let freshEnd = start.addingTimeInterval(freshReplyWindow)
    let visibleEnd = start.addingTimeInterval(replyVisibleFor)
    guard now < visibleEnd else { return [idle(now)] }
    if now >= freshEnd {
      return [
        ComplicationEntry(date: now, status: status, relevance: 0.1, duration: visibleEnd.timeIntervalSince(now)),
        idle(visibleEnd),
      ]
    }
    return [
      ComplicationEntry(date: now, status: status, relevance: 0.8, duration: freshEnd.timeIntervalSince(now)),
      ComplicationEntry(
        date: freshEnd, status: status, relevance: 0.1, duration: visibleEnd.timeIntervalSince(freshEnd)),
      idle(visibleEnd),
    ]
  }
}

/// Where a tap on a complication goes. The links stay on the watch, so the
/// chat's title can travel in one.
enum ComplicationLink: Equatable {
  case voice
  case open
  case chat(id: String, title: String?)

  static let scheme = "hermes-watch"

  var url: URL? {
    var components = URLComponents()
    components.scheme = Self.scheme
    switch self {
    case .voice:
      components.host = "voice"
    case .open:
      components.host = "open"
    case .chat(let id, let title):
      components.host = "chat"
      components.queryItems = [URLQueryItem(name: "id", value: id)] + (title.map { [URLQueryItem(name: "title", value: $0)] } ?? [])
    }
    return components.url
  }

  private static func isChatId(_ id: String) -> Bool {
    guard let slash = id.firstIndex(of: "/") else { return false }
    return id.index(after: slash) < id.endIndex
  }

  init?(url: URL) {
    guard url.scheme == Self.scheme else { return nil }
    switch url.host {
    case "voice":
      self = .voice
    case "open":
      self = .open
    case "chat":
      let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
      // `<profile>/<session>`, the shape the phone gives every chat id.
      guard let id = items.first(where: { $0.name == "id" })?.value, Self.isChatId(id) else { return nil }
      self = .chat(id: id, title: items.first(where: { $0.name == "title" })?.value.map(ComplicationStatus.clipped))
    default:
      return nil
    }
  }
}
