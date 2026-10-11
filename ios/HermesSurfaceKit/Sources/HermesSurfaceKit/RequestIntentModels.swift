import Foundation

// What the "Pending Requests" and "Answer Approval" intents say and decide,
// apart from App Intents itself so it can be tested with `swift test`: the
// shape of the Dart side's answers, the sentences Siri speaks, and the two
// flows that turn answers into a sentence. The Runner supplies the backend
// (`RequestIntentsBridge`), which runs the Dart side in a background engine.

/// How a request intent ended. The raw values are what Dart sends, and what
/// its telemetry records.
enum RequestOutcome: String, Equatable, Sendable {
  case answered
  case none
  case gone
  case cancelled
  case failed
  case signedOut = "signed_out"
  case deviceLocked = "device_locked"
  case unreachable
  case appLocked = "app_locked"
  /// No Dart engine answered in time.
  case unavailable
}

/// One open request as the Dart side lists it.
struct PendingRow: Equatable, Sendable {
  let profile: String
  let threadID: String
  /// Empty while App Lock is on.
  let title: String
  let kind: PendingKind
  let requestID: String
  let createdAt: Date?

  init(
    profile: String, threadID: String, title: String, kind: PendingKind, requestID: String,
    createdAt: Date?
  ) {
    self.profile = profile
    self.threadID = threadID
    self.title = title
    self.kind = kind
    self.requestID = requestID
    self.createdAt = createdAt
  }

  init?(json: Any) {
    guard let json = json as? [String: Any],
      let profile = json["profile"] as? String,
      let threadID = json["threadId"] as? String,
      let requestID = json["requestId"] as? String
    else { return nil }
    self.init(
      profile: profile, threadID: threadID, title: json["title"] as? String ?? "",
      kind: (json["kind"] as? String).flatMap(PendingKind.init(rawValue:)) ?? .input,
      requestID: requestID, createdAt: SurfaceTime.parse(json["createdAt"]))
  }

  init(_ request: PendingRequest) {
    self.init(
      profile: request.profile, threadID: request.threadId, title: request.threadTitle,
      kind: request.kind, requestID: request.requestId, createdAt: request.createdAt)
  }
}

/// What the Dart side answered to "what is waiting?".
struct PendingReply: Equatable, Sendable {
  let outcome: RequestOutcome
  /// How many requests wait, also when [requests] is empty because App Lock
  /// is on.
  let count: Int
  let appLock: Bool
  let requests: [PendingRow]

  /// No answer: the Dart side did not come up or did not reply in time.
  static let unavailable = PendingReply(outcome: .unavailable, count: 0, appLock: false, requests: [])

  init(outcome: RequestOutcome, count: Int, appLock: Bool, requests: [PendingRow]) {
    self.outcome = outcome
    self.count = count
    self.appLock = appLock
    self.requests = requests
  }

  init(json: [String: Any]?) {
    guard let json, let outcome = (json["outcome"] as? String).flatMap(RequestOutcome.init(rawValue:))
    else {
      self = .unavailable
      return
    }
    let rows = (json["requests"] as? [Any])?.compactMap(PendingRow.init(json:)) ?? []
    self.init(
      outcome: outcome, count: SurfaceJSON.int(json["count"]) ?? rows.count,
      appLock: SurfaceJSON.bool(json["appLock"]) ?? false, requests: rows)
  }
}

/// The command and offered choices of one open approval.
struct ApprovalDetail: Equatable, Sendable {
  let command: String
  let description: String
  let choices: [String]
}

enum DetailReply: Equatable, Sendable {
  case found(ApprovalDetail)
  case ended(RequestOutcome)

  init(json: [String: Any]?) {
    guard let json, let word = json["outcome"] as? String else {
      self = .ended(.unavailable)
      return
    }
    if word == "found" {
      self = .found(
        ApprovalDetail(
          command: json["command"] as? String ?? "",
          description: json["description"] as? String ?? "",
          choices: (json["choices"] as? [Any])?.compactMap { $0 as? String } ?? []))
    } else {
      self = .ended(RequestOutcome(rawValue: word) ?? .failed)
    }
  }
}

/// Which request an answer is about.
struct RequestRef: Equatable, Sendable {
  let profile: String
  let threadID: String
  let requestID: String
}

/// The Dart side of the request intents. The Runner implements it with a
/// background Flutter engine; tests fake it.
protocol RequestIntentsBackend: Sendable {
  func pending(profile: String?) async -> PendingReply
  func approvalDetail(_ request: RequestRef) async -> DetailReply
  func answerApproval(_ request: RequestRef, choice: ApprovalChoice) async -> RequestOutcome
  /// Tells telemetry the user cancelled the confirmation.
  func recordCancelled(choice: ApprovalChoice) async
}

