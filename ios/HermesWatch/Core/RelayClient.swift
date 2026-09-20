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

  func threads() async throws -> [ThreadSummary] {
    let reply = try await call(["op": "threads"])
    guard let rows = reply["threads"] as? [[String: Any]] else { throw HermesClientError.failed }
    return rows.compactMap { row in
      guard let id = row["id"] as? String, let title = row["title"] as? String else { return nil }
      return ThreadSummary(
        id: id,
        title: title,
        updatedAt: Self.date(row["updatedAt"]),
        pinned: row["pinned"] as? Bool ?? false
      )
    }
  }

  func messages(threadId: String) async throws -> [ChatMessage] {
    let reply = try await call(["op": "messages", "threadId": threadId])
    guard let rows = reply["messages"] as? [[String: Any]] else { throw HermesClientError.failed }
    return rows.compactMap { row in
      guard let id = row["id"] as? String, let content = row["content"] as? String else { return nil }
      let role: ChatMessage.Role = row["role"] as? String == "user" ? .user : .assistant
      return ChatMessage(id: id, role: role, content: content, at: Self.date(row["at"]))
    }
  }

  func send(threadId: String?, text: String) async throws -> SendResult {
    var message: [String: Any] = ["op": "send", "text": text]
    if let threadId { message["threadId"] = threadId }
    let reply = try await call(message)
    guard let text = reply["text"] as? String else { throw HermesClientError.failed }
    let boundId = reply["threadId"] as? String
    if threadId == nil, boundId == nil { throw HermesClientError.failed }
    return SendResult(
      threadId: boundId,
      text: text,
      failed: reply["failed"] as? Bool ?? false
    )
  }

  private func call(_ message: [String: Any]) async throws -> [String: Any] {
    let reply = try await transport.request(message)
    guard reply["ok"] as? Bool == true else {
      switch reply["error"] as? String {
      case "signed_out": throw HermesClientError.signedOut
      case "unavailable": throw HermesClientError.unavailable
      default: throw HermesClientError.failed
      }
    }
    return reply
  }

  private static func date(_ epochSeconds: Any?) -> Date {
    Date(timeIntervalSince1970: (epochSeconds as? NSNumber)?.doubleValue ?? 0)
  }
}
