import XCTest

@testable import HermesSurfaceKit

private let at = date("2026-10-10T12:00:00Z")
private let utc = TimeZone(identifier: "UTC")!
private let british = Locale(identifier: "en_GB")

private func row(
  _ request: String, title: String = "Trip plan", kind: PendingKind = .approval,
  profile: String = "default", thread: String? = nil, minutesAgo: Int = 5
) -> PendingRow {
  PendingRow(
    profile: profile, threadID: thread ?? "t-\(request)", title: title, kind: kind,
    requestID: request, createdAt: at.addingTimeInterval(TimeInterval(-60 * minutesAgo)))
}

private func snapshot(
  signedIn: Bool = true, pending: [PendingRow] = [], updatedAt: Date = at
) -> SurfaceSnapshot {
  SurfaceSnapshot(
    updatedAt: updatedAt, signedIn: signedIn, profile: "default", profiles: ["default", "work"],
    recentChats: [],
    pending: pending.map {
      PendingRequest(
        profile: $0.profile, threadId: $0.threadID, threadTitle: $0.title, kind: $0.kind,
        requestId: $0.requestID, createdAt: $0.createdAt ?? at,
        url: DeepLink.chat(profile: $0.profile, id: $0.threadID))
    }, kanban: nil, schedules: nil)
}

private func entity(
  _ request: String = "r1", kind: PendingKind = .approval, profile: String = "default"
) -> PendingRequestEntity {
  PendingRequestEntity(
    profile: profile, threadID: "t-\(request)", requestID: request, title: "Trip plan", kind: kind)
}

/// A backend that answers what the test set and remembers what it was asked.
final class FakeBackend: RequestIntentsBackend, @unchecked Sendable {
  private let lock = NSLock()
  private var _calls: [String] = []
  var pendingReply = PendingReply.unavailable
  var detailReply = DetailReply.ended(.unavailable)
  var answerOutcome = RequestOutcome.answered

  var calls: [String] {
    lock.lock()
    defer { lock.unlock() }
    return _calls
  }

  private func note(_ call: String) {
    lock.lock()
    _calls.append(call)
    lock.unlock()
  }

  func pending(profile: String?) async -> PendingReply {
    note("pending \(profile ?? "-")")
    return pendingReply
  }

  func approvalDetail(_ request: RequestRef) async -> DetailReply {
    note("detail \(request.profile)/\(request.threadID)/\(request.requestID)")
    return detailReply
  }

  func answerApproval(_ request: RequestRef, choice: ApprovalChoice) async -> RequestOutcome {
    note("answer \(request.requestID) \(choice.rawValue)")
    return answerOutcome
  }

  func recordCancelled(choice: ApprovalChoice) async { note("cancelled \(choice.rawValue)") }
}

final class PendingRequestEntityTests: XCTestCase {
  func testTheIdIsTheThreePartsEncodedAndRoundTrips() throws {
    let found = PendingRequestEntity(
      profile: "R&D/team", threadID: "a/b", requestID: "c++ 1", title: "T", kind: .approval)
    XCTAssertEqual(found.id, "R%26D%2Fteam/a%2Fb/c%2B%2B%201")
    let parsed = try XCTUnwrap(PendingRequestEntity.parse(id: found.id))
    XCTAssertEqual(parsed.profile, "R&D/team")
    XCTAssertEqual(parsed.threadID, "a/b")
    XCTAssertEqual(parsed.requestID, "c++ 1")
  }

  func testAnIdWithoutThreePartsIsNoRequest() {
    XCTAssertNil(PendingRequestEntity.parse(id: "a/b"))
    XCTAssertNil(PendingRequestEntity.parse(id: "a/b/c/d"))
    XCTAssertNil(PendingRequestEntity.parse(id: "a//c"))
    XCTAssertNil(PendingRequestEntity.parse(id: "a/b/"))
  }

  func testAnEmptyTitleIsShownAsChatWithTheProfileAndKind() {
    let hidden = PendingRequestEntity(
      profile: "work", threadID: "t", requestID: "r", title: "", kind: .approval,
      raisedAt: at.addingTimeInterval(-7200))
    XCTAssertEqual(hidden.title, "Chat")
    XCTAssertTrue(hidden.subtitle(now: at).hasPrefix("Approval · work · "), hidden.subtitle(now: at))
  }

