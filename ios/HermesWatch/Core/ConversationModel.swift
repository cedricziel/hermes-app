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

  private(set) var permitsOriginalTitle = true
  private(set) var threadId: String?
  /// Where the open chat lives, if the phone said; nil for a new chat.
  private(set) var handoff: HandoffTarget?
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

  private let session: WatchSessionState
  private var cleanupId: UUID?
  private let client: HermesClient

  /// How long a send keeps asking while Hermes waits; the phone gives up
  /// after 15 minutes without an event.
  static let waitingLimit: TimeInterval = 20 * 60

  init(client: HermesClient, threadId: String?, handoff: HandoffTarget? = nil, session: WatchSessionState? = nil) {
    self.client = client
    self.threadId = threadId
    self.handoff = threadId == nil ? nil : handoff
    if threadId != nil { phase = .loading }
    let session = session ?? client.sessionState ?? WatchSessionState()
    self.session = session
    cleanupId = session.register { [weak self] in self?.clearPrivateState() }
  }

  /// Shows the messages saved last time, if there are any, until the phone
  /// answers.
  func load() async {
    guard session.usable, let threadId else { return }
    let generation = session.generation
    if messages.isEmpty, let saved = client.savedMessages(threadId: threadId) { messages = saved }
    do {
      let loaded = try await client.messages(threadId: threadId)
      guard generation == session.generation else { return }
      messages = loaded
      phase = .idle
    } catch {
      guard generation == session.generation else { return }
      if (error as? HermesClientError) == .signedOut { session.invalidate(); return }
      phase = .failed(error as? HermesClientError ?? .failed)
    }
  }

  func send(_ text: String) async {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard session.usable, !text.isEmpty, !busy else { return }
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
      guard currentSend == attempt else { return }
      // The phone answers early while the turn waits on the user, and the
      // same send id asked again picks up where it was. A phone that has
      // forgotten the send reads the bound chat instead of sending it again.
      let deadline = Date().addingTimeInterval(Self.waitingLimit)
      while let waiting = result.waiting {
        guard currentSend == attempt else { return }
        guard Date() < deadline else { throw HermesClientError.failed }
        waited = true
        threadId = result.threadId ?? threadId
        handoff = result.handoff ?? handoff
        phase = waiting == .working ? .sending : .waiting(waiting)
        result = try await client.send(threadId: threadId, text: text, sendId: sendId, retry: true)
        guard currentSend == attempt else { return }
      }
      threadId = result.threadId ?? threadId
      handoff = result.handoff ?? handoff
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
      if reason == .signedOut { session.invalidate(); return }
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
    guard session.usable, !busy else { return }
    let generation = session.generation
    unsentVoice = nil
    phase = .transcribing
    do {
      let text = try await client.transcribe(audio: audio, mimeType: mimeType)
      guard generation == session.generation else { return }
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        phase = .failed(.noSpeech)
        return
      }
      phase = .idle
      await send(text)
    } catch {
      guard generation == session.generation else { return }
      if (error as? HermesClientError) == .signedOut { session.invalidate(); return }
      unsentVoice = audio
      phase = .failed(error as? HermesClientError ?? .failed)
    }
  }

  private func clearPrivateState() {
    permitsOriginalTitle = false
    currentSend = nil
    threadId = nil
    handoff = nil
    messages = []
    unsent = nil
    unsentId = nil
    unsentVoice = nil
    keptMessage = nil
    phase = .failed(session.invalidationReason)
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
