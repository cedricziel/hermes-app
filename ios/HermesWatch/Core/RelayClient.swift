import Foundation

/// Carries one request to the phone and returns its reply.
protocol RelayTransport {
  func request(_ message: [String: Any]) async throws -> [String: Any]
}

/// A [HermesClient] that asks the phone app, which holds the session, to do
/// the work. The wire format is the one `WatchRequestHandler` in the Dart app
/// answers.
struct RelayClient: HermesClient {
  let transport: RelayTransport
  let session: WatchSessionState
  var sessionState: WatchSessionState? { session }

  init(transport: RelayTransport, session: WatchSessionState? = nil) {
    self.transport = transport
    self.session = session ?? WatchSessionState()
  }


  func threads() async throws -> [ThreadSummary] {
    let reply = try await call(["op": "threads"])
    guard let rows = reply["threads"] as? [[String: Any]] else { throw HermesClientError.failed }
    return rows.compactMap { row in
      guard let id = row["id"] as? String, session.owns(id), let title = row["title"] as? String else { return nil }
      return ThreadSummary(
        id: id,
        title: title,
        updatedAt: (row["updatedAt"] as? NSNumber).flatMap { $0.doubleValue > 0 ? Date(timeIntervalSince1970: $0.doubleValue) : nil },
        pinned: row["pinned"] as? Bool ?? false,
        handoff: HandoffTarget(row: row)
      )
    }
  }

  func messages(threadId: String) async throws -> [ChatMessage] {
    let reply = try await call(["op": "messages", "threadId": threadId])
    guard let rows = reply["messages"] as? [[String: Any]] else { throw HermesClientError.failed }
    return rows.compactMap { row in
      guard let id = row["id"] as? String, let content = row["content"] as? String else { return nil }
      let role: ChatMessage.Role = row["role"] as? String == "user" ? .user : .assistant
      return ChatMessage(
        id: id,
        role: role,
        content: content,
        at: Self.date(row["at"]),
        tools: row["tools"] as? [String] ?? []
      )
    }
  }

  func send(threadId: String?, text: String, sendId: String, retry: Bool) async throws -> SendResult {
    var message: [String: Any] = ["op": "send", "text": text, "sendId": sendId]
    if let threadId { message["threadId"] = threadId }
    if retry { message["retry"] = true }
    // This watch understands a `waiting` answer; an older one ends the send.
    message["waits"] = true
    let reply = try await call(message)
    let boundId = reply["threadId"] as? String
    if let boundId, !session.owns(boundId) { throw HermesClientError.contextChanged }
    if let waiting = reply["waiting"] as? String {
      return SendResult(
        threadId: boundId, text: "", failed: false,
        waiting: SendResult.Waiting(rawValue: waiting) ?? .working, handoff: HandoffTarget(row: reply))
    }
    guard let text = reply["text"] as? String else { throw HermesClientError.failed }
    if threadId == nil, boundId == nil { throw HermesClientError.failed }
    return SendResult(
      threadId: boundId,
      text: text,
      failed: reply["failed"] as? Bool ?? false,
      tools: reply["tools"] as? [String] ?? [],
      handoff: HandoffTarget(row: reply)
    )
  }

  func transcribe(audio: Data, mimeType: String) async throws -> String {
    let reply = try await call(["op": "transcribe", "audio": audio, "mimeType": mimeType])
    guard let text = reply["text"] as? String else { throw HermesClientError.failed }
    return text
  }

  private func call(_ request: [String: Any]) async throws -> [String: Any] {
    let preparedContext = session.contextId
    let preparedGeneration = session.generation
    if !session.handshaken {
      let handshake = try await transport.request(["op": "session"])
      guard handshake["ok"] as? Bool == true else {
        if handshake["error"] as? String == "bad_request" { throw HermesClientError.updateRequired }
        try check(handshake)
        throw HermesClientError.failed
      }
      guard handshake["protocolVersion"] as? Int == 2,
        let context = handshake["contextId"] as? String,
        let revision = handshake["revision"] as? Int else { throw HermesClientError.updateRequired }
      guard session.acceptContext(context, revision: revision) else { throw HermesClientError.contextChanged }
    }
    guard preparedGeneration == session.generation,
      preparedContext == nil || preparedContext == session.contextId else { throw HermesClientError.contextChanged }
    guard session.usable, let context = session.contextId else { throw HermesClientError.signedOut }
    if let thread = request["threadId"] as? String, !session.owns(thread) { throw HermesClientError.contextChanged }
    let generation = session.generation
    let revision = session.revision
    var message = request
    message["contextId"] = context
    message["revision"] = revision
    let reply = try await transport.request(message)
    guard generation == session.generation, session.contextId == context else { throw HermesClientError.contextChanged }
    try check(reply)
    guard reply["contextId"] as? String == context, reply["revision"] as? Int == revision else {
      session.invalidate(reason: .contextChanged)
      throw HermesClientError.contextChanged
    }
    return reply
  }

  private func check(_ reply: [String: Any]) throws {
    guard reply["ok"] as? Bool == true else {
      switch reply["error"] as? String {
      case "signed_out": session.invalidate(); throw HermesClientError.signedOut
      case "context_changed": session.invalidate(reason: .contextChanged); throw HermesClientError.contextChanged
      case "unavailable": throw HermesClientError.unavailable
      default: throw HermesClientError.failed
      }
    }
  }

  private static func date(_ epochSeconds: Any?) -> Date {
    Date(timeIntervalSince1970: (epochSeconds as? NSNumber)?.doubleValue ?? 0)
  }
}
