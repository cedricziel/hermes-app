import Foundation
import Observation
import OSLog

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
@MainActor
struct CachingClient: HermesClient {
  let inner: HermesClient
  let cache: ChatCache
  var session: WatchSessionState = WatchSessionState()
  var sessionState: WatchSessionState? { session }
  var recoveryStore: PendingSendStore { inner.recoveryStore }

  init(inner: HermesClient, cache: ChatCache, session: WatchSessionState? = nil) {
    self.inner = inner
    self.cache = cache
    let session = session ?? WatchSessionState()
    self.session = session
    _ = session.register { cache.clear() }
  }

  func requestDetails(threadId: String, requestId: String) async throws -> WatchRequestDetails? {
    try await forgettingOnSignOut { try await inner.requestDetails(threadId: threadId, requestId: requestId) }
  }
  func answerRequest(threadId: String, requestId: String, fingerprint: String, answer: WatchRequestAnswer) async throws -> String {
    try await forgettingOnSignOut { try await inner.answerRequest(threadId: threadId, requestId: requestId, fingerprint: fingerprint, answer: answer) }
  }

  func prepareRecovery() async throws { try await forgettingOnSignOut { try await inner.prepareRecovery() } }
  func forgetSend(sendId: String) async throws { try await forgettingOnSignOut { try await inner.forgetSend(sendId: sendId) } }
  func send(threadId: String?, text: String, sendId: String, retry: Bool, createdAt: Date) async throws -> SendResult {
    let result = try await forgettingOnSignOut {
      try await inner.send(threadId: threadId, text: text, sendId: sendId, retry: retry, createdAt: createdAt)
    }
    cacheResult(result, threadId: threadId, text: text, sendId: sendId, createdAt: createdAt)
    return result
  }

  func savedThreads() -> [ThreadSummary]? {
    guard session.usable, session.contextId != nil else { return nil }
    return cache.threads()?.filter { session.owns($0.id) }
  }

  func savedMessages(threadId: String) -> [ChatMessage]? {
    guard session.owns(threadId) else { return nil }
    return cache.messages(threadId: threadId)
  }

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
    cacheResult(result, threadId: threadId, text: text, sendId: sendId, createdAt: Date())
    return result
  }

  private func cacheResult(_ result: SendResult, threadId: String?, text: String, sendId: String, createdAt: Date) {
    guard !result.failed, result.waiting == nil, result.recoveryState == nil, let boundId = result.threadId ?? threadId else { return }
    var saved = cache.messages(threadId: boundId) ?? []
    guard !saved.contains(where: { $0.id == "local-\(sendId)-reply" }) else { return }
    if !saved.contains(where: { $0.id == "local-\(sendId)" }) {
      saved.append(ChatMessage(id: "local-\(sendId)", role: .user, content: text, at: createdAt))
    }
    saved.append(ChatMessage(id: "local-\(sendId)-reply", role: .assistant, content: result.text, at: Date(), tools: result.tools))
    cache.save(messages: saved, threadId: boundId)
  }

  func transcribe(audio: Data, mimeType: String) async throws -> String {
    try await forgettingOnSignOut { try await inner.transcribe(audio: audio, mimeType: mimeType) }
  }

  private func forgettingOnSignOut<T>(_ call: () async throws -> T) async throws -> T {
    let generation = session.generation
    do {
      let result = try await call()
      if !session.usable { throw HermesClientError.signedOut }
      guard generation == session.generation else { throw HermesClientError.signedOut }
      return result
    } catch HermesClientError.signedOut {
      if generation == session.generation { session.invalidate(); cache.clear() }
      throw HermesClientError.signedOut
    }
  }
}

/// Keeps the cache as JSON files in [directory]: one for the list, one per
/// chat. Only chats still on the list keep their messages, so it stays as
/// small as what the phone sends.
struct FileChatCache: ChatCache {
  let directory: URL
  var remove: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }
  var persistTombstone: (URL) throws -> Void = { file in
    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    #if os(watchOS)
      try Data().write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    #else
      try Data().write(to: file, options: .atomic)
    #endif
  }
  var diagnostics: (Bool) throws -> Void = { success in
    Logger(subsystem: "app.hermes.watch", category: "privacy").notice("Cache cleanup success=\(success, privacy: .public)")
  }
  var cleanupPending: Bool { CacheCleanupBarrier.contains(directory) || FileManager.default.fileExists(atPath: tombstone.path) }
  private var tombstone: URL { directory.appendingPathExtension("cleanup-pending") }

  func retryCleanup() {
    guard cleanupPending else { return }
    do {
      if FileManager.default.fileExists(atPath: directory.path) { try remove(directory) }
      if FileManager.default.fileExists(atPath: tombstone.path) { try FileManager.default.removeItem(at: tombstone) }
      CacheCleanupBarrier.remove(directory)
      try? diagnostics(true)
    } catch {
      CacheCleanupBarrier.insert(directory)
      try? diagnostics(false)
    }
  }

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
    CacheCleanupBarrier.insert(directory)
    do {
      try persistTombstone(tombstone)
    } catch {
      try? diagnostics(false)
    }
    retryCleanup()
  }

  /// Thread ids hold a slash, so the file is named by their base64url form.
  private func fileName(for threadId: String) -> String {
    Data(threadId.utf8).base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      + ".json"
  }

  private func read<T: Decodable>(_ type: T.Type, from file: URL) -> T? {
    retryCleanup()
    guard !cleanupPending, let data = try? Data(contentsOf: file) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }

  private func write<T: Encodable>(_ value: T, to file: URL) {
    retryCleanup()
    guard !cleanupPending, let data = try? JSONEncoder().encode(value) else { return }
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

private enum CacheCleanupBarrier {
  private static let lock = NSLock()
  private static var blocked = Set<String>()

  static func contains(_ directory: URL) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return blocked.contains(directory.standardizedFileURL.path)
  }

  static func insert(_ directory: URL) {
    lock.lock()
    defer { lock.unlock() }
    blocked.insert(directory.standardizedFileURL.path)
  }

  static func remove(_ directory: URL) {
    lock.lock()
    defer { lock.unlock() }
    blocked.remove(directory.standardizedFileURL.path)
  }
}

