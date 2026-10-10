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

    cache.save(threads: [ThreadSummary(id: "w/s1", title: "Kept", updatedAt: .distantPast, pinned: false)])

    XCTAssertNil(cache.messages(threadId: "w/old"))
    XCTAssertNotNil(cache.messages(threadId: "w/s1"))
  }

  func testClearForgetsEverything() {
    let cache = FileChatCache(directory: directory)
    cache.save(threads: [ThreadSummary(id: "w/s1", title: "Trip", updatedAt: .distantPast, pinned: false)])
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
final class CachedModelTests: XCTestCase {
  private let thread = ThreadSummary(id: "w/s1", title: "Trip", updatedAt: .distantPast, pinned: false)

  func testTheListShowsSavedChatsBeforeThePhoneAnswers() async {
    let cache = MemoryChatCache()
    cache.savedThreads = [thread]
    let client = FakeClient()
    let fresh = ThreadSummary(id: "w/s2", title: "New", updatedAt: .distantPast, pinned: false)
    client.threadsResult = .success([fresh])

    let model = ThreadListModel(client: client, cache: cache)
    XCTAssertEqual(model.state, .loaded([thread]))

    await model.load()
    XCTAssertEqual(model.state, .loaded([fresh]))
    XCTAssertEqual(cache.savedThreads, [fresh])
  }

  func testTheListKeepsSavedChatsWhenThePhoneCannotBeReached() async {
    let cache = MemoryChatCache()
    cache.savedThreads = [thread]
    let client = FakeClient()
    client.threadsResult = .failure(HermesClientError.phoneUnreachable)
    let model = ThreadListModel(client: client, cache: cache)

    await model.load()

    XCTAssertEqual(model.state, .loaded([thread]))
    XCTAssertEqual(model.refreshFailure, .phoneUnreachable)
  }

  func testSigningOutOnThePhoneForgetsTheSavedChats() async {
    let cache = MemoryChatCache()
    cache.savedThreads = [thread]
    cache.savedMessages = ["w/s1": [ChatMessage(id: "m1", role: .user, content: "Hi", at: .distantPast)]]
    let client = FakeClient()
    client.threadsResult = .failure(HermesClientError.signedOut)
    let model = ThreadListModel(client: client, cache: cache)

    await model.load()

    XCTAssertEqual(model.state, .failed(.signedOut))
    XCTAssertNil(cache.savedThreads)
    XCTAssertTrue(cache.savedMessages.isEmpty)
  }

  func testAChatShowsSavedMessagesWhileItLoads() async {
    let saved = ChatMessage(id: "m1", role: .user, content: "Hi", at: .distantPast)
    let fresh = ChatMessage(id: "m2", role: .assistant, content: "Hello", at: .distantPast)
    let cache = MemoryChatCache()
    cache.savedMessages = ["w/s1": [saved]]
    let client = FakeClient()
    client.messagesResult = .success([saved, fresh])

    let model = ConversationModel(client: client, threadId: "w/s1", cache: cache)
    XCTAssertEqual(model.messages, [saved])
    XCTAssertEqual(model.phase, .loading)

    await model.load()
    XCTAssertEqual(model.messages, [saved, fresh])
    XCTAssertEqual(cache.savedMessages["w/s1"], [saved, fresh])
  }

  func testASentMessageAndItsReplyAreSavedUnderTheNewThread() async {
    let cache = MemoryChatCache()
    let client = FakeClient()
    client.sendResult = .success(SendResult(threadId: "w/new", text: "Hi there", failed: false))
    let model = ConversationModel(client: client, threadId: nil, cache: cache)

    await model.send("Hello")

    XCTAssertEqual(cache.savedMessages["w/new"]?.map(\.content), ["Hello", "Hi there"])
  }
}
