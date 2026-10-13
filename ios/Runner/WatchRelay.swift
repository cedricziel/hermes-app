import Flutter
import UIKit
import WatchConnectivity
import OSLog

/// Passes what the watch app asks for on to Dart over the `app.hermes/watch`
/// channel and sends Dart's answer back. Dart does the network work: it holds
/// the session and knows the dashboard.
final class WatchRelay: NSObject, WCSessionDelegate {
  static let channelName = "app.hermes/watch"

  private let channel: FlutterMethodChannel?
  private let invokeRequest: ([String: Any], @escaping (Any?) -> Void) -> Void
  private let beginTask: (@escaping () -> Void) -> UIBackgroundTaskIdentifier
  private let endTask: (UIBackgroundTaskIdentifier) -> Void
  private let logger = Logger(subsystem: "app.hermes", category: "watch-relay")

  init(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    self.channel = channel
    invokeRequest = { message, completion in
      channel.invokeMethod("request", arguments: message, result: completion)
    }
    beginTask = { expiry in
      UIApplication.shared.beginBackgroundTask(withName: "watch-relay", expirationHandler: expiry)
    }
    endTask = { UIApplication.shared.endBackgroundTask($0) }
    super.init()
    secureRequestAccessAtLaunch()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(FlutterMethodNotImplemented); return }
      if call.method == "publishSessionState", let arguments = call.arguments as? [String: Any],
        let usable = arguments["usable"] as? Bool {
        self.publishSessionState(usable: usable, arguments: arguments, result: result)
        return
      }
      if call.method == "publishRequestAccess", let arguments = call.arguments as? [String: Any],
        let allowed = arguments["allowed"] as? Bool {
        self.publishRequestAccess(allowed: allowed, arguments: arguments, result: result)
        return
      }
      guard call.method == "complication",
        let arguments = call.arguments as? [String: Any],
        let payload = arguments["payload"] as? [String: Any]
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.sendComplication(payload, urgent: arguments["urgent"] as? Bool ?? false, result: result)
    }
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  init(
    invokeRequest: @escaping ([String: Any], @escaping (Any?) -> Void) -> Void,
    beginTask: @escaping (@escaping () -> Void) -> UIBackgroundTaskIdentifier,
    endTask: @escaping (UIBackgroundTaskIdentifier) -> Void
  ) {
    channel = nil
    self.invokeRequest = invokeRequest
    self.beginTask = beginTask
    self.endTask = endTask
    super.init()
  }

  private struct RequestAccessState: Codable {
    let epoch: Int
    let allowed: Bool
    let contextId: String?
    let revision: Int?
    var payload: [String: Any] {
      guard let contextId, let revision else { return ["unavailable": true] }
      return ["epoch": epoch, "allowed": allowed, "contextId": contextId, "revision": revision]
    }
  }

  private var requestAccess: RequestAccessState?
  private var requestAccessUnavailable = false

  private func requestAccessFile() throws -> URL {
    let directory = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true)
    return directory.appendingPathComponent("watch.requests.publication.json")
  }

  private func reserveRequestAccess(allowed: Bool, owner: [String: Any]?) throws -> RequestAccessState {
    var file = try requestAccessFile()
    let saved: RequestAccessState?
    if FileManager.default.fileExists(atPath: file.path) {
      saved = try JSONDecoder().decode(RequestAccessState.self, from: Data(contentsOf: file))
    } else {
      saved = nil
    }
    let previous = max(saved?.epoch ?? 0, requestAccess?.epoch ?? 0)
    guard previous >= 0, previous < Int.max else {
      throw CocoaError(.fileReadCorruptFile)
    }
    let state = RequestAccessState(epoch: previous + 1, allowed: allowed,
      contextId: owner?["contextId"] as? String, revision: owner?["revision"] as? Int)
    try JSONEncoder().encode(state).write(
      to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try file.setResourceValues(values)
    requestAccess = state
    requestAccessUnavailable = false
    return state
  }

  private func secureRequestAccessAtLaunch() {
    do {
      _ = try reserveRequestAccess(allowed: false, owner: publication)
    } catch {
      requestAccess = nil
      requestAccessUnavailable = true
      logger.error("Request access publication unavailable")
    }
  }

  private func publishRequestAccess(allowed: Bool, arguments: [String: Any], result: FlutterResult) {
    do {
      let owner = publication
      let context = owner?["contextId"] as? String
      let revision = owner?["revision"] as? Int
      let matches = owner?["usable"] as? Bool == true && context?.isEmpty == false &&
        revision != nil && revision! >= 0 &&
        context == arguments["contextId"] as? String &&
        revision == arguments["revision"] as? Int
      guard !allowed || matches else {
        result(FlutterError(code: "context_changed", message: nil, details: nil))
        return
      }
      let state = try reserveRequestAccess(allowed: allowed, owner: matches ? owner : nil)
      deliverSessionState()
      result(["epoch": state.epoch, "allowed": state.allowed].merging(state.payload) { _, new in new })
    } catch {
      requestAccessUnavailable = true
      deliverSessionState()
      result(FlutterError(code: "unavailable", message: nil, details: nil))
    }
  }

  private var publication: [String: Any]? {
    UserDefaults.standard.dictionary(forKey: "watch.session.publication")
  }

  private func publishSessionState(usable: Bool, arguments: [String: Any], result: FlutterResult) {
    let previous = publication?["revision"] as? Int ?? 0
    let requested = arguments["revision"] as? Int ?? previous + 1
    let unchanged = publication?["usable"] as? Bool == usable && publication?["contextId"] as? String == arguments["contextId"] as? String
    let revision = unchanged ? max(requested, previous) : max(requested, previous + 1)
    var state: [String: Any] = ["revision": revision, "usable": usable]
    if let context = arguments["contextId"] as? String { state["contextId"] = context }
    if let version = arguments["protocolVersion"] as? Int { state["protocolVersion"] = version }
    if publication?["usable"] as? Bool != usable ||
      publication?["contextId"] as? String != state["contextId"] as? String ||
      publication?["revision"] as? Int != revision {
      do {
        _ = try reserveRequestAccess(allowed: false, owner: publication)
      } catch {
        requestAccessUnavailable = true
      }
      deliverSessionState()
    }
    UserDefaults.standard.set(state, forKey: "watch.session.publication")
    deliverSessionState()
    result(state)
  }

  private var requestAccessPayload: [String: Any] {
    guard !requestAccessUnavailable, let access = requestAccess,
      access.contextId?.isEmpty == false, access.revision != nil,
      publication?["usable"] as? Bool == true,
      access.contextId == publication?["contextId"] as? String,
      access.revision == publication?["revision"] as? Int else {
      return ["unavailable": true]
    }
    return access.payload
  }

  private func deliverSessionState() {
    guard WCSession.isSupported(), publication != nil || requestAccess != nil || requestAccessUnavailable else { return }
    let session = WCSession.default
    guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else { return }
    var payload: [String: Any] = [:]
    if let publication { payload["watchSession"] = publication }
    payload["watchRequests"] = requestAccessPayload
    do {
      try session.updateApplicationContext(session.applicationContext.merging(payload) { _, new in new })
      session.transferUserInfo(payload)
    } catch {
      logger.error("Session context failed code=\((error as NSError).code)")
    }
  }

  /// Hands the watch's complications the latest turn's status. Only an
  /// [urgent] one, a change of state, spends the budgeted transfer that wakes
  /// the watch app; anything else, and an urgent one once the budget is spent,
  /// goes as the application context, which the watch reads when it next runs.
  /// The payload's sequence number lets the watch drop what arrives late.
  /// Answers how it went, or `none` when there is no watch to tell.
  private func sendComplication(_ payload: [String: Any], urgent: Bool, result: FlutterResult) {
    guard WCSession.isSupported() else { return result("none") }
    let session = WCSession.default
    guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
      return result("none")
    }
    if urgent, session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 {
      session.transferCurrentComplicationUserInfo(payload)
      return result("complication")
    }
    do {
      try session.updateApplicationContext(session.applicationContext.merging(payload) { _, new in new })
      result("context")
    } catch {
      logger.error("Complication context failed code=\((error as NSError).code)")
      result(FlutterError(code: "complication_failed", message: nil, details: nil))
    }
  }

  func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    DispatchQueue.main.async {
      // A turn can take a minute, and the phone app is often in the background
      // when the watch asks. Without a background task iOS would suspend it
      // mid-turn and the watch would never get an answer.
      var task = UIBackgroundTaskIdentifier.invalid
      var replied = false
      let reply: ([String: Any]) -> Void = { answer in
        guard !replied else { return }
        replied = true
        replyHandler(answer)
        if task != .invalid {
          self.endTask(task)
          task = .invalid
        }
      }
      task = self.beginTask {
        self.logger.error("Background task expired")
        reply(["ok": false, "error": "unavailable"])
      }
      self.invokeRequest(message) { result in
        switch result {
        case let answer as [String: Any]:
          var answer = answer
          if let publication = self.publication { answer["watchSession"] = publication }
          answer["watchRequests"] = self.requestAccessPayload
          reply(answer)
        case let missing as NSObject where missing === FlutterMethodNotImplemented:
          self.logger.error("Dart handler unavailable")
          reply(["ok": false, "error": "unavailable"])
        default:
          self.logger.error("Dart handler returned invalid reply")
          reply(["ok": false, "error": "failed"])
        }
      }
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    DispatchQueue.main.async { self.deliverSessionState() }
    logger.notice("Activation completed state=\(activationState.rawValue) errorCode=\((error as NSError?)?.code ?? 0)")
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