  func testANamedChatShowsKindAndAgeOnly() {
    let named = PendingRequestEntity(
      profile: "work", threadID: "t", requestID: "r", title: "Trip plan", kind: .question,
      raisedAt: at.addingTimeInterval(-7200))
    XCTAssertEqual(named.title, "Trip plan")
    XCTAssertTrue(named.subtitle(now: at).hasPrefix("Question · "), named.subtitle(now: at))
    XCTAssertFalse(named.subtitle(now: at).contains("work"))
  }
}

final class ApprovalsDirectoryTests: XCTestCase {
  private func directory(_ rows: [PendingRow], signedIn: Bool = true) -> IntentDirectory {
    IntentDirectory(snapshot: snapshot(signedIn: signedIn, pending: rows))
  }

  func testOffersOnlyApprovalsOldestFirst() {
    let found = directory([
      row("new", minutesAgo: 1), row("q", kind: .question, minutesAgo: 90),
      row("old", minutesAgo: 60),
    ]).approvals()
    XCTAssertEqual(found.map(\.requestID), ["old", "new"])
  }

  func testNarrowsToOneProfile() {
    let found = directory([row("a"), row("b", profile: "work")]).approvals(profile: "work")
    XCTAssertEqual(found.map(\.requestID), ["b"])
  }

  func testOffersNothingWhileSignedOutOrWithoutASnapshot() {
    XCTAssertEqual(directory([row("a")], signedIn: false).approvals(), [])
    XCTAssertEqual(IntentDirectory(snapshot: nil).approvals(), [])
  }

  func testTheCommandIsNowhereInTheEntity() {
    let described = String(describing: directory([row("a")]).approvals())
    XCTAssertFalse(described.contains("rm -rf"))
  }

  func testAKnownIdKeepsItsKindAndTitle() {
    let known = directory([row("q", kind: .question)])
    let id = entity("q", kind: .approval).id
    XCTAssertEqual(known.pendingRequests(withIDs: [id]).map(\.kind), [.question])
    XCTAssertEqual(known.pendingRequests(withIDs: [id]).map(\.title), ["Trip plan"])
  }

  func testAnUnknownIdStillResolvesSoRunningItSaysItIsGone() {
    let found = directory([]).pendingRequests(withIDs: [entity("old").id, "junk"])
    XCTAssertEqual(found.map(\.requestID), ["old"])
    XCTAssertEqual(found.map(\.kind), [.approval])
  }

  func testTheSameRequestIdInTwoProfilesStaysApart() {
    let found = directory([row("r", profile: "default"), row("r", profile: "work")]).approvals()
    XCTAssertEqual(Set(found.map(\.id)).count, 2)
  }
}

final class RequestSpeechTests: XCTestCase {
  private func list(_ rows: [PendingRow], count: Int? = nil, asOf: Date? = nil) -> String {
    RequestSpeech.list(rows, count: count ?? rows.count, asOf: asOf, locale: british, timeZone: utc)
  }

  func testTwoRequests() {
    XCTAssertEqual(
      list([
        row("1", title: "Trip plan"), row("2", title: "Backup", kind: .question),
      ]),
      "2 requests: Trip plan is waiting for your approval. Backup has a question for you.")
  }

  func testOneRequestAndTheGenericKind() {
    XCTAssertEqual(
      list([row("1", kind: .input)]), "1 request: Trip plan is waiting for you in Hermes.")
  }

  func testNothing() {
    XCTAssertEqual(list([]), "Nothing is waiting for you.")
  }

  func testNamesFiveAndSumsUpTheRest() {
    let rows = (1...8).map { row("r\($0)", title: "Chat \($0)") }
    let said = list(rows)
    XCTAssertTrue(said.hasPrefix("8 requests: Chat 1 is waiting"), said)
    XCTAssertTrue(said.contains("Chat 5 is waiting for your approval. and 3 more."), said)
    XCTAssertFalse(said.contains("Chat 6"), said)
  }

