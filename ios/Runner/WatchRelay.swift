import Flutter
import UIKit
import WatchConnectivity

/// Passes what the watch app asks for on to Dart over the `app.hermes/watch`
/// channel and sends Dart's answer back. Dart does the network work: it holds
/// the session and knows the dashboard.
final class WatchRelay: NSObject, WCSessionDelegate {
  static let channelName = "app.hermes/watch"

  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    super.init()
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
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
          UIApplication.shared.endBackgroundTask(task)
          task = .invalid
        }
      }
      task = UIApplication.shared.beginBackgroundTask(withName: "watch-relay") {
        reply(["ok": false, "error": "unavailable"])
      }
      self.channel.invokeMethod("request", arguments: message) { result in
        switch result {
        case let answer as [String: Any]:
          reply(answer)
        case let missing as NSObject where missing === FlutterMethodNotImplemented:
          reply(["ok": false, "error": "unavailable"])
        default:
          reply(["ok": false, "error": "failed"])
        }
      }
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
