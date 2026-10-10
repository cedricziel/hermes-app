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
    /// The send waits on the user's answer to an approval or a question.
    case waiting(SendResult.Waiting)
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
  /// The message of a send that waited on the user and then lost the phone.
  /// Hermes has it, so it stays on screen and trying again only asks after it.
  private var keptMessage: ChatMessage?
  /// The send in progress; a send whose wait was stopped no longer is.
  private var currentSend: UUID?

  private let client: HermesClient

  /// How long a send keeps asking while Hermes waits; the phone gives up
  /// after 15 minutes without an event.
  static let waitingLimit: TimeInterval = 20 * 60

  init(client: HermesClient, threadId: String?) {
    self.client = client
    self.threadId = threadId
    if threadId != nil { phase = .loading }
  }

  /// Shows the messages saved last time, if there are any, until the phone
  /// answers.
  func load() async {
    guard let threadId else { return }
    if messages.isEmpty, let saved = client.savedMessages(threadId: threadId) { messages = saved }
    do {
      messages = try await client.messages(threadId: threadId)
      phase = .idle
    } catch {
      phase = .failed(error as? HermesClientError ?? .failed)
    }
  }

  func send(_ text: String) async {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, !busy else { return }
    let again = text == unsent
    // A send that waited reached Hermes: trying it again only asks after it.
    let resuming = again && keptMessage != nil
    let sendId = (again ? unsentId : nil) ?? UUID().uuidString
    unsent = nil
    unsentId = nil
    phase = .sending
    let pending = resuming ? keptMessage! : ChatMessage(id: "local-\(UUID().uuidString)", role: .user, content: text, at: Date())
    if !resuming { messages.append(pending) }
    keptMessage = nil
    let attempt = UUID()
    currentSend = attempt
    var waited = resuming
    do {
      var result = try await client.send(threadId: threadId, text: text, sendId: sendId, retry: resuming)
      // The phone answers early while the turn waits on the user, and the
      // same send id asked again picks up where it was. A phone that has
      // forgotten the send reads the bound chat instead of sending it again.
      let deadline = Date().addingTimeInterval(Self.waitingLimit)
      while let waiting = result.waiting {
        guard currentSend == attempt else { return }
        guard Date() < deadline else { throw HermesClientError.failed }
        waited = true
        threadId = result.threadId ?? threadId
        phase = waiting == .working ? .sending : .waiting(waiting)
        result = try await client.send(threadId: threadId, text: text, sendId: sendId, retry: true)
      }
      threadId = result.threadId ?? threadId
      if result.failed {
        guard currentSend == attempt else { return }
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
      if currentSend == attempt { phase = .idle }
    } catch {
      guard currentSend == attempt else { return }
      let reason = error as? HermesClientError ?? .failed
      if waited {
        keep(pending, error: reason, sendId: sendId)
      } else {
        takeBack(pending, error: reason, sendId: sendId)
      }
    }
  }

  /// Stops waiting on the user's answer here: the message stays, the chat is
  /// free again, and the reply shows when the chat is read next.
  func stopWaiting() {
    guard case .waiting = phase else { return }
    currentSend = nil
    phase = .idle
  }

  /// A message or a recording is on its way, or the chat is loading.
  var busy: Bool {
    switch phase {
    case .sending, .loading, .transcribing, .waiting: true
    case .idle, .failed: false
    }
  }

  /// Sends what the dashboard hears in a recording as the next message.
  func sendVoice(_ audio: Data, mimeType: String) async {
    guard !busy else { return }
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

  /// Keeps a message Hermes has but whose reply did not come back, to ask
  /// after it again.
  private func keep(_ pending: ChatMessage, error: HermesClientError, sendId: String) {
    keptMessage = pending
    unsent = pending.content
    unsentId = sendId
    phase = .failed(error)
  }

  /// Drops a message that did not go through and keeps its text to try again.
  private func takeBack(_ pending: ChatMessage, error: HermesClientError, sendId: String?) {
    messages.removeAll { $0.id == pending.id }
    unsent = pending.content
    unsentId = sendId
    phase = .failed(error)
  }
}
