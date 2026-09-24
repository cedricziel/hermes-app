import AVFoundation
import Observation

/// Records one voice message as small AAC audio. The recording travels to the
/// phone in a single WatchConnectivity message, which holds about 64 KB, so
/// the bit rate is low and the length capped.
@MainActor
@Observable
final class VoiceRecorder {
  enum State: Equatable {
    case idle
    case recording
    case denied
    case failed
  }

  static let mimeType = "audio/mp4"
  static let maxDuration: TimeInterval = 30

  private(set) var state = State.idle
  private var recorder: AVAudioRecorder?
  private let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice.m4a")

  func start() async {
    guard state != .recording else { return }
    guard await AVAudioApplication.requestRecordPermission() else {
      state = .denied
      return
    }
    do {
      try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default)
      try AVAudioSession.sharedInstance().setActive(true)
      let recorder = try AVAudioRecorder(
        url: url,
        settings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVSampleRateKey: 16_000,
          AVNumberOfChannelsKey: 1,
          AVEncoderBitRateKey: 12_000,
        ]
      )
      guard recorder.record(forDuration: Self.maxDuration) else {
        state = .failed
        return
      }
      self.recorder = recorder
      state = .recording
    } catch {
      state = .failed
    }
  }

  /// Stops and returns the recording, or nil when nothing was recorded.
  func stop() -> Data? {
    guard let recorder else { return nil }
    recorder.stop()
    self.recorder = nil
    state = .idle
    try? AVAudioSession.sharedInstance().setActive(false)
    defer { try? FileManager.default.removeItem(at: url) }
    guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
    return data
  }

  func cancel() {
    _ = stop()
  }
}
