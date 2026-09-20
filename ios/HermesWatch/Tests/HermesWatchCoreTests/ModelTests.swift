import XCTest

@testable import HermesWatchCore

final class FakeClient: HermesClient {
  var threadsResult: Result<[ThreadSummary], Error> = .success([])
  var messagesResult: Result<[ChatMessage], Error> = .success([])
  var sendResult: Result<SendResult, Error> = .success(SendResult(threadId: nil, text: "ok", failed: false))
  private(set) var sends: [(threadId: String?, text: String)] = []

  func threads() async throws -> [ThreadSummary] { try threadsResult.get() }
  func messages(threadId: String) async throws -> [ChatMessage] { try messagesResult.get() }
  func send(threadId: String?, text: String) async throws -> SendResult {
    sends.append((threadId, text))
    return try sendResult.get()
  }
}

@MainActor
final class ThreadListModelTests: XCTestCase {
  func testLoadsThreads() async {
    let client = FakeClient()
    let thread = ThreadSummary(id: "s1", title: "Groceries", updatedAt: .distantPast, pinned: false)
    client.threadsResult = .success([thread])
    let model = ThreadListModel(client: client)
    XCTAssertEqual(model.state, .loading)

    await model.load()

    XCTAssertEqual(model.state, .loaded([thread]))
  }

  func testReportsWhyLoadingFailed() async {
    let client = FakeClient()
    client.threadsResult = .failure(HermesClientError.phoneUnreachable)
    let model = ThreadListModel(client: client)

    await model.load()

    XCTAssertEqual(model.state, .failed(.phoneUnreachable))
  }
}

@MainActor
final class ConversationModelTests: XCTestCase {
  func testAnExistingThreadLoadsItsMessages() async {
    let client = FakeClient()
    let message = ChatMessage(id: "s1-1", role: .user, content: "Hi", at: .distantPast)
    client.messagesResult = .success([message])
    let model = ConversationModel(client: client, threadId: "s1")
    XCTAssertEqual(model.phase, .loading)

    await model.load()

    XCTAssertEqual(model.messages, [message])
    XCTAssertEqual(model.phase, .idle)
  }

  func testANewThreadStartsEmptyAndIdle() {
    let model = ConversationModel(client: FakeClient(), threadId: nil)

    XCTAssertEqual(model.phase, .idle)
    XCTAssertTrue(model.messages.isEmpty)
  }

  func testSendingAppendsTheMessageAndTheReplyAndBindsTheThread() async {
    let client = FakeClient()
    client.sendResult = .success(SendResult(threadId: "new-1", text: "Hi there", failed: false))
    let model = ConversationModel(client: client, threadId: nil)

    await model.send("  Hello  ")

    XCTAssertEqual(client.sends.first?.text, "Hello")
    XCTAssertNil(client.sends.first?.threadId)
    XCTAssertEqual(model.messages.map(\.role), [.user, .assistant])
    XCTAssertEqual(model.messages.map(\.content), ["Hello", "Hi there"])
    XCTAssertEqual(model.threadId, "new-1")
    XCTAssertEqual(model.phase, .idle)

    await model.send("More")
    XCTAssertEqual(client.sends.last?.threadId, "new-1")
  }

  func testABlankMessageIsNotSent() async {
    let client = FakeClient()
    let model = ConversationModel(client: client, threadId: "s1")

    await model.send("   ")

    XCTAssertTrue(client.sends.isEmpty)
    XCTAssertTrue(model.messages.isEmpty)
  }

  func testAFailedSendKeepsTheTextToTryAgain() async {
    let client = FakeClient()
    client.sendResult = .failure(HermesClientError.phoneUnreachable)
    let model = ConversationModel(client: client, threadId: "s1")
    await model.load()

    await model.send("Hello")

    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertEqual(model.unsent, "Hello")
    XCTAssertEqual(model.phase, .failed(.phoneUnreachable))
  }

  func testNothingIsSentWhileTheThreadIsStillLoading() async {
    let client = FakeClient()
    let model = ConversationModel(client: client, threadId: "s1")
    XCTAssertEqual(model.phase, .loading)

    await model.send("Hello")

    XCTAssertTrue(client.sends.isEmpty)
    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertEqual(model.phase, .loading)
  }

  func testAFailedTurnKeepsTheTextAndStillBindsTheThread() async {
    let client = FakeClient()
    client.sendResult = .success(SendResult(threadId: "new-1", text: "Model unavailable", failed: true))
    let model = ConversationModel(client: client, threadId: nil)

    await model.send("Hello")

    XCTAssertTrue(model.messages.isEmpty)
    XCTAssertEqual(model.unsent, "Hello")
    XCTAssertEqual(model.phase, .failed(.failed))
    XCTAssertEqual(model.threadId, "new-1")

    client.sendResult = .success(SendResult(threadId: "new-1", text: "Hi", failed: false))
    await model.send("Hello")
    XCTAssertEqual(client.sends.last?.threadId, "new-1")
    XCTAssertEqual(model.phase, .idle)
  }

  func testSendingAgainClearsTheFailure() async {
    let client = FakeClient()
    client.sendResult = .failure(HermesClientError.unavailable)
    let model = ConversationModel(client: client, threadId: "s1")
    await model.load()
    await model.send("Hello")
    client.sendResult = .success(SendResult(threadId: "s1", text: "Hi", failed: false))

    await model.send("Hello")

    XCTAssertNil(model.unsent)
    XCTAssertEqual(model.phase, .idle)
    XCTAssertEqual(model.messages.map(\.content), ["Hello", "Hi"])
  }
}
