import AppIntents
import Foundation

// "Pending Requests" and "Answer Approval": what Hermes is waiting for, and an
// approval answered from Siri or Shortcuts. Both run in the app's process
// (`supportedModes = .background`) and reach Hermes through the Dart side
// (`RequestIntentsRuntime.backend`). They are compiled into the Runner only.

/// An answer to an approval, as Hermes names the choices.
enum ApprovalChoice: String, AppEnum, CaseIterable, Sendable {
  case once
  case session
  case always
  case deny

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Choice"
  static let caseDisplayRepresentations: [ApprovalChoice: DisplayRepresentation] = [
    .once: "Once",
    .session: "This session",
    .always: "Always",
    .deny: "Deny",
  ]

  /// How the choice reads in a sentence.
  var title: String {
    switch self {
    case .once: return "Once"
    case .session: return "This session"
    case .always: return "Always"
    case .deny: return "Deny"
    }
  }
}

/// An open request of the agent, as an App Intents parameter. It names the
/// chat and the kind, never the command or the question.
struct PendingRequestEntity: AppEntity, Equatable {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Request"
  static let defaultQuery = PendingRequestQuery()

  /// `<profile>/<thread id>/<request id>`, each part percent-encoded.
  let id: String
  let profile: String
  let threadID: String
  let requestID: String
  let kind: PendingKind
  let raisedAt: Date?

  /// The chat's title; "Chat" while App Lock keeps it inside the app.
  let title: String
  private let titleHidden: Bool

  init(
    profile: String, threadID: String, requestID: String, title: String, kind: PendingKind,
    raisedAt: Date? = nil
  ) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    self.id = Self.makeID(profile: profile, threadID: threadID, requestID: requestID)
    self.profile = profile
    self.threadID = threadID
    self.requestID = requestID
    self.kind = kind
    self.raisedAt = raisedAt
    self.title = trimmed.isEmpty ? ChatEntity.untitled : trimmed
    self.titleHidden = ChatEntity.hides(trimmed)
  }

  init(_ row: PendingRow) {
    self.init(
      profile: row.profile, threadID: row.threadID, requestID: row.requestID, title: row.title,
      kind: row.kind, raisedAt: row.createdAt)
  }

  static func makeID(profile: String, threadID: String, requestID: String) -> String {
    [profile, threadID, requestID]
      .map { $0.addingPercentEncoding(withAllowedCharacters: DeepLink.unreserved) ?? "" }
      .joined(separator: "/")
  }

  /// A request named only by its [id]. The kind is taken to be an approval,
  /// the only kind the picker offers; the Dart side settles whether it still
  /// waits.
  static func parse(id: String) -> PendingRequestEntity? {
    let parts = id.split(separator: "/", omittingEmptySubsequences: false)
    guard parts.count == 3 else { return nil }
    let decoded = parts.compactMap { String($0).removingPercentEncoding }
    guard decoded.count == 3, !decoded[1].isEmpty, !decoded[2].isEmpty else { return nil }
    return PendingRequestEntity(
      profile: decoded[0], threadID: decoded[1], requestID: decoded[2], title: "", kind: .approval)
  }

  var kindLabel: String {
    switch kind {
    case .approval: return "Approval"
    case .question: return "Question"
    case .input: return "Waiting"
    }
  }

  /// The kind and when it was raised, with the profile when the title says
  /// nothing about the chat.
  func subtitle(now: Date = .now) -> String {
    var parts = [kindLabel]
    if titleHidden { parts.append(profile) }
    if let raisedAt {
      let formatter = RelativeDateTimeFormatter()
      formatter.unitsStyle = .short
      parts.append(formatter.localizedString(for: raisedAt, relativeTo: now))
    }
    return parts.joined(separator: " · ")
  }

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: "\(title)", subtitle: "\(subtitle())", image: .init(systemName: "checkmark.shield"))
  }
}

