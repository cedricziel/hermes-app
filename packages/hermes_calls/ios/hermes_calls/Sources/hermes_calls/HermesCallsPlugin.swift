import AVFAudio
import CallKit
import Flutter
import UIKit

/// Only user-started outgoing calls. No PushKit registration or artificial
/// incoming call is needed to put an ongoing Hermes conversation in CallKit.
public final class HermesCallsPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, CXProviderDelegate {
  private let provider: CXProvider
  private let controller = CXCallController()
  private let audio = CallAudio()
  private var sink: FlutterEventSink?
  private var callID: UUID?
  private var startGeneration = 0
  private var routeObserver: NSObjectProtocol?
  private var configurationObserver: NSObjectProtocol?
  private var audioActive = false
  private var activationTimer: Timer?

  override init() {
    let configuration = CXProviderConfiguration()
    configuration.supportsVideo = false
    configuration.supportedHandleTypes = [.generic]
    configuration.maximumCallGroups = 1
    configuration.maximumCallsPerCallGroup = 1
    configuration.includesCallsInRecents = false
    provider = CXProvider(configuration: configuration)
    super.init()
    provider.setDelegate(self, queue: .main)
    audio.emit = { [weak self] event in self?.emit(event) }
    routeObserver = NotificationCenter.default.addObserver(
      forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in self?.reportRoute() }
    configurationObserver = NotificationCenter.default.addObserver(
      forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self, self.callID != nil, self.audioActive, !self.audio.running else { return }
      // Notify Dart before cancelling a pending drain, so a route handoff
      // invalidates the old speech turn rather than failing the entire call.
      self.emit(["type": "audioReset"])
      do { self.audio.stop(); try self.audio.start(); self.reportRoute() }
      catch {
        self.emit(["type": "error"])
        self.finish(reason: .failed)
      }
    }
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = HermesCallsPlugin()
    let methods = FlutterMethodChannel(name: "hermes_app/calls", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methods)
    FlutterEventChannel(name: "hermes_app/calls/events", binaryMessenger: registrar.messenger())
      .setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "start":
      guard callID == nil, let raw = args["id"] as? String, let id = UUID(uuidString: raw),
            let name = args["name"] as? String else {
        result(failure("unavailable", "Another call is already active.")); return
      }
      startGeneration += 1
      let requestedGeneration = startGeneration
      AVAudioApplication.requestRecordPermission { [weak self] granted in
        DispatchQueue.main.async {
          guard let self else { result(nil); return }
          guard requestedGeneration == self.startGeneration else {
            result(self.failure("cancelled", "Call cancelled.")); return
          }
          guard granted else { result(self.failure("permission", "Microphone access is off.")); return }
          guard self.callID == nil else { result(self.failure("unavailable", "Another call is already active.")); return }
          self.callID = id
          let action = CXStartCallAction(call: id, handle: CXHandle(type: .generic, value: name))
          self.controller.request(CXTransaction(action: action)) { error in
            DispatchQueue.main.async {
              if let error {
                if self.callID == id { self.finish(reason: .failed) }
                result(self.failure("start", error.localizedDescription))
              } else { result(nil) }
            }
          }
        }
      }
    case "end":
      startGeneration += 1
      audioActive = false
      audio.stop()
      guard let id = callID else { result(nil); return }
      controller.request(CXTransaction(action: CXEndCallAction(call: id))) { [weak self] error in
        DispatchQueue.main.async {
          if error != nil, self?.callID == id { self?.finish(reason: .failed) }
          result(nil)
        }
      }
    case "muted":
      guard let id = callID, let muted = args["muted"] as? Bool else { result(nil); return }
      controller.request(CXTransaction(action: CXSetMutedCallAction(call: id, muted: muted))) { error in
        DispatchQueue.main.async { result(error.map { self.failure("mute", $0.localizedDescription) }) }
      }
    case "speaker":
      do {
        try AVAudioSession.sharedInstance().overrideOutputAudioPort(args["enabled"] as? Bool == true ? .speaker : .none)
        reportRoute()
        result(nil)
      } catch { result(failure("route", "Could not change the audio route.")) }
    case "connected":
      if let id = callID { provider.reportOutgoingCall(with: id, connectedAt: Date()) }
      result(nil)
    case "play":
      guard callID != nil, let bytes = args["pcm"] as? FlutterStandardTypedData,
            let rate = args["sampleRate"] as? NSNumber else {
        result(failure("audio", "No active call audio.")); return
      }
      do { try audio.play(bytes.data, rate: rate.doubleValue); result(nil) }
      catch { result(failure("audio", "Could not play call audio.")) }
    case "drain": audio.finish(result)
    case "stopPlayback": audio.stopPlayback(); result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
    guard action.callUUID == callID else { action.fail(); return }
    do {
      try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP])
      let update = CXCallUpdate()
      update.remoteHandle = action.handle
      update.localizedCallerName = action.handle.value
      update.supportsHolding = false
      update.supportsGrouping = false
      update.supportsUngrouping = false
      update.supportsDTMF = false
      provider.reportCall(with: action.callUUID, updated: update)
      provider.reportOutgoingCall(with: action.callUUID, startedConnectingAt: Date())
      action.fulfill()
      activationTimer?.invalidate()
      activationTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in
        self?.emit(["type": "error", "message": "Call audio did not become available."])
        self?.finish(reason: .failed)
      }
    } catch {
      action.fail()
      finish(reason: .failed)
    }
  }

  public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    guard callID != nil else { return }
    activationTimer?.invalidate()
    activationTimer = nil
    do {
      audioActive = true
      try audio.start()
      emit(["type": "activated"])
      reportRoute()
    } catch {
      emit(["type": "error", "message": "Could not open call audio."])
      finish(reason: .failed)
    }
  }

  public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    audioActive = false
    audio.stop()
    emit(["type": "deactivated"])
  }

  public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    guard action.callUUID == callID else { action.fail(); return }
    audio.muted = action.isMuted
    emit(["type": "muted", "muted": action.isMuted])
    action.fulfill()
  }

  public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    guard action.callUUID == callID else { action.fulfill(); return }
    action.fulfill()
    finish(reason: nil)
  }

  public func providerDidReset(_ provider: CXProvider) { finish(reason: .failed) }
  public func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
    finish(reason: .failed)
  }

  private func finish(reason: CXCallEndedReason?) {
    startGeneration += 1
    audioActive = false
    guard let id = callID else { return }
    activationTimer?.invalidate()
    activationTimer = nil
    audio.stop()
    audio.muted = false
    callID = nil
    if let reason { provider.reportCall(with: id, endedAt: Date(), reason: reason) }
    emit(["type": reason == .failed ? "error" : "ended"])
  }

  private func reportRoute() {
    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
    emit(["type": "route", "name": outputs.first?.portName ?? "iPhone",
          "speaker": outputs.contains { $0.portType == .builtInSpeaker }])
  }

  private func emit(_ event: [String: Any]) { sink?(event) }
  private func failure(_ code: String, _ message: String) -> FlutterError {
    FlutterError(code: code, message: message, details: nil)
  }
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events; return nil
  }
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    finish(reason: .remoteEnded)
    return nil
  }
  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    finish(reason: .failed)
    provider.invalidate()
    if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
    if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
  }
}