/// Where the intents find their backend. The Runner sets it at launch; until
/// then, and in the widget extension, nothing is available.
enum RequestIntentsRuntime {
  nonisolated(unsafe) static var backend: RequestIntentsBackend = UnavailableBackend()
}

struct UnavailableBackend: RequestIntentsBackend {
  func pending(profile: String?) async -> PendingReply { .unavailable }
  func approvalDetail(_ request: RequestRef) async -> DetailReply { .ended(.unavailable) }
  func answerApproval(_ request: RequestRef, choice: ApprovalChoice) async -> RequestOutcome {
    .unavailable
  }
  func recordCancelled(choice: ApprovalChoice) async {}
}

/// What Siri says. The first three and the unavailable one are the sentences
/// "Ask Hermes" uses for the same situations.
enum RequestSpeech {
  static let signedOut = "Sign in to Hermes first."
  static let deviceLocked = "Unlock your iPhone first."
  static let unreachable = "Can't reach your Hermes server."
  static let unavailable = "Hermes isn't available right now."
  static let nothingWaiting = "Nothing is waiting for you."
  static let gone = "That request is no longer waiting."
  static let cancelled = "Cancelled."
  static let appLocked = "Open Hermes to answer this request."
  static let failedToRead = "Couldn't read your requests."
  static let failedToSend = "Couldn't send your answer."
  static let notAnApproval = "Only approvals can be answered here."
  static let noChoice = "Hermes doesn't offer an answer for this request. Open Hermes to answer it."

  /// The sentence for a run that ended without its result, or `nil` for an
  /// outcome that is a result.
  static func sentence(for outcome: RequestOutcome) -> String? {
    switch outcome {
    case .signedOut: return signedOut
    case .deviceLocked: return deviceLocked
    case .unreachable: return unreachable
    case .unavailable: return unavailable
    case .gone: return gone
    case .appLocked: return appLocked
    case .cancelled: return cancelled
    case .failed: return failedToSend
    case .answered, .none: return nil
    }
  }

  static func kindPhrase(_ kind: PendingKind) -> String {
    switch kind {
    case .approval: return "is waiting for your approval"
    case .question: return "has a question for you"
    case .input: return "is waiting for you in Hermes"
    }
  }

  /// The most requests named in one answer.
  static let listLimit = 5

  /// "2 requests: Trip plan is waiting for your approval. Backup has a
  /// question for you." Never more than [listLimit] are named. With
  /// [asOf], "As of 10:42, " comes first.
  static func list(
    _ rows: [PendingRow], count: Int, asOf: Date? = nil, locale: Locale = .current,
    timeZone: TimeZone = .current
  ) -> String {
    let prefix = asOfPrefix(asOf, locale: locale, timeZone: timeZone)
    guard count > 0 else { return nothing(prefix) }
    let header = count == 1 ? "1 request:" : "\(count) requests:"
    var parts = rows.prefix(listLimit).map { "\(name($0)) \(kindPhrase($0.kind))." }
    if count > listLimit { parts.append("and \(count - listLimit) more.") }
    return prefix + ([header] + parts).joined(separator: " ")
  }

  /// What is said while App Lock keeps the titles inside the app.
  static func countOnly(_ count: Int, asOf: Date? = nil, locale: Locale = .current, timeZone: TimeZone = .current)
    -> String
  {
    let prefix = asOfPrefix(asOf, locale: locale, timeZone: timeZone)
    guard count > 0 else { return nothing(prefix) }
    let body =
      count == 1
      ? "1 request is waiting. Open Hermes to see it."
      : "\(count) requests are waiting. Open Hermes to see them."
    return asOf == nil ? body : prefix + body.prefix(1).lowercased() + body.dropFirst()
  }

  private static func asOfPrefix(_ asOf: Date?, locale: Locale, timeZone: TimeZone) -> String {
    asOf.map { "As of \(time($0, locale: locale, timeZone: timeZone)), " } ?? ""
  }

  private static func nothing(_ prefix: String) -> String {
    prefix.isEmpty ? nothingWaiting : prefix + "nothing is waiting for you."
  }

  private static func name(_ row: PendingRow) -> String {
    row.title.isEmpty ? ChatEntity.untitled : row.title
  }

  private static func time(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
    let formatter = DateFormatter()
    formatter.locale = locale
    formatter.timeZone = timeZone
    formatter.dateStyle = .none
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }

  static func approved(_ choice: ApprovalChoice) -> String {
    switch choice {
    case .once: return "Approved once."
    case .session: return "Approved for this session."
    case .always: return "Approved always."
    case .deny: return "Denied."
    }
  }

  static func notOffered(_ choice: ApprovalChoice) -> String {
    "Hermes doesn't offer \(choice.title) for this request."
  }

  static func confirmation(_ choice: ApprovalChoice) -> String {
    switch choice {
    case .once: return "Allow Hermes to run this once?"
    case .session: return "Allow Hermes to run this for this session?"
    case .always: return "Allow Hermes to run this always?"
    case .deny: return "Deny this request?"
    }
  }
}

