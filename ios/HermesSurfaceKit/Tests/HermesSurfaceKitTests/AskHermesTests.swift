import AppIntents
import XCTest

@testable import HermesSurfaceKit

/// A service the test drives: it answers when told, and records what it was
/// asked.
private final class FakeService: AskHermesService, @unchecked Sendable {
  struct Call: Equatable {
    var question: String
    var profile: String?
    var chatID: String?
  }

  private let lock = NSLock()
  private var _calls: [Call] = []
  private var _opened: [URL] = []
  var reply: @Sendable () async -> AskAnswer = { AskAnswer(.answered, text: "Hi") }

  var calls: [Call] { lock.withLock { _calls } }
  var opened: [URL] { lock.withLock { _opened } }

  func ask(
    question: String, profile: String?, chatID: String?, deadline: ContinuousClock.Instant
  ) async -> AskAnswer {
    lock.withLock { _calls.append(Call(question: question, profile: profile, chatID: chatID)) }
    return await reply()
  }

  func open(_ url: URL) async {
    lock.withLock { _opened.append(url) }
  }
}

final class AskAnswerTests: XCTestCase {
  func testEachOutcomeIsSaidInItsOwnWords() {
    let words: [AskOutcome: String] = [
      .stillWorking: "Still working — I'll notify you.",
      .needsYou: "Hermes needs your answer. Open the chat in Hermes.",
      .failed: "Hermes couldn't answer.",
      .signedOut: "Sign in to Hermes first.",
      .deviceLocked: "Unlock your iPhone first.",
      .unreachable: "Can't reach your Hermes server.",
      .unavailable: "Hermes isn't available right now. Open Hermes to check.",
      .appLocked: "Continue in Hermes to ask.",
    ]
    for outcome in AskOutcome.allCases where outcome != .answered {
      let answer = AskAnswer(outcome, text: "ignored reply text")
      XCTAssertEqual(answer.spoken, words[outcome], "\(outcome)")
      XCTAssertEqual(answer.output, words[outcome], "\(outcome)")
    }
  }

  func testAnAnsweredQuestionSpeaksPlainTextAndOutputsTheMarkdown() {
    let answer = AskAnswer(.answered, text: "**Three** tickets are open.")
    XCTAssertEqual(answer.spoken, "Three tickets are open.")
    XCTAssertEqual(answer.output, "**Three** tickets are open.")
  }

  func testTheChannelReplyIsParsed() {
    XCTAssertEqual(
      AskAnswer(channelReply: ["outcome": "answered", "text": "Hi"]),
      AskAnswer(.answered, text: "Hi"))
    XCTAssertEqual(
      AskAnswer(channelReply: ["outcome": "still_working"]), AskAnswer(.stillWorking))
    XCTAssertEqual(
      AskAnswer(channelReply: ["outcome": "device_locked", "text": "nope"]),
      AskAnswer(.deviceLocked))
  }

  func testAnythingElseFromTheChannelIsAFailure() {
    XCTAssertEqual(AskAnswer(channelReply: nil), AskAnswer(.failed))
    XCTAssertEqual(AskAnswer(channelReply: "text"), AskAnswer(.failed))
    XCTAssertEqual(AskAnswer(channelReply: ["outcome": "surprise"]), AskAnswer(.failed))
  }
}

final class SpokenTextTests: XCTestCase {
  func testBoldItalicAndCodeLoseTheirMarks() {
    XCTAssertEqual(SpokenText.plain("**Three** *open* __tickets__ and `ls`"), "Three open tickets and ls")
  }

  func testHeadingsBulletsAndQuotesLoseTheirMarks() {
    let markdown = "# Plan\n\n- one\n* two\n+ three\n\n> noted"
    XCTAssertEqual(SpokenText.plain(markdown), "Plan\n\none\ntwo\nthree\n\nnoted")
  }

  func testLinksSayTheirTextNotTheirTarget() {
    XCTAssertEqual(
      SpokenText.plain("See [the docs](https://example.com/a?b=c) and ![chart](x.png)."),
      "See the docs and chart.")
  }

  func testACodeBlockKeepsItsCodeWithoutTheFences() {
    XCTAssertEqual(SpokenText.plain("Run:\n```sh\nls -la\n```\nDone"), "Run:\nls -la\nDone")
  }

  func testNumbersAndMathAreLeftAlone() {
    XCTAssertEqual(SpokenText.plain("2*3*4 = 24, snake_case_name, 5 - 3"), "2*3*4 = 24, snake_case_name, 5 - 3")
    XCTAssertEqual(SpokenText.plain("1. first\n2. second"), "1. first\n2. second")
  }

  func testBlankRunsCollapse() {
    XCTAssertEqual(SpokenText.plain("a\n\n\n\n\nb\n"), "a\n\nb")
  }
}

