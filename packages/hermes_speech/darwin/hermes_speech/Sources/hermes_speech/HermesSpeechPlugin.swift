import AVFoundation
import Speech

#if os(iOS)
  import Flutter
#else
  import FlutterMacOS
#endif

/// Recognizes speech on the device with SpeechAnalyzer, from 16-bit mono PCM
/// the app records itself or from a whole recording. Errors reach Dart only as
/// fixed codes
/// (`unsupported`, `modelMissing`, `failed`), never as recognizer text.
public final class HermesSpeechPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let instance = HermesSpeechPlugin()
    registrar.addMethodCallDelegate(
      instance, channel: FlutterMethodChannel(name: "hermes_app/speech", binaryMessenger: messenger))
    FlutterEventChannel(name: "hermes_app/speech/events", binaryMessenger: messenger)
      .setStreamHandler(instance)
    registrar.publish(instance)
  }

  private var sink: FlutterEventSink?
  private var sessions: [Int: Session] = [:]
  private var nextId = 0

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    MainActor.assumeIsolated { cancelAll() }
    sink = nil
  }

  @MainActor
  private func cancelAll() {
    sessions.values.forEach { $0.cancel() }
    sessions.removeAll()
  }

  // Flutter calls the plugin on the main thread.
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    MainActor.assumeIsolated { handleOnMain(call, result: result) }
  }

  @MainActor
  private func handleOnMain(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "status":
      Task { @MainActor in result(await Self.status(args["locale"] as? String)) }
    case "install":
      Task { @MainActor in result(await self.install(args["locale"] as? String)) }
    case "start":
      Task { @MainActor in
        result(await self.start(args["locale"] as? String, sampleRate: args["sampleRate"] as? Int))
      }
    case "append":
      // Synchronous, so chunks reach the analyzer in the order they came.
      if let id = args["id"] as? Int, let pcm = args["pcm"] as? FlutterStandardTypedData {
        sessions[id]?.append(pcm.data)
      }
      result(nil)
    case "finish":
      guard let id = args["id"] as? Int, let session = sessions.removeValue(forKey: id) else {
        result(FlutterError(code: "failed", message: nil, details: nil))
        return
      }
      Task { @MainActor in
        do {
          result(try await session.finish())
        } catch {
          result(FlutterError(code: "failed", message: nil, details: nil))
        }
      }
    case "transcribeFile":
      let audio = (args["audio"] as? FlutterStandardTypedData)?.data
      Task { @MainActor in
        result(await Self.transcribeFile(audio, locale: args["locale"] as? String))
      }
    case "cancel":
      if let id = args["id"] as? Int { sessions.removeValue(forKey: id)?.cancel() }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Model

  private static func transcriber(
    _ tag: String?, preset: SpeechTranscriber.Preset = .progressiveTranscription
  ) async -> SpeechTranscriber? {
    guard SpeechTranscriber.isAvailable, let tag,
      let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: tag))
    else { return nil }
    return SpeechTranscriber(locale: locale, preset: preset)
  }

  /// `unsupported`, `missing`, `downloading` or `installed`.
  private static func status(_ tag: String?) async -> String {
    guard let transcriber = await transcriber(tag) else { return "unsupported" }
    switch await AssetInventory.status(forModules: [transcriber]) {
    case .installed: return "installed"
    case .downloading: return "downloading"
    case .supported: return "missing"
    default: return "unsupported"
    }
  }

  @MainActor
  private func install(_ tag: String?) async -> Any? {
    guard let transcriber = await Self.transcriber(tag) else {
      return FlutterError(code: "unsupported", message: nil, details: nil)
    }
    do {
      guard
        let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber])
      else { return nil }  // Already installed.
      let observation = request.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
        let fraction = progress.fractionCompleted
        Task { @MainActor in self?.sink?(["type": "progress", "fraction": fraction]) }
      }
      defer { observation.invalidate() }
      try await request.downloadAndInstall()
      sink?(["type": "progress", "fraction": 1.0])
      return nil
    } catch {
      return FlutterError(code: "failed", message: nil, details: nil)
    }
  }

  // MARK: Recordings

  /// Everything heard in [audio], a recording in any format AVAudioFile reads.
  @MainActor
  private static func transcribeFile(_ audio: Data?, locale tag: String?) async -> Any? {
    guard let audio, let transcriber = await transcriber(tag, preset: .transcription) else {
      return FlutterError(code: "unsupported", message: nil, details: nil)
    }
    guard await AssetInventory.status(forModules: [transcriber]) == .installed else {
      return FlutterError(code: "modelMissing", message: nil, details: nil)
    }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    do {
      try audio.write(to: url)
      let file = try AVAudioFile(forReading: url)
      let analyzer = SpeechAnalyzer(modules: [transcriber])
      async let text = transcriber.results.reduce(into: "") { text, result in
        if result.isFinal { text += String(result.text.characters) }
      }
      try await analyzer.start(inputAudioFile: file, finishAfterFile: true)
      return try await text
    } catch {
      return FlutterError(code: "failed", message: nil, details: nil)
    }
  }

  // MARK: Sessions

  @MainActor
  private func start(_ tag: String?, sampleRate: Int?) async -> Any? {
    // One recording at a time; the analyzer limits concurrent analyses.
    cancelAll()
    guard let sampleRate, let transcriber = await Self.transcriber(tag) else {
      return FlutterError(code: "unsupported", message: nil, details: nil)
    }
    guard await AssetInventory.status(forModules: [transcriber]) == .installed else {
      return FlutterError(code: "modelMissing", message: nil, details: nil)
    }
    nextId += 1
    let id = nextId
    do {
      let session = try await Session.start(
        transcriber: transcriber, sampleRate: Double(sampleRate),
        onText: { [weak self] text in self?.sink?(["id": id, "type": "partial", "text": text]) },
        onError: { [weak self] in
          self?.sessions.removeValue(forKey: id)?.cancel()
          self?.sink?(["id": id, "type": "error", "code": "failed"])
        })
      sessions[id] = session
      return id
    } catch {
      return FlutterError(code: "failed", message: nil, details: nil)
    }
  }
}

