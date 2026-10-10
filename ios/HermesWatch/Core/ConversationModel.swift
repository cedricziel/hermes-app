import Foundation
import Observation

@MainActor
@Observable
final class ConversationModel {
  enum Phase: Equatable {
    case loading
    case idle
    case transcribing
    case sending
    case failed(HermesClientError)
  }

  private(set) var threadId: String?
  private(set) var messages: [ChatMessage] = []
  private(set) var phase = Phase.idle
  /// Text of a message that did not go through, so it can be sent again.
  private(set) var unsent: String?
  /// The id [unsent] went out with. Sending it again reuses the id, so the
  /// phone can tell a retry from a new message.
  private var unsentId: String?
  /// A recording that could not be transcribed, so it can be tried again.
  private(set) var unsentVoice: Data?

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
    let sendId = (text == unsent ? unsentId : nil) ?? UUID().uuidString
    unsent = nil
    unsentId = nil
    phase = .sending
    let pending = ChatMessage(id: "local-\(UUID().uuidString)", role: .user, content: text, at: Date())
    messages.append(pending)
    do {
      let result = try await client.send(threadId: threadId, text: text, sendId: sendId)
      threadId = result.threadId ?? threadId
      if result.failed {
        let reason = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Hermes answered, so trying again is a new message.
        takeBack(pending, error: reason.isEmpty ? .failed : .replyFailed(reason), sendId: nil)
        return
      }
      messages.append(
        ChatMessage(
          id: "local-\(UUID().uuidString)",
          role: .assistant,
          content: result.text,
          at: Date(),
          tools: result.tools
        )
      )
      phase = .idle
    } catch {
      takeBack(pending, error: error as? HermesClientError ?? .failed, sendId: sendId)
    }
  }

  /// Sends what the dashboard hears in a recording as the next message.
  func sendVoice(_ audio: Data, mimeType: String) async {
    guard phase != .sending, phase != .loading, phase != .transcribing else { return }
    unsentVoice = nil
    phase = .transcribing
    do {
      let text = try await client.transcribe(audio: audio, mimeType: mimeType)
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        phase = .failed(.noSpeech)
        return
      }
      phase = .idle
      await send(text)
    } catch {
      unsentVoice = audio
      phase = .failed(error as? HermesClientError ?? .failed)
    }
  }

  /// Drops a message that did not go through and keeps its text to try again.
  private func takeBack(_ pending: ChatMessage, error: HermesClientError, sendId: String?) {
    messages.removeAll { $0.id == pending.id }
    unsent = pending.content
    unsentId = sendId
    phase = .failed(error)
  }
}