final class AskWindowTests: XCTestCase {
  func testTheWindowIsTwentyFiveSeconds() {
    XCTAssertEqual(AskHermes.window, .seconds(25))
  }

  func testAnAnswerInTimeIsReturnedAsIs() async {
    let service = FakeService()
    let answer = await AskHermes.answer(
      question: "q", profile: "work", chatID: nil,
      deadline: .now + .seconds(5), service: service)
    XCTAssertEqual(answer, AskAnswer(.answered, text: "Hi"))
    XCTAssertEqual(service.calls, [.init(question: "q", profile: "work", chatID: nil)])
  }

  func testAnAnswerAfterTheDeadlineIsStillWorkingAndTheAskGoesOn() async throws {
    let service = FakeService()
    let release = AsyncGate()
    let finished = AsyncGate()
    service.reply = {
      await release.wait()
      await finished.open()
      return AskAnswer(.answered, text: "late")
    }

    let answer = await AskHermes.answer(
      question: "q", profile: nil, chatID: nil,
      deadline: .now + .milliseconds(30), service: service)

    XCTAssertEqual(answer, AskAnswer(.stillWorking))
    // The ask was not cancelled: it still runs to its end.
    await release.open()
    await finished.wait()
  }

  func testWithoutAServiceTheAnswerIsUnavailable() async {
    let answer = await AskHermes.answer(
      question: "q", profile: nil, chatID: nil, deadline: .now + .seconds(1), service: nil)
    XCTAssertEqual(answer, AskAnswer(.unavailable))
  }

  func testAPastDeadlineAnswersStillWorkingAtOnce() async {
    let service = FakeService()
    service.reply = {
      try? await Task.sleep(for: .seconds(5))
      return AskAnswer(.answered, text: "never heard")
    }
    let answer = await AskHermes.answer(
      question: "q", profile: nil, chatID: nil, deadline: .now - .seconds(1), service: service)
    XCTAssertEqual(answer, AskAnswer(.stillWorking))
  }

  func testEveryOutcomeOfTheServiceReachesTheCaller() async {
    for outcome in AskOutcome.allCases where outcome != .stillWorking {
      let service = FakeService()
      service.reply = { AskAnswer(outcome) }
      let answer = await AskHermes.answer(
        question: "q", profile: nil, chatID: nil, deadline: .now + .seconds(5), service: service)
      XCTAssertEqual(answer.outcome, outcome)
    }
  }
}

final class AskHermesIntentTests: XCTestCase {
  private func directory(profile: String? = "default") -> IntentDirectory {
    IntentDirectory(
      snapshot: SurfaceSnapshot(
        updatedAt: Date(), signedIn: true, profile: profile, profiles: [], recentChats: [],
        pending: [], kanban: nil, schedules: nil))
  }

  func testANewChatGoesToTheGivenProfileElseTheCurrentOne() {
    let intent = AskHermesIntent()
    XCTAssertEqual(intent.target(in: directory(profile: "work")).profile, "work")
    XCTAssertNil(intent.target(in: directory(profile: "work")).chatID)
    intent.profile = ProfileEntity(id: "play")
    XCTAssertEqual(intent.target(in: directory(profile: "work")).profile, "play")
    XCTAssertNil(AskHermesIntent().target(in: IntentDirectory(snapshot: nil)).profile)
  }

  func testAChatIsContinuedInItsOwnProfile() {
    let intent = AskHermesIntent()
    intent.profile = ProfileEntity(id: "play")
    intent.chat = ChatEntity(profile: "work", threadID: "abc", title: "Trip plan")
    let target = intent.target(in: directory(profile: "default"))
    XCTAssertEqual(target.profile, "work")
    XCTAssertEqual(target.chatID, "work/abc")
  }

  func testTheHandOverIsANewChatWithTheQuestionUnsent() {
    XCTAssertEqual(
      AskHermes.handOverLink(profile: "work", question: "What's C++ & more?").absoluteString,
      "hermes://new?profile=work&prompt=What's%20C%2B%2B%20%26%20more%3F")
    XCTAssertEqual(
      AskHermes.handOverLink(profile: nil, question: "Hi").absoluteString,
      "hermes://new?prompt=Hi")
  }

  func testTheIntentRunsWhileLockedAndOffersTheForeground() {
    XCTAssertEqual(
      String(describing: AskHermesIntent.authenticationPolicy),
      String(describing: IntentAuthenticationPolicy.alwaysAllowed))
    XCTAssertTrue(AskHermesIntent.supportedModes.contains(.background))
    XCTAssertTrue(AskHermesIntent.supportedModes.contains(.foreground(.dynamic)))
  }
}

/// A door a test opens by hand.
private actor AsyncGate {
  private var isOpen = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func wait() async {
    if isOpen { return }
    await withCheckedContinuation { waiters.append($0) }
  }

  func open() {
    isOpen = true
    waiters.forEach { $0.resume() }
    waiters = []
  }
}
