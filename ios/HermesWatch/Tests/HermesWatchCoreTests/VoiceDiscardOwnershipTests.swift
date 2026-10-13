import XCTest
@testable import HermesWatchCore

@MainActor
final class VoiceDiscardOwnershipTests: XCTestCase {
  func testDiscardDuringResultCheckKeepsDeliveryBusyAndOwned() async throws {
    let client = FakeClient()
    try client.recoveryStore.save(PendingSendRecord(sendId: "pending", contextId: "test-context", revision: 1,
      profile: nil, threadId: nil, text: "existing request", localMessageId: "local", createdAt: Date(), recoveryState: .notSent))
    let model = ConversationModel(client: client, threadId: nil)
    await model.load()
    client.transcribeResult = .success("draft")
    await model.sendVoice(Data([1]), mimeType: "audio/mp4")
    let started = expectation(description: "result check suspended")
    var reply: CheckedContinuation<SendResult, Never>?
    client.sendHandler = {
      await withCheckedContinuation { continuation in reply = continuation; started.fulfill() }
    }
    let check = Task { await model.checkResult() }
    await fulfillment(of: [started], timeout: 1)
    let sendId = model.recovery?.sendId
    model.discardVoice()
    await model.send("parallel request")
    XCTAssertEqual(model.phase, .sending)
    XCTAssertTrue(model.busy)
    XCTAssertEqual(model.recovery?.sendId, sendId)
    XCTAssertEqual(client.sends.count, 1)
    reply?.resume(returning: SendResult(threadId: nil, text: "done", failed: false))
    await check.value
    XCTAssertEqual(model.phase, .idle)
    XCTAssertNil(model.recovery)
    XCTAssertEqual(model.messages.last?.content, "done")
  }

  func testDiscardWhileWaitingDoesNotEnableAnotherSend() async throws {
    let client = FakeClient()
    try client.recoveryStore.save(PendingSendRecord(sendId: "pending", contextId: "test-context", revision: 1,
      profile: nil, threadId: nil, text: "existing request", localMessageId: "local", createdAt: Date(), recoveryState: .notSent))
    let model = ConversationModel(client: client, threadId: nil)
    await model.load()
    client.transcribeResult = .success("draft")
    await model.sendVoice(Data([1]), mimeType: "audio/mp4")
    client.sendResults = [.success(SendResult(threadId: nil, text: "", failed: false, waiting: .question))]
    let started = expectation(description: "waiting poll suspended")
    var reply: CheckedContinuation<SendResult, Never>?
    client.sendHandler = {
      await withCheckedContinuation { continuation in reply = continuation; started.fulfill() }
    }
    let check = Task { await model.checkResult() }
    await fulfillment(of: [started], timeout: 1)
    model.discardVoice()
    await model.send("parallel request")
    XCTAssertEqual(model.phase, .waiting(.question))
    XCTAssertTrue(model.busy)
    XCTAssertEqual(client.sends.count, 2)
    reply?.resume(returning: SendResult(threadId: nil, text: "done", failed: false))
    await check.value
    XCTAssertEqual(model.messages.last?.content, "done")
  }

  func testDiscardResetsVoiceOwnedFailure() async {
    let client = FakeClient()
    client.transcribeResult = .failure(HermesClientError.phoneUnreachable)
    let model = ConversationModel(client: client, threadId: nil)
    await model.sendVoice(Data([1]), mimeType: "audio/mp4")
    model.discardVoice()
    XCTAssertEqual(model.phase, .idle)
    XCTAssertEqual(model.voice.state, .idle)
    XCTAssertNil(model.unsentVoice)
  }

  func testDiscardPreservesAnotherOperationsIdenticalFailure() async {
    let client = FakeClient()
    let model = ConversationModel(client: client, threadId: "s1")
    await model.load()
    client.transcribeResult = .failure(HermesClientError.phoneUnreachable)
    await model.sendVoice(Data([1]), mimeType: "audio/mp4")
    client.messagesResult = .failure(HermesClientError.phoneUnreachable)
    await model.load()
    model.discardVoice()
    XCTAssertEqual(model.phase, .failed(.phoneUnreachable))
    XCTAssertEqual(model.voice.state, .idle)
  }
  func testRetryDuringResultCheckPreservesFailedDraftAndDelivery() async throws {
    let client = FakeClient()
    try client.recoveryStore.save(PendingSendRecord(sendId: "pending", contextId: "test-context", revision: 1,
      profile: nil, threadId: nil, text: "existing request", localMessageId: "local", createdAt: Date(), recoveryState: .notSent))
    let model = ConversationModel(client: client, threadId: nil)
    await model.load()
    client.transcribeResult = .failure(HermesClientError.phoneUnreachable)
    await model.sendVoice(Data([1]), mimeType: "audio/mp4")
    let started = expectation(description: "result check suspended")
    var reply: CheckedContinuation<SendResult, Never>?
    client.sendHandler = {
      await withCheckedContinuation { continuation in reply = continuation; started.fulfill() }
    }
    let check = Task { await model.checkResult() }
    await fulfillment(of: [started], timeout: 1)
    await model.retryVoice()
    XCTAssertEqual(model.phase, .sending)
    XCTAssertTrue(model.busy)
    XCTAssertEqual(model.voice.state, .failed)
    XCTAssertEqual(model.unsentVoice, Data([1]))
    XCTAssertEqual(client.transcribed.count, 1)
    XCTAssertEqual(client.sends.count, 1)
    reply?.resume(returning: SendResult(threadId: nil, text: "done", failed: false))
    await check.value
    XCTAssertEqual(model.messages.last?.content, "done")
  }

