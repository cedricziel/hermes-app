import XCTest
@testable import HermesWatchCore

final class VoiceDraftTests: XCTestCase {
  func testDefaultTranscriptWaitsForReviewAndEditedSendIsTrimmed() {
    var draft = VoiceDraft()
    let attempt = draft.start(audio: Data([1]), mimeType: "audio/mp4", reason: .manual, fastSend: false)
    XCTAssertNil(draft.complete("delete folder", attempt: attempt))
    draft.text = "  keep folder  "
    XCTAssertEqual(draft.takeText(), "keep folder")
    XCTAssertEqual(draft.state, .idle)
  }

  func testManualFastSendReturnsTranscriptOnce() {
    var draft = VoiceDraft()
    let attempt = draft.start(audio: Data([1]), mimeType: "audio/mp4", reason: .manual, fastSend: true)
    XCTAssertEqual(draft.complete(" continue ", attempt: attempt), "continue")
    XCTAssertNil(draft.complete("continue", attempt: attempt))
  }

  func testCappedAndInterruptedRecordingsAlwaysRequireReview() {
    var capped = VoiceDraft()
    let cap = capped.start(audio: Data([1]), mimeType: "audio/mp4", reason: .durationLimit, fastSend: true)
    XCTAssertNil(capped.complete("continue", attempt: cap))
    XCTAssertEqual(capped.state, .review)
    var interrupted = VoiceDraft()
    let interruption = interrupted.start(audio: Data([2]), mimeType: "audio/mp4", reason: .interruption, fastSend: true)
    XCTAssertNil(interrupted.complete("continue", attempt: interruption))
    XCTAssertEqual(interrupted.state, .review)
  }

  func testEmptySpeechReleasesAudioAndOffersRecordingAgain() {
    var draft = VoiceDraft()
    let attempt = draft.start(audio: Data([1]), mimeType: "audio/mp4", reason: .manual, fastSend: true)
    XCTAssertNil(draft.complete(" \n", attempt: attempt))
    XCTAssertEqual(draft.state, .noSpeech)
    XCTAssertNil(draft.audio)
  }

  func testDiscardIgnoresLateTranscriptAndClearsSensitiveData() {
    var draft = VoiceDraft()
    let attempt = draft.start(audio: Data([1]), mimeType: "audio/mp4", reason: .manual, fastSend: true)
    draft.discard()
    XCTAssertNil(draft.complete("delete folder", attempt: attempt))
    XCTAssertEqual(draft.state, .idle)
    XCTAssertEqual(draft.text, "")
    XCTAssertNil(draft.audio)
  }

  func testFailedTranscriptionKeepsAudioForRetryWithoutFastSend() {
    var draft = VoiceDraft()
    let attempt = draft.start(audio: Data([1]), mimeType: "audio/mp4", reason: .manual, fastSend: true)
    draft.fail(attempt: attempt)
    XCTAssertEqual(draft.state, .failed)
    XCTAssertEqual(draft.audio, Data([1]))
    let retry = draft.retry()!
    XCTAssertNil(draft.complete("continue", attempt: retry))
    XCTAssertEqual(draft.state, .review)
  }

  func testStopAtDurationBoundaryReviewsBeforeCompletionCallback() {
    let reason = VoiceTerminationReason.classifyStop(reported: .manual, isRecording: true,
      elapsed: 30, durationLimit: 30)
    var draft = VoiceDraft()
    let attempt = draft.start(audio: Data([1]), mimeType: "audio/mp4", reason: reason, fastSend: true)
    XCTAssertEqual(reason, .durationLimit)
    XCTAssertNil(draft.complete("continue", attempt: attempt))
    XCTAssertEqual(draft.state, .review)
  }

  func testNaturalStopBeforeCompletionCallbackAlwaysReviews() {
    let reason = VoiceTerminationReason.classifyStop(reported: .manual, isRecording: false,
      elapsed: 0, durationLimit: 30)
    var draft = VoiceDraft()
    let attempt = draft.start(audio: Data([1]), mimeType: "audio/mp4", reason: reason, fastSend: true)
    XCTAssertEqual(reason, .automatic)
    XCTAssertNil(draft.complete("continue", attempt: attempt))
    XCTAssertEqual(draft.state, .review)
  }

  func testActiveRecordingBeforeCapAllowsManualFastSend() {
    let reason = VoiceTerminationReason.classifyStop(reported: .manual, isRecording: true,
      elapsed: 29.99, durationLimit: 30)
    XCTAssertEqual(reason, .manual)
  }

  func testInterruptionReasonSurvivesStopClassification() {
    let reason = VoiceTerminationReason.classifyStop(reported: .interruption, isRecording: false,
      elapsed: 30, durationLimit: 30)
    XCTAssertEqual(reason, .interruption)
  }
}
