import Flutter
import UIKit

/// Runs the Dart side of "Pending Requests" and "Answer Approval". An intent
/// runs in the app's process, possibly launched in the background with no
/// scene and so no Flutter engine, so the bridge starts an engine of its own
/// on the `requestIntentsMain` entry point and keeps it for a few seconds
/// for the next call. Calls run one at a time. Nothing but the request's ids
/// and the user's choice goes over the channel; Dart reads the tokens itself.
@MainActor
final class RequestIntentsBridge: RequestIntentsBackend {
  static let shared = RequestIntentsBridge()

  private static let channelName = "hermes_app/request_intents"
  private static let entrypoint = "requestIntentsMain"
  private static let library = "package:hermes_app/src/background/entry_points.dart"

  /// How long the engine may take to say it is ready.
  private static let readyWait: TimeInterval = 5
  /// How long the engine is kept after the last call.
  private static let idleTeardown: TimeInterval = 10
  /// What a call may take: the Dart side's own limit plus the engine's start.
  private static let readTimeout: TimeInterval = 20
  private static let answerTimeout: TimeInterval = 25

  private var engine: FlutterEngine?
  private var channel: FlutterMethodChannel?
  private var isReady = false
  private var readyWaiters: [CheckedContinuation<Bool, Never>] = []
  private var busy = false
  private var queue: [CheckedContinuation<Void, Never>] = []
  private var idle: Task<Void, Never>?

  func pending(profile: String?) async -> PendingReply {
    var arguments: [String: Any] = [:]
    if let profile { arguments["profile"] = profile }
    return PendingReply(json: await call("pending", arguments, timeout: Self.readTimeout))
  }

  func approvalDetail(_ request: RequestRef) async -> DetailReply {
    DetailReply(json: await call("approvalDetail", arguments(request), timeout: Self.readTimeout))
  }

  func answerApproval(_ request: RequestRef, choice: ApprovalChoice) async -> RequestOutcome {
    var arguments = arguments(request)
    arguments["choice"] = choice.rawValue
    let reply = await call("answerApproval", arguments, timeout: Self.answerTimeout)
    return (reply?["outcome"] as? String).flatMap(RequestOutcome.init(rawValue:)) ?? .unavailable
  }

  func recordCancelled(choice: ApprovalChoice) async {
    _ = await call(
      "record", ["outcome": "cancelled", "choice": choice.rawValue], timeout: Self.readTimeout)
  }

  private func arguments(_ request: RequestRef) -> [String: Any] {
    ["profile": request.profile, "threadId": request.threadID, "requestId": request.requestID]
  }

  // MARK: Calls

  private func call(_ method: String, _ arguments: [String: Any], timeout: TimeInterval) async
    -> [String: Any]?
  {
    await acquire()
    idle?.cancel()
    // iOS suspends the app as soon as the intent returns; this holds it until
    // the Dart side is done or its time runs out.
    var task = UIBackgroundTaskIdentifier.invalid
    task = UIApplication.shared.beginBackgroundTask(withName: "request-intent") {
      UIApplication.shared.endBackgroundTask(task)
      task = .invalid
    }
    var reply: [String: Any]?
    if await startEngineIfNeeded() {
      reply = await invoke(method, arguments, timeout: timeout)
    }
    scheduleTeardown()
    if task != .invalid { UIApplication.shared.endBackgroundTask(task) }
    release()
    return reply
  }

  private func acquire() async {
    guard busy else {
      busy = true
      return
    }
    await withCheckedContinuation { queue.append($0) }
  }

  private func release() {
    if queue.isEmpty {
      busy = false
    } else {
      queue.removeFirst().resume()
    }
  }

  /// Sends [method] and returns the Dart side's map, or `nil` for an error or
  /// for no answer within [timeout].
  private func invoke(_ method: String, _ arguments: [String: Any], timeout: TimeInterval) async
    -> [String: Any]?
  {
    guard let channel else { return nil }
    return await withCheckedContinuation { continuation in
      let once = Once()
      channel.invokeMethod(method, arguments: arguments) { result in
        once.run { continuation.resume(returning: result as? [String: Any]) }
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
        once.run { continuation.resume(returning: nil) }
      }
    }
  }

  // MARK: Engine

  private func startEngineIfNeeded() async -> Bool {
    if engine == nil {
      let engine = FlutterEngine(
        name: "hermes.request_intents", project: nil, allowHeadlessExecution: true)
      guard engine.run(withEntrypoint: Self.entrypoint, libraryURI: Self.library) else {
        return false
      }
      // A handler can only be set once the engine runs. Dart's first message
      // is handled on this thread, after this turn, so none is missed.
      let channel = FlutterMethodChannel(
        name: Self.channelName, binaryMessenger: engine.binaryMessenger)
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "ready" else { return result(FlutterMethodNotImplemented) }
        self?.markReady()
        result(nil)
      }
      BackgroundPlugins.register(with: engine)
      self.engine = engine
      self.channel = channel
    }
    if await waitUntilReady() { return true }
    tearDown()
    return false
  }

  private func waitUntilReady() async -> Bool {
    if isReady { return true }
    return await withCheckedContinuation { continuation in
      readyWaiters.append(continuation)
      DispatchQueue.main.asyncAfter(deadline: .now() + Self.readyWait) { [weak self] in
        self?.resumeWaiters(false)
      }
    }
  }

  private func markReady() {
    isReady = true
    resumeWaiters(true)
  }

  private func resumeWaiters(_ ready: Bool) {
    let waiters = readyWaiters
    readyWaiters = []
    for waiter in waiters { waiter.resume(returning: ready) }
  }

  private func scheduleTeardown() {
    idle?.cancel()
    idle = Task { [weak self] in
      try? await Task.sleep(for: .seconds(Self.idleTeardown))
      guard !Task.isCancelled, let self, !self.busy else { return }
      self.tearDown()
    }
  }

  private func tearDown() {
    engine?.destroyContext()
    engine = nil
    channel = nil
    isReady = false
  }
}

/// Runs a closure once, however many callers race to.
private final class Once: @unchecked Sendable {
  private let lock = NSLock()
  private var done = false

  func run(_ work: () -> Void) {
    lock.lock()
    let first = !done
    done = true
    lock.unlock()
    if first { work() }
  }
}
