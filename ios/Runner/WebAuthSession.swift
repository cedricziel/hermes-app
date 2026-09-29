import AuthenticationServices
import Flutter
import UIKit

/// Shows the dashboard's sign-in page in an `ASWebAuthenticationSession` for
/// Dart, over the `hermes_app/web_auth` channel.
///
/// The authorization code still reaches Dart's loopback listener, because
/// Hermes only accepts a `127.0.0.1` redirect. The listener then sends the
/// sheet on to `callbackScheme`, which ends the session on its own.
///
/// - `start(url, callbackScheme)` shows the sheet and answers whether it could.
/// - `cancel()` closes it.
/// - `dismissed` is sent to Dart when the sheet ended without reaching
///   `callbackScheme`, i.e. the user closed it.
final class WebAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
  static let channelName = "hermes_app/web_auth"

  private let channel: FlutterMethodChannel
  private var session: ASWebAuthenticationSession?
  private var generation = 0

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      guard let arguments = call.arguments as? [String: Any],
            let url = (arguments["url"] as? String).flatMap(URL.init(string:)),
            let scheme = arguments["callbackScheme"] as? String
      else {
        result(FlutterError(code: "bad_arguments", message: "start needs url and callbackScheme", details: nil))
        return
      }
      result(start(url: url, callbackScheme: scheme))
    case "cancel":
      close()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(url: URL, callbackScheme: String) -> Bool {
    close()
    generation += 1
    let id = generation
    let session = ASWebAuthenticationSession(
      url: url,
      callback: .customScheme(callbackScheme)
    ) { [weak self] _, error in
      DispatchQueue.main.async {
        // A session closed from Dart, or replaced by a newer one, has nothing to report.
        guard let self, self.generation == id, self.session != nil else { return }
        self.session = nil
        if error != nil { self.channel.invokeMethod("dismissed", arguments: nil) }
      }
    }
    session.presentationContextProvider = self
    self.session = session
    guard session.start() else {
      self.session = nil
      return false
    }
    return true
  }

  private func close() {
    let open = session
    session = nil
    open?.cancel()
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    return scenes.lazy.compactMap(\.keyWindow).first
      ?? scenes.lazy.flatMap(\.windows).first
      ?? ASPresentationAnchor()
  }
}