  func testPrefixesTheTimeOfAStoredList() {
    XCTAssertEqual(
      list([row("1")], asOf: date("2026-10-10T10:42:00Z")),
      "As of 10:42, 1 request: Trip plan is waiting for your approval.")
    XCTAssertEqual(
      list([], asOf: date("2026-10-10T10:42:00Z")), "As of 10:42, nothing is waiting for you.")
  }

  func testCountOnly() {
    XCTAssertEqual(
      RequestSpeech.countOnly(2), "2 requests are waiting. Open Hermes to see them.")
    XCTAssertEqual(RequestSpeech.countOnly(1), "1 request is waiting. Open Hermes to see it.")
    XCTAssertEqual(RequestSpeech.countOnly(0), "Nothing is waiting for you.")
    XCTAssertEqual(
      RequestSpeech.countOnly(
        2, asOf: date("2026-10-10T10:42:00Z"), locale: british, timeZone: utc),
      "As of 10:42, 2 requests are waiting. Open Hermes to see them.")
  }

  func testAnEmptyTitleIsSpokenAsChat() {
    XCTAssertEqual(
      list([row("1", title: "")]), "1 request: Chat is waiting for your approval.")
  }

  func testTheSentencesForAnApproval() {
    XCTAssertEqual(RequestSpeech.approved(.once), "Approved once.")
    XCTAssertEqual(RequestSpeech.approved(.session), "Approved for this session.")
    XCTAssertEqual(RequestSpeech.approved(.always), "Approved always.")
    XCTAssertEqual(RequestSpeech.approved(.deny), "Denied.")
    XCTAssertEqual(
      RequestSpeech.notOffered(.always), "Hermes doesn't offer Always for this request.")
  }

  func testTheSentencesMatchAskHermes() {
    XCTAssertEqual(RequestSpeech.sentence(for: .signedOut), "Sign in to Hermes first.")
    XCTAssertEqual(RequestSpeech.sentence(for: .deviceLocked), "Unlock your iPhone first.")
    XCTAssertEqual(RequestSpeech.sentence(for: .unreachable), "Can't reach your Hermes server.")
    XCTAssertEqual(RequestSpeech.sentence(for: .unavailable), "Hermes isn't available right now.")
  }
}

final class PendingRequestsFlowTests: XCTestCase {
  private var backend = FakeBackend()
  private var stored: SurfaceSnapshot?

  override func setUp() {
    backend = FakeBackend()
    stored = nil
  }

  private func run(profile: String? = nil) async -> PendingAnswer {
    await PendingRequestsFlow(
      backend: backend, stored: { self.stored }, locale: british, timeZone: utc
    ).run(profile: profile)
  }

  private func reply(_ rows: [PendingRow], appLock: Bool = false) -> PendingReply {
    PendingReply(
      outcome: rows.isEmpty ? .none : .answered, count: rows.count, appLock: appLock,
      requests: appLock ? [] : rows)
  }

  func testSpeaksTheFreshList() async {
    backend.pendingReply = reply([row("1"), row("2", title: "Backup", kind: .question)])
    stored = snapshot(pending: [row("old")])

    let answer = await run()

    XCTAssertEqual(
      answer.text,
      "2 requests: Trip plan is waiting for your approval. Backup has a question for you.")
    XCTAssertEqual(answer.rows.map(\.requestID), ["1", "2"])
    XCTAssertEqual(backend.calls, ["pending -"])
  }

  func testPassesTheProfileOn() async {
    backend.pendingReply = reply([])
    _ = await run(profile: "work")
    XCTAssertEqual(backend.calls, ["pending work"])
  }

  func testSaysNothingIsWaiting() async {
    backend.pendingReply = reply([])
    let answer = await run()
    XCTAssertEqual(answer.text, "Nothing is waiting for you.")
    XCTAssertEqual(answer.rows, [])
  }

  func testGivesTheCountOnlyUnderAppLock() async {
    backend.pendingReply = PendingReply(outcome: .answered, count: 2, appLock: true, requests: [])
    let answer = await run()
    XCTAssertEqual(answer.text, "2 requests are waiting. Open Hermes to see them.")
    XCTAssertEqual(answer.rows, [])
  }

