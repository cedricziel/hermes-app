import Foundation

enum VoiceTerminationReason: Equatable {
  case manual, durationLimit, interruption, automatic

  static func classifyStop(reported: Self, isRecording: Bool, elapsed: TimeInterval,
    durationLimit: TimeInterval) -> Self {
    guard reported == .manual else { return reported }
    guard elapsed.isFinite, elapsed >= 0 else { return .automatic }
    if elapsed >= durationLimit { return .durationLimit }
    return isRecording ? .manual : .automatic
  }
}

struct VoiceDraft {
  enum State: Equatable { case idle, transcribing, review, failed, noSpeech }
  private(set) var state = State.idle
  var text = ""
  private(set) var audio: Data?
  private(set) var mimeType = "audio/mp4"
  private var attempt: UUID?
  private var fastSend = false

  mutating func start(audio: Data, mimeType: String, reason: VoiceTerminationReason, fastSend: Bool) -> UUID {
    discard()
    self.audio = audio
    self.mimeType = mimeType
    self.fastSend = fastSend && reason == .manual
    state = .transcribing
    let token = UUID()
    attempt = token
    return token
  }

  mutating func complete(_ transcript: String, attempt token: UUID, allowSend: Bool = true) -> String? {
    guard attempt == token, state == .transcribing else { return nil }
    attempt = nil
    if allowSend { audio = nil }
    text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { audio = nil; state = .noSpeech; return nil }
    state = .review
    return fastSend && allowSend ? takeText() : nil
  }

  mutating func fail(attempt token: UUID) {
    guard attempt == token, state == .transcribing else { return }
    attempt = nil
    state = .failed
    fastSend = false
  }

  mutating func retry() -> UUID? {
    guard state == .failed, audio != nil else { return nil }
    let token = UUID()
    attempt = token
    state = .transcribing
    fastSend = false
    return token
  }

  mutating func takeText() -> String? {
    guard state == .review else { return nil }
    let result = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !result.isEmpty else { return nil }
    discard()
    return result
  }

  mutating func discard() {
    attempt = nil
    audio = nil
    text = ""
    fastSend = false
    state = .idle
  }
}