/// What "Pending Requests" ends with: the sentence, and the requests for
/// Shortcuts (none while App Lock is on).
struct PendingAnswer: Equatable, Sendable {
  let text: String
  let rows: [PendingRow]
}

/// "Pending Requests": asks the Dart side for a fresh list and falls back to
/// the snapshot the app last shared.
struct PendingRequestsFlow {
  let backend: RequestIntentsBackend
  /// The snapshot the app last stored.
  var stored: () -> SurfaceSnapshot? = { SurfaceSnapshot.load(appGroup: SurfaceSnapshot.appGroup) }
  var locale: Locale = .current
  var timeZone: TimeZone = .current

  func run(profile: String?) async -> PendingAnswer {
    let reply = await backend.pending(profile: profile)
    switch reply.outcome {
    case .answered, .none:
      if reply.appLock { return PendingAnswer(text: RequestSpeech.countOnly(reply.count), rows: []) }
      return PendingAnswer(
        text: RequestSpeech.list(reply.requests, count: reply.count), rows: reply.requests)
    case .signedOut, .deviceLocked, .unreachable, .unavailable, .failed, .gone, .cancelled, .appLocked:
      return fallback(reply.outcome, profile: profile)
    }
  }

  /// The last list the app shared, if a user is signed in; otherwise the
  /// sentence for why there is none. A stored snapshot with titles missing
  /// was written under App Lock.
  private func fallback(_ outcome: RequestOutcome, profile: String?) -> PendingAnswer {
    guard let snapshot = stored(), snapshot.signedIn else {
      let text = outcome == .failed ? nil : RequestSpeech.sentence(for: outcome)
      return PendingAnswer(text: text ?? RequestSpeech.failedToRead, rows: [])
    }
    let rows = snapshot.pending.filter { profile == nil || $0.profile == profile }
      .map(PendingRow.init)
      .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
    if rows.contains(where: { $0.title.isEmpty }) {
      return PendingAnswer(
        text: RequestSpeech.countOnly(
          rows.count, asOf: snapshot.updatedAt, locale: locale, timeZone: timeZone),
        rows: [])
    }
    return PendingAnswer(
      text: RequestSpeech.list(
        rows, count: rows.count, asOf: snapshot.updatedAt, locale: locale, timeZone: timeZone),
      rows: rows)
  }
}

/// What the confirmation shows and speaks before an approval is allowed.
struct ConfirmationPrompt: Equatable, Sendable {
  let question: String
  let command: String
  let description: String

  /// The question, then the command, then what Hermes says it is for.
  var text: String {
    [question, command, description].filter { !$0.isEmpty }.joined(separator: "\n")
  }
}

/// "Answer Approval": looks the approval up, settles the choice, asks for
/// confirmation and answers.
struct ApprovalAnswerFlow {
  let backend: RequestIntentsBackend

  /// Returns what Siri says. [pick] asks the user which of the offered
  /// choices; [confirm] asks to allow, and throws when the user declines.
  func run(
    request: PendingRequestEntity,
    choice: ApprovalChoice?,
    pick: ([ApprovalChoice]) async throws -> ApprovalChoice,
    confirm: (ConfirmationPrompt) async throws -> Void
  ) async -> String {
    guard request.kind == .approval else { return RequestSpeech.notAnApproval }
    let ref = RequestRef(
      profile: request.profile, threadID: request.threadID, requestID: request.requestID)
    let detail: ApprovalDetail
    switch await backend.approvalDetail(ref) {
    case .ended(let outcome):
      return RequestSpeech.sentence(for: outcome) ?? RequestSpeech.failedToSend
    case .found(let found):
      detail = found
    }
    let offered = ApprovalChoice.allCases.filter { detail.choices.contains($0.rawValue) }
    guard !offered.isEmpty else { return RequestSpeech.noChoice }

    let chosen: ApprovalChoice
    if let choice {
      guard offered.contains(choice) else { return RequestSpeech.notOffered(choice) }
      chosen = choice
    } else if offered.count == 1 {
      chosen = offered[0]
    } else {
      do { chosen = try await pick(offered) } catch { return RequestSpeech.cancelled }
    }

    if chosen != .deny {
      let prompt = ConfirmationPrompt(
        question: RequestSpeech.confirmation(chosen), command: detail.command,
        description: detail.description)
      do { try await confirm(prompt) } catch {
        await backend.recordCancelled(choice: chosen)
        return RequestSpeech.cancelled
      }
    }

    let outcome = await backend.answerApproval(ref, choice: chosen)
    switch outcome {
    case .answered: return RequestSpeech.approved(chosen)
    default: return RequestSpeech.sentence(for: outcome) ?? RequestSpeech.failedToSend
    }
  }
}
