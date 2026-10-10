import XCTest

@testable import HermesWatchCore

final class FileChatCacheTests: XCTestCase {
  private var directory: URL!

  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: directory)
  }

  func testThreadsAndMessagesSurviveANewCache() {
    let thread = ThreadSummary(id: "w/s1", title: "Trip", updatedAt: Date(timeIntervalSince1970: 100), pinned: true)
    let message = ChatMessage(id: "m1", role: .assistant, content: "Hi", at: Date(timeIntervalSince1970: 5), tools: ["terminal"])
    let cache = FileChatCache(directory: directory)
    cache.save(threads: [thread])
    cache.save(messages: [message], threadId: "w/s1")

    let reopened = FileChatCache(directory: directory)

    XCTAssertEqual(reopened.threads(), [thread])
    XCTAssertEqual(reopened.messages(threadId: "w/s1"), [message])
  }

  func testNothingIsCachedAtFirst() {
    let cache = FileChatCache(directory: directory)

    XCTAssertNil(cache.threads())
    XCTAssertNil(cache.messages(threadId: "w/s1"))
  }

  func testMessagesOfChatsNoLongerListedAreDropped() {
    let cache = FileChatCache(directory: directory)
    cache.save(messages: [ChatMessage(id: "m1", role: .user, content: "Hi", at: .distantPast)], threadId: "w/old")
    cache.save(messages: [ChatMessage(id: "m2", role: .user, content: "Yo", at: .distantPast)], threadId: "w/s1")

    cache.save(threads: [ThreadSummary(id: "w/s1", title: "Kept", updatedAt: nil, pinned: false)])

    XCTAssertNil(cache.messages(threadId: "w/old"))
    XCTAssertNotNil(cache.messages(threadId: "w/s1"))
  }

  func testClearForgetsEverything() {
    let cache = FileChatCache(directory: directory)
    cache.save(threads: [ThreadSummary(id: "w/s1", title: "Trip", updatedAt: nil, pinned: false)])
    cache.save(messages: [ChatMessage(id: "m1", role: .user, content: "Hi", at: .distantPast)], threadId: "w/s1")

    cache.clear()

    XCTAssertNil(cache.threads())
    XCTAssertNil(cache.messages(threadId: "w/s1"))
  }
}

final class MemoryChatCache: ChatCache {
  var savedThreads: [ThreadSummary]?
  var savedMessages: [String: [ChatMessage]] = [:]

  func threads() -> [ThreadSummary]? { savedThreads }
  func save(threads: [ThreadSummary]) { savedThreads = threads }
  func messages(threadId: String) -> [ChatMessage]? { savedMessages[threadId] }
  func save(messages: [ChatMessage], threadId: String) { savedMessages[threadId] = messages }
  func clear() {
    savedThreads = nil
    savedMessages = [:]
  }
}

@MainActor
final class CachingClientTests: XCTestCase {
  private let thread = ThreadSummary(id: "w/s1", title: "Trip", updatedAt: nil, pinned: false)
  private var cache: MemoryChatCache!
  private var inner: FakeClient!
  private var client: CachingClient!

  override func setUp() async throws {
    cache = MemoryChatCache()
    inner = FakeClient()
    client = CachingClient(inner: inner, cache: cache)
  }

  func testAWaitingAnswerIsNotSavedAsATurn() async throws {
    inner.sendResult = .success(SendResult(threadId: "w/s1", text: "", failed: false, waiting: .approval))

    _ = try await client.send(threadId: "w/s1", text: "Clean up", sendId: "m1")

    XCTAssertNil(cache.savedMessages["w/s1"])
  }

  func testTheListIsSavedAndReplacedByThePhonesAnswer() async {
    cache.savedThreads = [thread]
    let fresh = ThreadSummary(id: "w/s2", title: "New", updatedAt: nil, pinned: false)
    inner.threadsResult = .success([fresh])
    let model = ThreadListModel(client: client)

    await model.load()

    XCTAssertEqual(model.state, .loaded([fresh]))
    XCTAssertEqual(cache.savedThreads, [fresh])
  }

  func testTheListKeepsSavedChatsWhenThePhoneCannotBeReached() async {
    cache.savedThreads = [thread]
    inner.threadsResult = .failure(HermesClientError.phoneUnreachable)
    let model = ThreadListModel(client: client)

    await model.load()

    XCTAssertEqual(model.state, .loaded([thread]))
    XCTAssertEqual(model.refreshFailure, .phoneUnreachable)
  }

  func testSigningOutOnThePhoneForgetsTheSavedChats() async {
    cache.savedThreads = [thread]
    cache.savedMessages = ["w/s1": [ChatMessage(id: "m1", role: .user, content: "Hi", at: .distantPast)]]
    inner.threadsResult = .failure(HermesClientError.signedOut)
    let model = ThreadListModel(client: client)

    await model.load()

    XCTAssertEqual(model.state, .failed(.signedOut))
    XCTAssertNil(cache.savedThreads)
    XCTAssertTrue(cache.savedMessages.isEmpty)
  }

  func testAChatKeepsSavedMessagesWhenThePhoneCannotBeReached() async {
    let saved = ChatMessage(id: "m1", role: .user, content: "Hi", at: .distantPast)
    cache.savedMessages = ["w/s1": [saved]]
    inner.messagesResult = .failure(HermesClientError.phoneUnreachable)
    let model = ConversationModel(client: client, threadId: "w/s1")

    await model.load()

    XCTAssertEqual(model.messages, [saved])
    XCTAssertEqual(model.phase, .failed(.phoneUnreachable))
  }

  func testLoadedMessagesAreSaved() async {
    let fresh = ChatMessage(id: "m2", role: .assistant, content: "Hello", at: .distantPast)
    inner.messagesResult = .success([fresh])
    let model = ConversationModel(client: client, threadId: "w/s1")

    await model.load()

    XCTAssertEqual(cache.savedMessages["w/s1"], [fresh])
  }

  func testASentMessageAndItsReplyAreSavedUnderTheNewThread() async {
    inner.sendResult = .success(SendResult(threadId: "w/new", text: "Hi there", failed: false))
    let model = ConversationModel(client: client, threadId: nil)

    await model.send("Hello")

    XCTAssertEqual(cache.savedMessages["w/new"]?.map(\.content), ["Hello", "Hi there"])
  }

  func testAFailedTurnIsNotSaved() async {
    inner.sendResult = .success(SendResult(threadId: "w/new", text: "Model unavailable", failed: true))
    let model = ConversationModel(client: client, threadId: nil)

    await model.send("Hello")

    XCTAssertNil(cache.savedMessages["w/new"])
  }
}
