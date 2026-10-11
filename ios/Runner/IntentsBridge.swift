import Flutter
import UIKit

/// The one bridge between the App Intents and Dart. It owns the Dart engines
/// intents run in and the channel `hermes_app/intents` on each of them, so any
/// intent that needs Dart (Ask Hermes now, the request intents next) is one
/// more method on this channel, not an engine or an entry point of its own.
///
/// Engines. The app's own engine, once Dart has said `ready` on it (this keeps
/// an intent in the isolate that owns the session); else a background engine
/// on the `intentsMain` entry point (`lib/src/background/entry_points.dart`)
/// that is started on first use, gets `AskHermes.readyWait` to say `ready`, and
/// is shut down `idleLife` after its last in-flight call ended or its ready
/// wait ran out. A background engine that was too slow is kept, so a later
/// call can use it.
///
/// Swift calls Dart (`FlutterMethodChannel.invokeMethod`):
/// - `ask` `{id, question, profile?, chatId?, msLeft}` answers
///   `{outcome, text?}` when the intent has something to say (see
///   `AskOutcome`); the ask then runs on until Dart calls `finished`.
/// - `expire` `id?`: iOS is out of background time for that ask (every ask
///   without an id); Dart stops announcing and winds it down.
/// - `unavailable` `reason`: a call that found no engine (`AskUnavailable`),
///   told once Dart is there to record it.
/// - `openLink` `url`: take this `hermes://` link as if the platform had
///   delivered it; answers whether Dart took it.
///
/// (Siri's chat list is refreshed on its own channel, `hermes_app/shortcuts`.)
///
/// Dart calls Swift:
/// - `ready`: the handler is in place, calls may come.
/// - `finished` `id`: that ask has nothing left to do, so its background task
///   may end.
/// - `closed`: Dart stopped listening (the engine's `ready` is void).
///
/// A background task is held from the start of an ask until `finished` or
/// until iOS expires it. Calls reach an engine one at a time until it has
/// answered, or Swift's deadline for the call passed, whichever is first.
@MainActor
final class IntentsBridge: AskTurnService {
  static let shared = IntentsBridge()

  /// How long a background engine lives after its last call ended.
  static let idleLife: Duration = .seconds(10)

  /// How long `open` waits for the app's engine before it opens the link
  /// itself.
  static let appReadyWait: Duration = .seconds(10)

  /// One engine's end of the channel.
  final class Endpoint {
    let channel: FlutterMethodChannel
    let isApp: Bool
    var ready = false
    private var waiting: [Latch<Bool>] = []

    init(channel: FlutterMethodChannel, isApp: Bool) {
      self.channel = channel
      self.isApp = isApp
    }

    func becomeReady() {
      ready = true
      let all = waiting
      waiting = []
      all.forEach { $0.resume(true) }
    }

    /// Whether the engine said it is ready within [limit].
    func whenReady(within limit: Duration) async -> Bool {
      if ready { return true }
      return await withCheckedContinuation { continuation in
        let latch = Latch<Bool>(continuation)
        waiting.append(latch)
        Task {
          try? await Task.sleep(for: limit)
          latch.resume(false)
        }
      }
    }
  }

  private enum Called {
    case reply(Any?)
    case timedOut
  }

  private struct Ask {
    var task: UIBackgroundTaskIdentifier
    var endpoint: Endpoint?
  }

  private var app: Endpoint?
  private var appWaiting: [Latch<Bool>] = []
  private var background: (engine: FlutterEngine, endpoint: Endpoint)?
  private var asks: [String: Ask] = [:]
  private var owed: [AskUnavailable] = []
  private var idleTeardown: Task<Void, Never>?
  private var busy = false
  private var queue: [CheckedContinuation<Void, Never>] = []

  // MARK: Channel

  /// Listens on an engine's channel. The app's engine and a background engine
  /// each have one.
  @discardableResult
  func attach(messenger: FlutterBinaryMessenger, isApp: Bool) -> Endpoint {
    let channel = FlutterMethodChannel(name: "hermes_app/intents", binaryMessenger: messenger)
    let endpoint = Endpoint(channel: channel, isApp: isApp)
    if isApp { app = endpoint }
    channel.setMethodCallHandler { [weak endpoint] call, result in
      MainActor.assumeIsolated {
        switch call.method {
        case "ready":
          if let endpoint { IntentsBridge.shared.becameReady(endpoint) }
        case "finished":
          if let id = call.arguments as? String { IntentsBridge.shared.finish(id) }
        case "closed":
          endpoint?.ready = false
        default:
          return result(FlutterMethodNotImplemented)
        }
        result(nil)
      }
    }
    return endpoint
  }