  func testFallsBackToTheStoredListWhenTheServerIsUnreachable() async {
    backend.pendingReply = PendingReply(outcome: .unreachable, count: 0, appLock: false, requests: [])
    stored = snapshot(pending: [row("1")], updatedAt: date("2026-10-10T10:42:00Z"))

    let answer = await run()

    XCTAssertEqual(
      answer.text, "As of 10:42, 1 request: Trip plan is waiting for your approval.")
    XCTAssertEqual(answer.rows.map(\.requestID), ["1"])
  }

  func testTheStoredListIsFilteredAndOldestFirst() async {
    backend.pendingReply = PendingReply(outcome: .unreachable, count: 0, appLock: false, requests: [])
    stored = snapshot(pending: [
      row("new", title: "B", minutesAgo: 1), row("other", profile: "work"),
      row("old", title: "A", minutesAgo: 30),
    ])

    let answer = await run(profile: "default")

    XCTAssertEqual(answer.rows.map(\.requestID), ["old", "new"])
  }

  func testAStoredListWrittenUnderAppLockGivesTheCountOnly() async {
    backend.pendingReply = PendingReply(outcome: .unreachable, count: 0, appLock: false, requests: [])
    stored = snapshot(
      pending: [row("1", title: ""), row("2", title: "")],
      updatedAt: date("2026-10-10T10:42:00Z"))

    let answer = await run()

    XCTAssertEqual(
      answer.text, "As of 10:42, 2 requests are waiting. Open Hermes to see them.")
    XCTAssertEqual(answer.rows, [])
  }

  func testNobodySignedInAndNothingStoredSaysSoForEachOutcome() async {
    let cases: [(RequestOutcome, String)] = [
      (.signedOut, "Sign in to Hermes first."),
      (.deviceLocked, "Unlock your iPhone first."),
      (.unreachable, "Can't reach your Hermes server."),
      (.unavailable, "Hermes isn't available right now."),
      (.failed, "Couldn't read your requests."),
    ]
    for (outcome, sentence) in cases {
      backend.pendingReply = PendingReply(outcome: outcome, count: 0, appLock: false, requests: [])
      stored = nil
      let withoutSnapshot = await run()
      XCTAssertEqual(withoutSnapshot.text, sentence, "\(outcome)")
      stored = snapshot(signedIn: false, pending: [row("1")])
      let signedOut = await run()
      XCTAssertEqual(signedOut.text, sentence, "\(outcome) signed out")
      XCTAssertEqual(signedOut.rows, [])
    }
  }

  func testAStoredEmptyListIsStillAnAnswer() async {
    backend.pendingReply = PendingReply(outcome: .unreachable, count: 0, appLock: false, requests: [])
    stored = snapshot(pending: [], updatedAt: date("2026-10-10T10:42:00Z"))
    let answer = await run()
    XCTAssertEqual(answer.text, "As of 10:42, nothing is waiting for you.")
  }
}

final class ApprovalAnswerFlowTests: XCTestCase {
  private var backend = FakeBackend()
  private var prompts: [ConfirmationPrompt] = []
  private var picked: [[ApprovalChoice]] = []

  private struct Declined: Error {}

  override func setUp() {
    backend = FakeBackend()
    prompts = []
    picked = []
    backend.detailReply = .found(
      ApprovalDetail(
        command: "rm -rf build", description: "Deletes the build folder",
        choices: ["deny", "once", "session"]))
  }

  private func run(
    _ request: PendingRequestEntity? = nil, choice: ApprovalChoice? = nil,
    pickReturns: ApprovalChoice? = .once, confirms: Bool = true
  ) async -> String {
    await ApprovalAnswerFlow(backend: backend).run(
      request: request ?? entity(), choice: choice,
      pick: { options in
        self.picked.append(options)
        guard let pickReturns else { throw Declined() }
        return pickReturns
      },
      confirm: { prompt in
        self.prompts.append(prompt)
        if !confirms { throw Declined() }
      })
  }