@MainActor
@Observable
final class WatchSessionState {
  static let shared = WatchSessionState(defaults: .standard)
  private let defaults: UserDefaults
  private(set) var revision: Int
  private(set) var generation = 0
  private(set) var usable: Bool
  private(set) var contextId: String?
  private(set) var handshaken = false
  private(set) var invalidationReason = HermesClientError.signedOut
  private var cleanup: [UUID: () -> Void] = [:]
  private let diagnostics: (String, Bool, Int) throws -> Void

  convenience init() { self.init(defaults: UserDefaults(suiteName: UUID().uuidString)!) }

  init(defaults: UserDefaults, diagnostics: @escaping (String, Bool, Int) throws -> Void = { reason, success, count in
    Logger(subsystem: "app.hermes.watch", category: "privacy").notice("Session cleanup reason=\(reason, privacy: .public) success=\(success, privacy: .public) count=\(count, privacy: .public)")
  }) {
    self.defaults = defaults
    self.diagnostics = diagnostics
    revision = defaults.integer(forKey: "watch.session.revision")
    usable = !defaults.bool(forKey: "watch.session.signedOut")
    contextId = defaults.string(forKey: "watch.session.context")
  }

  func register(_ action: @escaping () -> Void) -> UUID {
    let id = UUID()
    cleanup[id] = action
    if !usable { action() }
    return id
  }

  /// Registers all private cleanup before accepting the startup publication.
  @discardableResult
  func start(receivedSession payload: [String: Any], cleanup action: @escaping () -> Void) -> UUID {
    let removesLegacyData = contextId == nil && usable
    let registration = register(action)
    if removesLegacyData { action() }
    receive(payload)
    return registration
  }

  func unregister(_ id: UUID) { cleanup.removeValue(forKey: id) }

  func receive(_ payload: [String: Any]) {
    guard let state = payload["watchSession"] as? [String: Any],
      let next = state["revision"] as? Int, let usable = state["usable"] as? Bool,
      next >= revision else { return }
    if !usable {
      guard next > revision || self.usable else { return }
      revision = next
      defaults.set(next, forKey: "watch.session.revision")
      invalidate()
      return
    }
    guard state["protocolVersion"] as? Int == 2,
      let context = state["contextId"] as? String else { return }
    _ = acceptContext(context, revision: next, confirmed: false)
  }

  @discardableResult
  func acceptContext(_ context: String, revision next: Int, confirmed: Bool = true) -> Bool {
    guard !context.isEmpty, next >= revision,
      next > revision || contextId == context || (contextId == nil && revision == 0 && usable) else { return false }
    let replacesUsableSession = contextId != nil && (contextId != context || next > revision)
    let alreadyVerified = contextId == context && next == revision && handshaken
    if replacesUsableSession {
      invalidationReason = .contextChanged
      generation += 1
      for action in cleanup.values { action() }
      try? diagnostics("context_changed", true, cleanup.count)
    }
    WatchRequestAccess.shared.acceptOwner(context, revision: next)
    contextId = context
    revision = next
    usable = true
    handshaken = alreadyVerified || confirmed
    defaults.set(context, forKey: "watch.session.context")
    defaults.set(next, forKey: "watch.session.revision")
    defaults.set(false, forKey: "watch.session.signedOut")
    return true
  }

  func owns(_ threadId: String) -> Bool {
    WatchThreadId.decode(threadId)?.contextId == contextId && contextId != nil && usable
  }

  func invalidate(reason: HermesClientError = .signedOut) {
    invalidationReason = reason
    generation += 1
    usable = false
    handshaken = false
    contextId = nil
    defaults.removeObject(forKey: "watch.session.context")
    defaults.set(true, forKey: "watch.session.signedOut")
    for action in cleanup.values { action() }
    try? diagnostics(reason == .contextChanged ? "context_changed" : "signed_out", true, cleanup.count)
  }
}