  private func becameReady(_ endpoint: Endpoint) {
    endpoint.becomeReady()
    if endpoint.isApp {
      let all = appWaiting
      appWaiting = []
      all.forEach { $0.resume(true) }
    }
    // Dart is there now to record what could not run before.
    let reasons = owed
    owed = []
    for reason in reasons { endpoint.channel.invokeMethod("unavailable", arguments: reason.rawValue) }
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
    // Released when the engine has answered or the call's deadline passed.
    let hold = Hold { [weak self] in self?.release() }
    defer { hold.drop() }
    Task {
      try? await ContinuousClock().sleep(until: deadline)
      hold.drop()
    }

    for attempt in 0..<2 {
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
      switch await call(endpoint.channel, "ask", arguments, until: deadline) {
      case .timedOut:
        // No answer in time: the ask may still be running, so it is not over.
        return AskAnswer(.stillWorking)
      case .reply(let reply):
        // An engine that answers nothing is gone; try the other one once.
        if attempt == 0, endpoint.isApp, Self.isGone(reply) {
          endpoint.ready = false
          continue
        }
        // Dart ends the ask with `finished`, which for a late reply comes long
        // after this answer; a reply that is no answer at all means it never
        // will.
        if !(reply is [String: Any]) { finish(id) }
        return AskAnswer(channelReply: reply)
      }
    }
    finish(id)
    return AskAnswer(.unavailable)
  }

  /// Opens [url] in the app. It goes to Dart's deep links, which hold a link
  /// that arrives before the shell is up; the URL is opened by iOS itself only
  /// when the app's engine never answers.
  func open(_ url: URL) async {
    if await whenAppReady(within: Self.appReadyWait), let app,
      case .reply(let taken) = await call(
        app.channel, "openLink", url.absoluteString, until: .now + .seconds(5)),
      !Self.isGone(taken)
    {
      return
    }
    _ = await UIApplication.shared.open(url)
  }

  // MARK: Engines

  /// The engine for an ask: the app's when it is ready, else the background
  /// one, started if need be; nil when neither is up in time.
  private func engine() async -> Endpoint? {
    if let app, app.ready { return app }
    idleTeardown?.cancel()
    if let background {
      return await ready(background.endpoint)
    }
    let engine = FlutterEngine(name: "hermes.intents", project: nil, allowHeadlessExecution: true)
    guard
      engine.run(
        withEntrypoint: "intentsMain",
        libraryURI: "package:hermes_app/src/background/entry_points.dart")
    else {
      owed.append(.engineStartFailed)
      return nil
    }
    NotificationActions.registerPlugins(engine)
    let endpoint = attach(messenger: engine.binaryMessenger, isApp: false)
    background = (engine, endpoint)
    return await ready(endpoint)
  }

  /// [endpoint] once it is ready. Too slow is not fatal for the engine: it is
  /// kept for the next call (and told what happened when it does come up).
  private func ready(_ endpoint: Endpoint) async -> Endpoint? {
    if await endpoint.whenReady(within: AskHermes.readyWait) { return endpoint }
    owed.append(.readyTimeout)
    scheduleTeardown()
    return nil
  }

  private func whenAppReady(within limit: Duration) async -> Bool {
    if app?.ready == true { return true }
    return await withCheckedContinuation { continuation in
      let latch = Latch<Bool>(continuation)
      appWaiting.append(latch)
      Task {
        try? await Task.sleep(for: limit)
        latch.resume(false)
      }
    }
  }

  private func stopBackgroundEngine() {
    background?.engine.destroyContext()
    background = nil
  }

  /// Shuts the background engine down [idleLife] after the last ask using it
  /// is done.
  private func scheduleTeardown() {
    guard let background,
      !asks.values.contains(where: { $0.endpoint === background.endpoint })
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

  /// A reply that says nobody handles the call: the engine is gone.
  private static func isGone(_ reply: Any?) -> Bool {
    reply is FlutterError || (reply as? NSObject) === FlutterMethodNotImplemented
  }

  private func call(
    _ channel: FlutterMethodChannel, _ method: String, _ arguments: Any?,
    until deadline: ContinuousClock.Instant
  ) async -> Called {
    await withCheckedContinuation { continuation in
      let latch = Latch<Called>(continuation)
      channel.invokeMethod(method, arguments: arguments) { latch.resume(.reply($0)) }
      Task {
        try? await ContinuousClock().sleep(until: deadline)
        latch.resume(.timedOut)
      }
    }
  }

  // MARK: One call at a time to an engine

  /// Calls reach the engine one at a time until it has answered, so two asks
  /// do not refresh the session together.
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

  /// The place in line, given back once, by whoever comes first.
  private final class Hold {
    private var give: (() -> Void)?

    init(_ give: @escaping () -> Void) {
      self.give = give
    }

    func drop() {
      let give = self.give
      self.give = nil
      give?()
    }
  }
}