  func testConfirmsWithTheCommandThenAnswers() async {
    let said = await run(choice: .once)

    XCTAssertEqual(said, "Approved once.")
    XCTAssertEqual(prompts.count, 1)
    XCTAssertEqual(prompts[0].question, "Allow Hermes to run this once?")
    XCTAssertEqual(prompts[0].command, "rm -rf build")
    XCTAssertEqual(prompts[0].description, "Deletes the build folder")
    XCTAssertEqual(
      prompts[0].text, "Allow Hermes to run this once?\nrm -rf build\nDeletes the build folder")
    XCTAssertEqual(backend.calls, ["detail default/t-r1/r1", "answer r1 once"])
    XCTAssertEqual(picked.count, 0)
  }

  func testTheConfirmationNamesTheScopeOfTheChoice() async {
    _ = await run(choice: .session)
    XCTAssertEqual(prompts[0].question, "Allow Hermes to run this for this session?")
  }

  func testDeclinedSendsNothingAndIsRecorded() async {
    let said = await run(choice: .once, confirms: false)

    XCTAssertEqual(said, "Cancelled.")
    XCTAssertEqual(backend.calls, ["detail default/t-r1/r1", "cancelled once"])
  }

  func testDenyNeedsNoConfirmation() async {
    let said = await run(choice: .deny)

    XCTAssertEqual(said, "Denied.")
    XCTAssertEqual(prompts, [])
    XCTAssertEqual(backend.calls.last, "answer r1 deny")
  }

  func testAChoiceHermesDoesNotOfferEndsTheIntent() async {
    let said = await run(choice: .always)

    XCTAssertEqual(said, "Hermes doesn't offer Always for this request.")
    XCTAssertEqual(prompts, [])
    XCTAssertEqual(backend.calls, ["detail default/t-r1/r1"])
  }

  func testAMissingChoiceIsAskedAmongTheOfferedOnesInOrder() async {
    let said = await run(choice: nil, pickReturns: .session)

    XCTAssertEqual(picked, [[.once, .session, .deny]])
    XCTAssertEqual(said, "Approved for this session.")
    XCTAssertEqual(prompts.count, 1)
  }

  func testDecliningTheQuestionOfWhichChoiceCancels() async {
    let said = await run(choice: nil, pickReturns: nil)

    XCTAssertEqual(said, "Cancelled.")
    XCTAssertEqual(backend.calls, ["detail default/t-r1/r1"])
  }

  func testOneOfferedChoiceIsNotAskedFor() async {
    backend.detailReply = .found(ApprovalDetail(command: "ls", description: "", choices: ["once"]))

    let said = await run(choice: nil)

    XCTAssertEqual(picked, [])
    XCTAssertEqual(said, "Approved once.")
    XCTAssertEqual(prompts[0].text, "Allow Hermes to run this once?\nls")
  }

  func testNoKnownChoiceSendsNothing() async {
    backend.detailReply = .found(ApprovalDetail(command: "ls", description: "", choices: ["maybe"]))
    let said = await run(choice: .once)
    XCTAssertEqual(said, RequestSpeech.noChoice)
    XCTAssertEqual(backend.calls, ["detail default/t-r1/r1"])
  }

  func testAnExpiredRequestIsSaidToBeGoneAndNothingIsSent() async {
    backend.detailReply = .ended(.gone)

    let said = await run(choice: .once)

    XCTAssertEqual(said, "That request is no longer waiting.")
    XCTAssertEqual(prompts, [])
    XCTAssertEqual(backend.calls, ["detail default/t-r1/r1"])
  }

  func testARequestThatExpiresWhileConfirmingIsSaidToBeGone() async {
    backend.answerOutcome = .gone

    let said = await run(choice: .once)

    XCTAssertEqual(said, "That request is no longer waiting.")
    XCTAssertEqual(backend.calls.last, "answer r1 once")
  }

