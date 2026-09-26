import AVFoundation
import Observation

/// Records one voice message as small AAC audio. The recording travels to the
/// phone in a single WatchConnectivity message, which holds about 64 KB, so
/// the bit rate is low and the length capped.
@MainActor
@Observable
final class VoiceRecorder: NSObject, AVAudioRecorderDelegate {
  enum State: Equatable {
    case idle
    case recording
    /// The length cap or an interruption ended the recording; [stop] still
    /// returns it.
    case finished
    case denied
    case failed
  }

  static let mimeType = "audio/mp4"
  static let maxDuration: TimeInterval = 30

  private(set) var state = State.idle
  private var recorder: AVAudioRecorder?
  private var interruptions: NSObjectProtocol?
  /// Bumped by every start and cancel, so a start still waiting for the
  /// microphone permission gives up once it is stale.
  private var attempt = 0
  private let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice.m4a")

  func start() async {
    guard recorder == nil else { return }
    attempt += 1
    let current = attempt
    let allowed = await AVAudioApplication.requestRecordPermission()
    guard current == attempt, recorder == nil else { return }
    guard allowed else {
      state = .denied
      return
    }
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playAndRecord, mode: .default)
      try session.setActive(true)
      let recorder = try AVAudioRecorder(
        url: url,
        settings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVSampleRateKey: 16_000,
          AVNumberOfChannelsKey: 1,
          AVEncoderBitRateKey: 12_000,
        ]
      )
      recorder.delegate = self
      guard recorder.record(forDuration: Self.maxDuration) else { throw CocoaError(.fileWriteUnknown) }
      self.recorder = recorder
      state = .recording
      interruptions = NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: session,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.finish(recorder, successfully: true) }
      }
    } catch {
      try? session.setActive(false)
      try? FileManager.default.removeItem(at: url)
      state = .failed
    }
  }

  /// Stops and returns the recording, or nil when nothing was recorded.
  func stop() -> Data? {
    attempt += 1
    if let interruptions { NotificationCenter.default.removeObserver(interruptions) }
    interruptions = nil
    guard let recorder else { return nil }
    recorder.delegate = nil
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

  nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    Task { @MainActor in self.finish(recorder, successfully: flag) }
  }

  /// Ends a recording that stopped on its own: kept for [stop] when it is
  /// usable, dropped as a failure when not.
  private func finish(_ recorder: AVAudioRecorder, successfully: Bool) {
    guard recorder === self.recorder, state == .recording else { return }
    if successfully {
      recorder.pause()
      try? AVAudioSession.sharedInstance().setActive(false)
      state = .finished
    } else {
      cancel()
      state = .failed
    }
  }
}
