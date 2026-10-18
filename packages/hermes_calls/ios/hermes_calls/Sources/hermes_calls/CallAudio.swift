import AVFAudio
import Flutter

/// CallKit owns AVAudioSession activation. This engine keeps its microphone
/// and speaker in one voice-processing graph, so acoustic echo cancellation
/// also sees speech received from Hermes.
final class CallAudio {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let outputFormat = AVAudioFormat(standardFormatWithSampleRate: 24_000, channels: 1)!
  private var tapped = false
  private var generation = 0
  private var playbackGeneration = 0
  private var pendingFrames = 0
  private var drain: FlutterResult?
  private var playbackConverter: AVAudioConverter?
  private var playbackRate = 0.0
  var running: Bool { engine.isRunning }
  var muted = false
  var emit: (([String: Any]) -> Void)?

  init() {
    engine.attach(player)
    engine.connect(player, to: engine.mainMixerNode, format: outputFormat)
  }

  func start() throws {
    guard !engine.isRunning else { return }
    let input = engine.inputNode
    try input.setVoiceProcessingEnabled(true)
    let source = input.outputFormat(forBus: 0)
    guard source.sampleRate > 0,
          let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16_000,
                                     channels: 1, interleaved: true),
          let converter = AVAudioConverter(from: source, to: target) else {
      throw AudioError.unavailable
    }
    let captureGeneration = generation
    input.installTap(onBus: 0, bufferSize: 2048, format: source) { [weak self] buffer, _ in
      let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 16_000 / source.sampleRate)) + 32
      guard let converted = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
      var supplied = false
      var error: NSError?
      converter.convert(to: converted, error: &error) { _, status in
        guard !supplied else { status.pointee = .noDataNow; return nil }
        supplied = true
        status.pointee = .haveData
        return buffer
      }
      guard error == nil, converted.frameLength > 0, let samples = converted.int16ChannelData else { return }
      let data = Data(bytes: samples[0], count: Int(converted.frameLength) * 2)
      DispatchQueue.main.async {
        guard let self, self.engine.isRunning, !self.muted,
              captureGeneration == self.generation else { return }
        self.emit?(["type": "pcm", "data": FlutterStandardTypedData(bytes: data)])
      }
    }
    tapped = true
    do {
      engine.prepare()
      try engine.start()
    } catch {
      input.removeTap(onBus: 0)
      tapped = false
      throw error
    }
  }

  func play(_ data: Data, rate: Double) throws {
    guard engine.isRunning, rate >= 8000, rate <= 96000, data.count % 2 == 0 else {
      throw AudioError.unavailable
    }
    guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
          let input = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(data.count / 2)),
          let samples = input.floatChannelData else { throw AudioError.unavailable }
    input.frameLength = input.frameCapacity
    data.withUnsafeBytes { bytes in
      for index in 0..<Int(input.frameLength) {
        let value = bytes.loadUnaligned(fromByteOffset: index * 2, as: Int16.self)
        samples[0][index] = Float(Int16(littleEndian: value)) / 32768
      }
    }
    let buffer: AVAudioPCMBuffer
    if rate == outputFormat.sampleRate {
      buffer = input
    } else {
      if playbackRate != rate {
        playbackConverter = AVAudioConverter(from: format, to: outputFormat)
        playbackRate = rate
      }
      guard let converter = playbackConverter,
            let converted = AVAudioPCMBuffer(pcmFormat: outputFormat,
              frameCapacity: AVAudioFrameCount(ceil(Double(input.frameLength) * 24_000 / rate)) + 32) else {
        throw AudioError.unavailable
      }
      var supplied = false
      var error: NSError?
      converter.convert(to: converted, error: &error) { _, status in
        guard !supplied else { status.pointee = .noDataNow; return nil }
        supplied = true
        status.pointee = .haveData
        return input
      }
      if let error { throw error }
      buffer = converted
    }
    guard pendingFrames + Int(buffer.frameLength) <= 24_000 * 120 else { throw AudioError.overflow }
    pendingFrames += Int(buffer.frameLength)
    let scheduledGeneration = playbackGeneration
    player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
      DispatchQueue.main.async {
        guard let self, scheduledGeneration == self.playbackGeneration else { return }
        self.pendingFrames -= Int(buffer.frameLength)
        if self.pendingFrames == 0 { self.drain?(nil); self.drain = nil }
      }
    }
    if !player.isPlaying { player.play() }
  }

  func finish(_ result: @escaping FlutterResult) {
    guard pendingFrames > 0 else { result(nil); return }
    drain?(FlutterError(code: "cancelled", message: "Playback replaced", details: nil))
    drain = result
  }

  func stopPlayback() {
    // Capture keeps the same generation; only playback completions are stale.
    playbackGeneration += 1
    player.stop()
    pendingFrames = 0
    drain?(FlutterError(code: "cancelled", message: "Playback stopped", details: nil))
    drain = nil
    playbackConverter = nil
    playbackRate = 0
  }

  func stop() {
    generation += 1
    stopPlayback()
    if tapped { engine.inputNode.removeTap(onBus: 0); tapped = false }
    engine.stop()
  }

  enum AudioError: Error { case unavailable, overflow }
}