/// One recording on its way through the analyzer.
@MainActor
private final class Session {
  private let analyzer: SpeechAnalyzer
  private let input: AsyncStream<AnalyzerInput>.Continuation
  private let source: AVAudioFormat
  private let converter: AVAudioConverter?
  private let target: AVAudioFormat
  private var results: Task<String, Error>?

  private init(
    analyzer: SpeechAnalyzer, input: AsyncStream<AnalyzerInput>.Continuation,
    source: AVAudioFormat, target: AVAudioFormat
  ) {
    self.analyzer = analyzer
    self.input = input
    self.source = source
    self.target = target
    converter = source == target ? nil : AVAudioConverter(from: source, to: target)
  }

  static func start(
    transcriber: SpeechTranscriber, sampleRate: Double,
    onText: @escaping @MainActor (String) -> Void, onError: @escaping @MainActor () -> Void
  ) async throws -> Session {
    guard
      let source = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: true)
    else { throw CocoaError(.featureUnsupported) }
    let target =
      await SpeechAnalyzer.bestAvailableAudioFormat(
        compatibleWith: [transcriber], considering: source) ?? source
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    let (stream, input) = AsyncStream<AnalyzerInput>.makeStream()
    let session = Session(analyzer: analyzer, input: input, source: source, target: target)
    // The live text is what is final so far plus the latest guess after it.
    session.results = Task { @MainActor in
      var final = ""
      var shown = ""
      do {
        for try await result in transcriber.results {
          let text = String(result.text.characters)
          if result.isFinal { final += text }
          let live = result.isFinal ? final : final + text
          if live != shown {
            shown = live
            onText(live)
          }
        }
      } catch is CancellationError {
      } catch {
        onError()
        throw error
      }
      return final
    }
    try await analyzer.start(inputSequence: stream)
    return session
  }

  func append(_ data: Data) {
    let frames = AVAudioFrameCount(data.count / 2)
    guard frames > 0, let buffer = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: frames)
    else { return }
    buffer.frameLength = frames
    data.withUnsafeBytes { bytes in
      buffer.int16ChannelData![0].update(
        from: bytes.bindMemory(to: Int16.self).baseAddress!, count: Int(frames))
    }
    guard let converted = convert(buffer) else { return }
    input.yield(AnalyzerInput(buffer: converted))
  }

  private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
    guard let converter else { return buffer }
    let capacity =
      AVAudioFrameCount(Double(buffer.frameLength) * target.sampleRate / source.sampleRate) + 16
    guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
      return nil
    }
    var consumed = false
    var error: NSError?
    converter.convert(to: output, error: &error) { _, status in
      if consumed {
        status.pointee = .noDataNow
        return nil
      }
      consumed = true
      status.pointee = .haveData
      return buffer
    }
    return error == nil && output.frameLength > 0 ? output : nil
  }

  /// Recognizes the rest of the recording and answers everything it heard.
  func finish() async throws -> String {
    input.finish()
    try await analyzer.finalizeAndFinishThroughEndOfInput()
    return try await results?.value ?? ""
  }

  func cancel() {
    input.finish()
    results?.cancel()
    Task { await analyzer.cancelAndFinishNow() }
  }
}
