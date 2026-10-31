import AuthenticationServices
import Cocoa
import FlutterMacOS

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
            start(url: url, callbackScheme: scheme, retries: 1, result: result)
        case "cancel":
            // Also ends a start still waiting to try again.
            generation += 1
            close()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Answers `result` with whether the sheet is showing. AuthenticationServices
    /// refuses a session while an earlier one is still closing, so a refused
    /// start is tried again a moment later, `retries` times.
    private func start(url: URL, callbackScheme: String, retries: Int, result: @escaping FlutterResult) {
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
        if session.start() {
            result(true)
            return
        }
        self.session = nil
        guard retries > 0 else {
            result(false)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            // Cancelled, or replaced by a newer start, meanwhile.
            guard let self, self.generation == id else {
                result(false)
                return
            }
            self.start(url: url, callbackScheme: callbackScheme, retries: retries - 1, result: result)
        }
    }

    private func close() {
        let open = session
        session = nil
        open?.cancel()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // The sheet needs a window on screen. The hidden main window and the
        // menu bar item's window are not.
        return NSApp.keyWindow
            ?? NSApp.mainWindow
            ?? NSApp.windows.first { $0.isVisible && $0.canBecomeKey }
            ?? ASPresentationAnchor()
    }
}
