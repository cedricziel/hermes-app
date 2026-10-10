import Foundation

/// What the watch saw last: the chat list and each listed chat's messages,
/// shown at once on the next launch and kept on screen when the phone cannot
/// be reached.
protocol ChatCache {
  func threads() -> [ThreadSummary]?
  func save(threads: [ThreadSummary])
  func messages(threadId: String) -> [ChatMessage]?
  func save(messages: [ChatMessage], threadId: String)
  /// Forgets everything, for a phone that signed out.
  func clear()
}

/// A [HermesClient] that keeps in [cache] what [inner] answers, offers it
/// back as what was saved, and forgets it all once the phone signed out.
struct CachingClient: HermesClient {
  let inner: HermesClient
  let cache: ChatCache

  func savedThreads() -> [ThreadSummary]? { cache.threads() }

  func savedMessages(threadId: String) -> [ChatMessage]? { cache.messages(threadId: threadId) }

  func threads() async throws -> [ThreadSummary] {
    let threads = try await forgettingOnSignOut { try await inner.threads() }
    cache.save(threads: threads)
    return threads
  }

  func messages(threadId: String) async throws -> [ChatMessage] {
    let messages = try await forgettingOnSignOut { try await inner.messages(threadId: threadId) }
    cache.save(messages: messages, threadId: threadId)
    return messages
  }

  func send(threadId: String?, text: String, sendId: String, retry: Bool) async throws -> SendResult {
    let result = try await forgettingOnSignOut {
      try await inner.send(threadId: threadId, text: text, sendId: sendId, retry: retry)
    }
    // A waiting answer is no turn yet; the final one is saved once.
    if !result.failed, result.waiting == nil, let boundId = result.threadId ?? threadId {
      let turn = [
        ChatMessage(id: "local-\(sendId)", role: .user, content: text, at: Date()),
        ChatMessage(id: "local-\(sendId)-reply", role: .assistant, content: result.text, at: Date(), tools: result.tools),
      ]
      cache.save(messages: (cache.messages(threadId: boundId) ?? []) + turn, threadId: boundId)
    }
    return result
  }

  func transcribe(audio: Data, mimeType: String) async throws -> String {
    try await forgettingOnSignOut { try await inner.transcribe(audio: audio, mimeType: mimeType) }
  }

  private func forgettingOnSignOut<T>(_ call: () async throws -> T) async throws -> T {
    do {
      return try await call()
    } catch HermesClientError.signedOut {
      cache.clear()
      throw HermesClientError.signedOut
    }
  }
}

/// Keeps the cache as JSON files in [directory]: one for the list, one per
/// chat. Only chats still on the list keep their messages, so it stays as
/// small as what the phone sends.
struct FileChatCache: ChatCache {
  let directory: URL

  /// In the app's Caches directory, which watchOS may empty when it needs
  /// the space.
  static var standard: FileChatCache {
    FileChatCache(
      directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("chats", isDirectory: true)
    )
  }

  private var threadsFile: URL { directory.appendingPathComponent("threads.json") }
  private var messagesDirectory: URL { directory.appendingPathComponent("messages", isDirectory: true) }

  func threads() -> [ThreadSummary]? { read([ThreadSummary].self, from: threadsFile) }

  func save(threads: [ThreadSummary]) {
    write(threads, to: threadsFile)
    let kept = Set(threads.map { fileName(for: $0.id) })
    let files = (try? FileManager.default.contentsOfDirectory(atPath: messagesDirectory.path)) ?? []
    for file in files where !kept.contains(file) {
      try? FileManager.default.removeItem(at: messagesDirectory.appendingPathComponent(file))
    }
  }

  func messages(threadId: String) -> [ChatMessage]? {
    read([ChatMessage].self, from: messagesDirectory.appendingPathComponent(fileName(for: threadId)))
  }

  func save(messages: [ChatMessage], threadId: String) {
    write(messages, to: messagesDirectory.appendingPathComponent(fileName(for: threadId)))
  }

  func clear() {
    try? FileManager.default.removeItem(at: directory)
  }

  /// Thread ids hold a slash, so the file is named by their base64url form.
  private func fileName(for threadId: String) -> String {
    Data(threadId.utf8).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      + ".json"
  }

  private func read<T: Decodable>(_ type: T.Type, from file: URL) -> T? {
    guard let data = try? Data(contentsOf: file) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }

  private func write<T: Encodable>(_ value: T, to file: URL) {
    guard let data = try? JSONEncoder().encode(value) else { return }
    try? FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    #if os(watchOS)
      try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    #else
      try? data.write(to: file, options: .atomic)
    #endif
  }
}
