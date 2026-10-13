import XCTest
@testable import HermesWatchCore

final class ConversationPresentationTests: XCTestCase {
  func testUnsentEditNeverReplacesAnExistingComposerDraft() {
    XCTAssertFalse(ConversationPresentation.canRestoreUnsentDraft(composer: "New draft", handoffInProgress: false))
    XCTAssertFalse(ConversationPresentation.canRestoreUnsentDraft(composer: " ", handoffInProgress: false))
    XCTAssertTrue(ConversationPresentation.canRestoreUnsentDraft(composer: "", handoffInProgress: false))
    XCTAssertFalse(ConversationPresentation.canRestoreUnsentDraft(composer: "", handoffInProgress: true))
  }
  func testHistoryWithoutTurnCompletionDoesNotAnnounceReply() {
    var reading = ConversationReadingPosition()
    reading.setFollowing(false)
    XCTAssertNil(reading.completedReply(id: nil, preservingFocus: false))
    XCTAssertNil(reading.newReplyId)
  }

  func testSameCompletedTurnIsNotAnnouncedAgainAfterHistoryReload() {
    var reading = ConversationReadingPosition()
    reading.setFollowing(false)
    XCTAssertNil(reading.completedReply(id: "turn-answer", preservingFocus: false))
    XCTAssertEqual(reading.revealReply(), "turn-answer")
    XCTAssertNil(reading.completedReply(id: "turn-answer", preservingFocus: false))
    XCTAssertNil(reading.newReplyId)
  }
  func testHistoryReaderGetsNewReplyWithoutMoving() {
    var reading = ConversationReadingPosition()
    reading.setFollowing(false)
    XCTAssertNil(reading.replyArrived(id: "answer", preservingFocus: false))
    XCTAssertEqual(reading.newReplyId, "answer")
    XCTAssertEqual(reading.revealReply(), "answer")
    XCTAssertNil(reading.newReplyId)
  }

  func testFollowedTurnRevealsAnswerStart() {
    var reading = ConversationReadingPosition()
    XCTAssertEqual(reading.replyArrived(id: "answer", preservingFocus: false), "answer")
    XCTAssertNil(reading.newReplyId)
  }

  func testVoiceOverAndEditingPreserveFocusEvenWhileFollowing() {
    var reading = ConversationReadingPosition()
    XCTAssertNil(reading.replyArrived(id: "answer", preservingFocus: true))
    XCTAssertEqual(reading.newReplyId, "answer")
  }

  func testSpeakersPrecedeContent() {
    XCTAssertEqual(ConversationPresentation.messageLabel(role: .user, content: "Hello"), "You: Hello")
    XCTAssertEqual(ConversationPresentation.messageLabel(role: .assistant, content: "Hi"), "Hermes: Hi")
  }

  func testDeliveryStatesExplainAcceptanceWithoutColor() {
    XCTAssertEqual(ConversationPresentation.deliveryLabel(.notSent), "Not sent")
    XCTAssertEqual(ConversationPresentation.deliveryLabel(.uncertain), "Delivery unconfirmed")
    XCTAssertEqual(ConversationPresentation.deliveryLabel(.pending), "Delivery unconfirmed")
    XCTAssertEqual(ConversationPresentation.deliveryLabel(.pending, evidence: .submitting), "Sending, awaiting confirmation")
    XCTAssertEqual(ConversationPresentation.deliveryLabel(.pending, evidence: .accepted), "Accepted, awaiting reply")
  }
}
