import Flutter
import UIKit

/// Runs the questions of "Ask Hermes" in Dart, in the engine that is up: the
/// app's own when it has said it is ready (so the ask shares the isolate that
/// owns the session), else a background engine started for the ask on the
/// `intentsMain` entry point. That one lives until 10 seconds after its last
/// ask is done.
///
/// A background task is held from the start of an ask until Dart reports it
/// done or iOS runs out of time, so a reply that takes longer than Siri waits
/// can still arrive as a notification.
@MainActor
final class IntentsBridge: AskTurnService {
  static let shared = IntentsBridge()

  /// How long a background engine may take to say it is ready.
  static let readyWait: Duration = .seconds(5)
  /// How long a background engine lives after its last ask.
  static let idleLife: Duration = .seconds(10)

  /// One engine's end of the channel.
  final class Endpoint {
    let channel: FlutterMethodChannel
    var ready = false
    private var waiting: [Waiter] = []

    init(channel: FlutterMethodChannel) {
      self.channel = channel
    }

    func becomeReady() {
      ready = true
      let all = waiting
      waiting = []
      all.forEach { $0.finish(true) }
    }

    /// Whether the engine said it is ready within [limit].
    func whenReady(within limit: Duration) async -> Bool {
      if ready { return true }
      return await withCheckedContinuation { continuation in
        let waiter = Waiter(continuation)
        waiting.append(waiter)
        Task {
          try? await Task.sleep(for: limit)
          waiter.finish(false)
        }
      }
    }
  }

  /// A continuation resumed by whichever of readiness and the timeout comes
  /// first.
  private final class Waiter {
    private var continuation: CheckedContinuation<Bool, Never>?

    init(_ continuation: CheckedContinuation<Bool, Never>) {
      self.continuation = continuation
    }

    func finish(_ ready: Bool) {
      continuation?.resume(returning: ready)
      continuation = nil
    }
  }

  private struct Ask {
    var task: UIBackgroundTaskIdentifier
    var endpoint: Endpoint?
  }

  private var app: Endpoint?
  private var background: (engine: FlutterEngine, endpoint: Endpoint)?
  private var asks: [String: Ask] = [:]
  private var idleTeardown: Task<Void, Never>?
  private var busy = false
  private var queue: [CheckedContinuation<Void, Never>] = []

  // MARK: Channel

  /// Listens on an engine's channel. The app's engine and a background engine
  /// each have one.
  @discardableResult
  func attach(messenger: FlutterBinaryMessenger, isApp: Bool) -> Endpoint {
    let channel = FlutterMethodChannel(name: "hermes_app/intents", binaryMessenger: messenger)
    let endpoint = Endpoint(channel: channel)
    if isApp { app = endpoint }
    channel.setMethodCallHandler { [weak endpoint] call, result in
      MainActor.assumeIsolated {
        switch call.method {
        case "refreshShortcuts":
          HermesAppShortcuts.updateAppShortcutParameters()
        case "ready":
          endpoint?.becomeReady()
        case "finished":
          if let id = call.arguments as? String { IntentsBridge.shared.finish(id) }
        default:
          return result(FlutterMethodNotImplemented)
        }
        result(nil)
      }
    }
    return endpoint
  }

  // MARK: AskTurnService

  func ask(
    question: String, profile: String?, chatID: String?, deadline: ContinuousClock.Instant
  ) async -> AskAnswer {
    let id = UUID().uuidString
    var task = UIBackgroundTaskIdentifier.invalid
    task = UIApplication.shared.beginBackgroundTask(withName: "ask-hermes") { [weak self] in
      MainActor.assumeIsolated { self?.expire(id) }
    }
    asks[id] = Ask(task: task, endpoint: nil)

    await acquire()
    defer { release() }
    guard let endpoint = await engine() else {
      finish(id)
      return AskAnswer(.unavailable)
    }
    asks[id]?.endpoint = endpoint

    var arguments: [String: Any] = [
      "id": id, "question": question, "msLeft": Self.milliseconds(until: deadline),
    ]
    arguments["profile"] = profile
    arguments["chatId"] = chatID
    let reply = await call(endpoint.channel, "ask", arguments)
    // Dart ends the ask with `finished`, which for a late reply comes long
    // after this answer; a reply that is no answer at all means it never will.
    if !(reply is [String: Any]) { finish(id) }
    return AskAnswer(channelReply: reply)
  }

  func open(_ url: URL) async {
    _ = await UIApplication.shared.open(url)
  }

  // MARK: Engines

  /// The engine for an ask: the app's when it is ready, else the background
  /// one, started if need be; nil when neither is up in time.
  private func engine() async -> Endpoint? {
    if let app, app.ready { return app }
    idleTeardown?.cancel()
    if let background {
      return await background.endpoint.whenReady(within: Self.readyWait)
        ? background.endpoint : nil
    }
    let engine = FlutterEngine(name: "hermes.intents", project: nil, allowHeadlessExecution: true)
    guard
      engine.run(
        withEntrypoint: "intentsMain",
        libraryURI: "package:hermes_app/src/background/entry_points.dart")
    else { return nil }
    NotificationActions.registerPlugins(engine)
    let endpoint = attach(messenger: engine.binaryMessenger, isApp: false)
    background = (engine, endpoint)
    guard await endpoint.whenReady(within: Self.readyWait) else {
      stopBackgroundEngine()
      return nil
    }
    return endpoint
  }

  private func stopBackgroundEngine() {
    background?.engine.destroyContext()
    background = nil
  }

  /// Shuts the background engine down [idleLife] after the last ask using it
  /// is done.
  private func scheduleTeardown() {
    guard background != nil, !asks.values.contains(where: { $0.endpoint === background?.endpoint })
    else { return }
    idleTeardown?.cancel()
    idleTeardown = Task { [weak self] in
      try? await Task.sleep(for: Self.idleLife)
      guard !Task.isCancelled else { return }
      self?.stopBackgroundEngine()
    }
  }

  // MARK: Asks

  /// Ends an ask: its background task, and the engine once it is idle.
  private func finish(_ id: String) {
    guard let ask = asks.removeValue(forKey: id) else { return }
    if ask.task != .invalid { UIApplication.shared.endBackgroundTask(ask.task) }
    scheduleTeardown()
  }

  /// iOS is out of background time: tell Dart so it stops announcing, and let
  /// go of the task.
  private func expire(_ id: String) {
    guard let ask = asks[id] else { return }
    ask.endpoint?.channel.invokeMethod("expire", arguments: id)
    finish(id)
  }

  private static func milliseconds(until deadline: ContinuousClock.Instant) -> Int {
    let left = ContinuousClock.now.duration(to: deadline)
    let (seconds, attoseconds) = left.components
    return max(0, Int(seconds) * 1000 + Int(attoseconds / 1_000_000_000_000_000))
  }

  private func call(_ channel: FlutterMethodChannel, _ method: String, _ arguments: Any?) async
    -> Any?
  {
    await withCheckedContinuation { continuation in
      channel.invokeMethod(method, arguments: arguments) { continuation.resume(returning: $0) }
    }
  }

  // MARK: One ask at a time to the engine

  /// Asks reach the engine one at a time until it has answered, so two of
  /// them do not refresh the session together.
  private func acquire() async {
    if busy {
      await withCheckedContinuation { queue.append($0) }
    } else {
      busy = true
    }
  }

  private func release() {
    if queue.isEmpty {
      busy = false
    } else {
      queue.removeFirst().resume()
    }
  }
}