  func testRetryWhileWaitingPreservesFailedDraftAndDelivery() async throws {
    let client = FakeClient()
    try client.recoveryStore.save(PendingSendRecord(sendId: "pending", contextId: "test-context", revision: 1,
      profile: nil, threadId: nil, text: "existing request", localMessageId: "local", createdAt: Date(), recoveryState: .notSent))
    let model = ConversationModel(client: client, threadId: nil)
    await model.load()
    client.transcribeResult = .failure(HermesClientError.phoneUnreachable)
    await model.sendVoice(Data([1]), mimeType: "audio/mp4")
    client.sendResults = [.success(SendResult(threadId: nil, text: "", failed: false, waiting: .question))]
    let started = expectation(description: "waiting poll suspended")
    var reply: CheckedContinuation<SendResult, Never>?
    client.sendHandler = {
      await withCheckedContinuation { continuation in reply = continuation; started.fulfill() }
    }
    let check = Task { await model.checkResult() }
    await fulfillment(of: [started], timeout: 1)
    await model.retryVoice()
    XCTAssertEqual(model.phase, .waiting(.question))
    XCTAssertTrue(model.busy)
    XCTAssertEqual(model.voice.state, .failed)
    XCTAssertEqual(model.unsentVoice, Data([1]))
    XCTAssertEqual(client.transcribed.count, 1)
    XCTAssertEqual(client.sends.count, 2)
    reply?.resume(returning: SendResult(threadId: nil, text: "done", failed: false))
    await check.value
    XCTAssertEqual(model.messages.last?.content, "done")
  }

  func testReviewedDraftSurvivesPendingRecoveryBlockingSend() async throws {
    let client = FakeClient()
    try client.recoveryStore.save(PendingSendRecord(sendId: "pending", contextId: "test-context", revision: 1,
      profile: nil, threadId: nil, text: "existing request", localMessageId: "local", createdAt: Date(), recoveryState: .pending))
    let model = ConversationModel(client: client, threadId: nil)
    await model.load()
    client.transcribeResult = .success("reviewed draft")
    await model.sendVoice(Data([1]), mimeType: "audio/mp4")
    await model.sendVoiceDraft()
    XCTAssertFalse(model.canCompose)
    XCTAssertTrue(client.sends.isEmpty)
    XCTAssertEqual(model.voice.state, .review)
    XCTAssertEqual(model.voiceText, "reviewed draft")
    XCTAssertEqual(model.unsentVoice, Data([1]))
    await model.forgetRecovery()
    await model.sendVoiceDraft()
    XCTAssertEqual(client.sends.map(\.text), ["reviewed draft"])
    XCTAssertEqual(model.voice.state, .idle)
    XCTAssertNil(model.unsentVoice)
  }

  func testFastSendFallsBackToReviewWhenPendingRecoveryBlocksSend() async throws {
    let client = FakeClient()
    try client.recoveryStore.save(PendingSendRecord(sendId: "pending", contextId: "test-context", revision: 1,
      profile: nil, threadId: nil, text: "existing request", localMessageId: "local", createdAt: Date(), recoveryState: .pending))
    let model = ConversationModel(client: client, threadId: nil)
    await model.load()
    client.transcribeResult = .success("fast draft")
    await model.sendVoice(Data([2]), mimeType: "audio/mp4", reason: .manual, fastSend: true)
    XCTAssertTrue(client.sends.isEmpty)
    XCTAssertEqual(model.voice.state, .review)
    XCTAssertEqual(model.voiceText, "fast draft")
    XCTAssertEqual(model.unsentVoice, Data([2]))
    await model.forgetRecovery()
    await model.sendVoiceDraft()
    XCTAssertEqual(client.sends.map(\.text), ["fast draft"])
  }

}
