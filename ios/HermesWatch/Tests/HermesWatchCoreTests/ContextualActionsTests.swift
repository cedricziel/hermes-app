import XCTest
@testable import HermesWatchCore

final class ContextualActionsTests: XCTestCase {
  func testNewChatOffersEditableStarters() {
    XCTAssertEqual(WatchContextualActions.select(newChat: true, empty: true, successfulReply: false, idle: true, draft: "", voiceIdle: true, recording: false, pendingRequest: false, unresolvedDelivery: false), [.planDay, .explain])
    XCTAssertEqual(WatchContextualAction.planDay.draft, "Help me plan my day.")
    XCTAssertEqual(WatchContextualAction.explain.draft, "Help me understand this topic: ")
    XCTAssertNil(WatchContextualAction.planDay.followUp)
  }

  func testSuccessfulAnswerOffersOrdinaryFollowUps() {
    XCTAssertEqual(WatchContextualActions.select(newChat: false, empty: false, successfulReply: true, idle: true, draft: "", voiceIdle: true, recording: false, pendingRequest: false, unresolvedDelivery: false), [.continueReply, .summarize])
    XCTAssertEqual(WatchContextualAction.continueReply.followUp, "Continue")
    XCTAssertNil(WatchContextualAction.continueReply.draft)
  }

  func testDraftCannotBeOverwritten() {
    XCTAssertTrue(actions(draft: "my words").isEmpty)
    XCTAssertTrue(actions(voiceIdle: false).isEmpty)
  }

  func testPendingRequestAndUnresolvedDeliverySuppressOrdinaryActions() {
    XCTAssertTrue(actions(pendingRequest: true).isEmpty)
    XCTAssertTrue(actions(unresolvedDelivery: true).isEmpty)
    XCTAssertTrue(actions(idle: false).isEmpty)
    XCTAssertTrue(actions(recording: true).isEmpty)
  }

  func testExistingEmptyChatAndFailedTurnHaveNoFollowUps() {
    XCTAssertTrue(WatchContextualActions.select(newChat: false, empty: true, successfulReply: false, idle: true, draft: "", voiceIdle: true, recording: false, pendingRequest: false, unresolvedDelivery: false).isEmpty)
  }

  private func actions(idle: Bool = true, draft: String = "", voiceIdle: Bool = true,
    recording: Bool = false, pendingRequest: Bool = false, unresolvedDelivery: Bool = false) -> [WatchContextualAction] {
    WatchContextualActions.select(newChat: true, empty: true, successfulReply: false, idle: idle,
      draft: draft, voiceIdle: voiceIdle, recording: recording, pendingRequest: pendingRequest,
      unresolvedDelivery: unresolvedDelivery)
  }
}

@MainActor
final class ContextualActionActivationTests: XCTestCase {
  func testStarterFillsEditableDraftWithoutDispatching() async {
    let client = FakeClient()
    let model = ConversationModel(client: client, threadId: nil)
    var draft = ""
    await WatchContextualActions.activate(.explain, available: { [.explain] },
      fillDraft: { draft = $0 }, send: { await model.send($0) })
    XCTAssertEqual(draft, "Help me understand this topic: ")
    draft += "clouds"
    XCTAssertEqual(draft, "Help me understand this topic: clouds")
    XCTAssertTrue(client.sends.isEmpty)
    XCTAssertTrue(model.messages.isEmpty)
  }

  func testFollowUpUsesOrdinarySendAndThreadIdentity() async {
    let client = FakeClient()
    let threadId = watchFixtureId("s1")
    let model = ConversationModel(client: client, threadId: threadId)
    await model.load()
    var draft = ""
    await WatchContextualActions.activate(.continueReply, available: { [.continueReply] },
      fillDraft: { draft = $0 }, send: { await model.send($0) })
    XCTAssertEqual(client.sends.count, 1)
    XCTAssertEqual(client.sends.first?.threadId, threadId)
    XCTAssertEqual(client.sends.first?.text, "Continue")
    XCTAssertEqual(client.sends.first?.retry, false)
    XCTAssertFalse(client.sends.first?.sendId.isEmpty ?? true)
    XCTAssertEqual(model.messages.first?.id, "local-\(client.sends.first?.sendId ?? "")")
    XCTAssertEqual(draft, "")
  }

  func testStaleActivationCannotOverwriteDraftOrDispatch() async {
    let client = FakeClient()
    let model = ConversationModel(client: client, threadId: nil)
    var draft = "My newer words"
    for action in [WatchContextualAction.explain, .continueReply] {
      await WatchContextualActions.activate(action, available: { [] },
        fillDraft: { draft = $0 }, send: { await model.send($0) })
    }
    XCTAssertEqual(draft, "My newer words")
    XCTAssertTrue(client.sends.isEmpty)
    XCTAssertTrue(model.messages.isEmpty)
  }
}
