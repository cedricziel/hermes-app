import Foundation
import Observation

@MainActor
@Observable
final class ConversationModel {
  enum Phase: Equatable {
    case loading
    case idle
    case sending
    case failed(HermesClientError)
  }

  private(set) var threadId: String?
  private(set) var messages: [ChatMessage] = []
  private(set) var phase = Phase.idle
  /// Text of a message that did not go through, so it can be sent again.
  private(set) var unsent: String?

  private let client: HermesClient

  init(client: HermesClient, threadId: String?) {
    self.client = client
    self.threadId = threadId
    if threadId != nil { phase = .loading }
  }

  func load() async {
    guard let threadId else { return }
    do {
      messages = try await client.messages(threadId: threadId)
      phase = .idle
    } catch {
      phase = .failed(error as? HermesClientError ?? .failed)
    }
  }

  func send(_ text: String) async {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, phase != .sending, phase != .loading else { return }
    unsent = nil
    phase = .sending
    let pending = ChatMessage(id: "local-\(UUID().uuidString)", role: .user, content: text, at: Date())
    messages.append(pending)
    do {
      let result = try await client.send(threadId: threadId, text: text)
      threadId = result.threadId ?? threadId
      if result.failed {
        let reason = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        takeBack(pending, error: reason.isEmpty ? .failed : .replyFailed(reason))
        return
      }
      messages.append(
        ChatMessage(id: "local-\(UUID().uuidString)", role: .assistant, content: result.text, at: Date())
      )
      phase = .idle
    } catch {
      takeBack(pending, error: error as? HermesClientError ?? .failed)
    }
  }

  /// Drops a message that did not go through and keeps its text to try again.
  private func takeBack(_ pending: ChatMessage, error: HermesClientError) {
    messages.removeAll { $0.id == pending.id }
    unsent = pending.content
    phase = .failed(error)
  }
}