  func testEveryOutcomeBeforeTheAnswerSendsNothing() async {
    let cases: [(RequestOutcome, String)] = [
      (.signedOut, "Sign in to Hermes first."),
      (.deviceLocked, "Unlock your iPhone first."),
      (.unreachable, "Can't reach your Hermes server."),
      (.unavailable, "Hermes isn't available right now."),
      (.appLocked, "Open Hermes to answer this request."),
      (.gone, "That request is no longer waiting."),
    ]
    for (outcome, sentence) in cases {
      backend = FakeBackend()
      backend.detailReply = .ended(outcome)
      let said = await run(choice: .once)
      XCTAssertEqual(said, sentence, "\(outcome)")
      XCTAssertEqual(backend.calls, ["detail default/t-r1/r1"], "\(outcome)")
    }
  }

  func testEveryOutcomeOfTheAnswerIsSaid() async {
    let cases: [(RequestOutcome, String)] = [
      (.answered, "Approved once."),
      (.signedOut, "Sign in to Hermes first."),
      (.deviceLocked, "Unlock your iPhone first."),
      (.unreachable, "Can't reach your Hermes server."),
      (.unavailable, "Hermes isn't available right now."),
      (.appLocked, "Open Hermes to answer this request."),
      (.gone, "That request is no longer waiting."),
      (.failed, "Couldn't send your answer."),
    ]
    for (outcome, sentence) in cases {
      backend.answerOutcome = outcome
      let said = await run(choice: .once)
      XCTAssertEqual(said, sentence, "\(outcome)")
    }
  }

  func testOnlyApprovalsAreAnswered() async {
    let said = await run(entity("q", kind: .question), choice: .once)

    XCTAssertEqual(said, "Only approvals can be answered here.")
    XCTAssertEqual(backend.calls, [])
  }

  func testTheRequestIsAddressedByProfileThreadAndId() async {
    _ = await run(entity("r9", profile: "work"), choice: .deny)
    XCTAssertEqual(backend.calls, ["detail work/t-r9/r9", "answer r9 deny"])
  }
}

final class RequestReplyDecodingTests: XCTestCase {
  func testReadsAPendingReply() {
    let reply = PendingReply(json: [
      "outcome": "answered", "count": 2, "appLock": false,
      "requests": [
        [
          "profile": "work", "threadId": "t", "title": "Trip", "kind": "question",
          "requestId": "r", "createdAt": "2026-10-10T11:00:00Z",
        ],
        ["profile": "work"],
      ],
    ])
    XCTAssertEqual(reply.outcome, .answered)
    XCTAssertEqual(reply.count, 2)
    XCTAssertEqual(reply.requests.map(\.requestID), ["r"])
    XCTAssertEqual(reply.requests.first?.kind, .question)
    XCTAssertEqual(reply.requests.first?.createdAt, date("2026-10-10T11:00:00Z"))
  }

  func testNoAnswerOrAnUnknownOutcomeIsUnavailable() {
    XCTAssertEqual(PendingReply(json: nil), .unavailable)
    XCTAssertEqual(PendingReply(json: ["outcome": "sideways"]), .unavailable)
    XCTAssertEqual(PendingReply(json: ["count": 1]), .unavailable)
  }

  func testReadsADetailReply() {
    XCTAssertEqual(
      DetailReply(json: [
        "outcome": "found", "command": "ls", "description": "d", "choices": ["once", 3, "deny"],
      ]),
      .found(ApprovalDetail(command: "ls", description: "d", choices: ["once", "deny"])))
    XCTAssertEqual(DetailReply(json: ["outcome": "gone"]), .ended(.gone))
    XCTAssertEqual(DetailReply(json: ["outcome": "app_locked"]), .ended(.appLocked))
    XCTAssertEqual(DetailReply(json: ["outcome": "???"]), .ended(.failed))
    XCTAssertEqual(DetailReply(json: nil), .ended(.unavailable))
  }

  func testTheOutcomeWordsAreTheOnesDartSends() {
    XCTAssertEqual(RequestOutcome(rawValue: "signed_out"), .signedOut)
    XCTAssertEqual(RequestOutcome(rawValue: "device_locked"), .deviceLocked)
    XCTAssertEqual(RequestOutcome(rawValue: "app_locked"), .appLocked)
  }
}