/// The approvals Answer Approval offers: those of the snapshot the app last
/// shared, optionally of one profile.
struct PendingRequestQuery: EntityQuery {
  @IntentParameterDependency<AnswerApprovalIntent>(\.$profile)
  var intent

  func entities(for identifiers: [PendingRequestEntity.ID]) async throws -> [PendingRequestEntity] {
    IntentDirectory.current().pendingRequests(withIDs: identifiers)
  }

  func suggestedEntities() async throws -> [PendingRequestEntity] {
    IntentDirectory.current().approvals(profile: intent?.profile.id)
  }
}

extension IntentDirectory {
  /// The open approvals, oldest first. Nothing while signed out.
  func approvals(profile: String? = nil) -> [PendingRequestEntity] {
    pendingRows.filter { $0.kind == .approval && (profile == nil || $0.profile == profile) }
      .map(PendingRequestEntity.init)
  }

  /// A request a saved shortcut names that the snapshot no longer holds is
  /// still returned, so that running it says it is gone.
  func pendingRequests(withIDs ids: [String]) -> [PendingRequestEntity] {
    let known = pendingRows
    return ids.compactMap { id in
      guard let parsed = PendingRequestEntity.parse(id: id) else { return nil }
      return known.first {
        $0.profile == parsed.profile && $0.threadID == parsed.threadID
          && $0.requestID == parsed.requestID
      }.map(PendingRequestEntity.init) ?? parsed
    }
  }

  private var pendingRows: [PendingRow] {
    (offered?.pending ?? []).map(PendingRow.init).sorted {
      let (a, b) = ($0.createdAt ?? .distantPast, $1.createdAt ?? .distantPast)
      return a == b ? $0.requestID < $1.requestID : a < b
    }
  }
}

struct PendingRequestsIntent: AppIntent {
  static let title: LocalizedStringResource = "Pending Requests"
  static let description = IntentDescription(
    "Tells you what Hermes is waiting for: approvals and questions, across your profiles.")
  static var supportedModes: IntentModes { .background }
  static var authenticationPolicy: IntentAuthenticationPolicy { .alwaysAllowed }

  @Parameter(title: "Profile", description: "Only this Hermes profile; all if empty.")
  var profile: ProfileEntity?

  static var parameterSummary: some ParameterSummary {
    Summary("Pending requests in \(\.$profile)")
  }

  func perform() async throws -> some IntentResult & ReturnsValue<[PendingRequestEntity]>
    & ProvidesDialog
  {
    let answer = await PendingRequestsFlow(backend: RequestIntentsRuntime.backend)
      .run(profile: profile?.id)
    return .result(
      value: answer.rows.map(PendingRequestEntity.init), dialog: IntentDialog("\(answer.text)"))
  }
}

struct AnswerApprovalIntent: AppIntent {
  static let title: LocalizedStringResource = "Answer Approval"
  static let description = IntentDescription(
    "Answers an approval Hermes is waiting for. The command is shown before you confirm.")
  static var supportedModes: IntentModes { .background }
  static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }

  @Parameter(title: "Request")
  var request: PendingRequestEntity

  @Parameter(title: "Choice", description: "Asked for if empty.")
  var choice: ApprovalChoice?

  @Parameter(title: "Profile", description: "Only offer this profile's approvals.")
  var profile: ProfileEntity?

  static var parameterSummary: some ParameterSummary {
    Summary("Answer \(\.$request) with \(\.$choice)") {
      \.$profile
    }
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let text = await ApprovalAnswerFlow(backend: RequestIntentsRuntime.backend).run(
      request: request, choice: choice,
      pick: { options in
        try await $choice.requestDisambiguation(
          among: options, dialog: IntentDialog("Which answer?"))
      },
      confirm: { prompt in
        try await requestConfirmation(actionName: .run, dialog: IntentDialog("\(prompt.text)"))
      })
    return .result(dialog: IntentDialog("\(text)"))
  }
}
