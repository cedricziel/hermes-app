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

  func prepareRecovery() async throws {
    let context = session.contextId
    let generation = session.generation
    let handshake = try await transport.request(["op": "session"])
    guard generation == session.generation else { throw HermesClientError.contextChanged }
    if handshake["error"] as? String == "bad_request" { throw HermesClientError.updateRequired }
    try check(handshake)
    guard handshake["protocolVersion"] as? Int == 2,
      let nextContext = handshake["contextId"] as? String,
      let revision = handshake["revision"] as? Int else { throw HermesClientError.updateRequired }
    guard session.acceptContext(nextContext, revision: revision) else { throw HermesClientError.contextChanged }
    guard context == nil || context == nextContext, generation == session.generation else { throw HermesClientError.contextChanged }
    guard let supported = handshake["sendState"] as? Bool else { throw HermesClientError.updateRequired }
    guard supported else { throw HermesClientError.unavailable }
  }

  func forgetSend(sendId: String) async throws {
    try await prepareRecovery()
    _ = try await call(["op": "forgetSend", "sendId": sendId])
  }

  func send(threadId: String?, text: String, sendId: String, retry: Bool) async throws -> SendResult {
    guard !retry else { throw HermesClientError.updateRequired }
    return try await send(threadId: threadId, text: text, sendId: sendId, retry: false, createdAt: Date())
  }

  func send(threadId: String?, text: String, sendId: String, retry: Bool, createdAt: Date) async throws -> SendResult {
    try await prepareRecovery()
    var message: [String: Any] = ["op": "send", "text": text, "sendId": sendId, "createdAt": Int64(createdAt.timeIntervalSince1970 * 1000)]
    if let threadId { message["threadId"] = threadId }
    if retry { message["retry"] = true }
    // This watch understands a `waiting` answer; an older one ends the send.
    message["waits"] = true
    let reply = try await call(message)
    if let answeredId = reply["sendId"] as? String, answeredId != sendId { throw HermesClientError.failed }
    let boundId = reply["threadId"] as? String
    if let boundId, !session.owns(boundId) { throw HermesClientError.contextChanged }
    if let raw = reply["recoveryState"] as? String {
      guard let state = SendRecoveryState(rawValue: raw), [.pending, .uncertain, .notSent].contains(state) else { throw HermesClientError.failed }
      return SendResult(threadId: boundId, text: "", failed: false, handoff: HandoffTarget(row: reply), recoveryState: state)
    }
    if let waiting = reply["waiting"] as? String {
      return SendResult(
        threadId: boundId, text: "", failed: false,
        waiting: SendResult.Waiting(rawValue: waiting) ?? .working, handoff: HandoffTarget(row: reply),
        requestId: reply["requestId"] as? String, inlineEligible: reply["inlineEligible"] as? Bool ?? false)
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

  func requestDetails(threadId: String, requestId: String) async throws -> WatchRequestDetails? {
    let access = WatchRequestAccess.shared
    guard access.allowed else { throw HermesClientError.unavailable }
    let epoch = access.epoch
    let reply = try await call(["op": "request_details", "threadId": threadId, "requestId": requestId, "requestEpoch": epoch])
    guard access.allowed, access.epoch == epoch, reply["requestEpoch"] as? Int == epoch else { throw HermesClientError.unavailable }
    if reply["status"] as? String == "expired" { return nil }
    return try WatchRequestDetails(row: reply)
  }

  func answerRequest(threadId: String, requestId: String, fingerprint: String, answer: WatchRequestAnswer) async throws -> String {
    let access = WatchRequestAccess.shared
    guard access.allowed else { throw HermesClientError.unavailable }
    let epoch = access.epoch
    var message = answer.fields
    message["op"] = "request_answer"
    message["threadId"] = threadId
    message["requestId"] = requestId
    message["requestEpoch"] = epoch
    message["fingerprint"] = fingerprint
    let reply = try await call(message)
    guard access.allowed, access.epoch == epoch else { throw HermesClientError.unavailable }
    return reply["status"] as? String ?? "uncertain"
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
    WatchRequestAccess.shared.receive(reply)
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
      case "capacity", "send_capacity", "journal_full": throw HermesClientError.recoveryCapacity
      case "expired", "send_expired": throw HermesClientError.sendExpired
      case "clock_skew": throw HermesClientError.clockSkew
      case "send_state_unavailable": throw HermesClientError.updateRequired
      default: throw HermesClientError.failed
      }
    }
  }

  private static func date(_ epochSeconds: Any?) -> Date {
    Date(timeIntervalSince1970: (epochSeconds as? NSNumber)?.doubleValue ?? 0)
  }
}
