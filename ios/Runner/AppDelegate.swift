import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var watchRelay: WatchRelay?
  private var webAuth: WebAuthSession?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets a notification show while the app is in the foreground and lets a tap reach Flutter.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    ChatHandoff.shared.install(messenger: engineBridge.applicationRegistrar.messenger())
    LiveActivityLaunch.shared.install(messenger: engineBridge.applicationRegistrar.messenger())
    watchRelay = WatchRelay(messenger: engineBridge.applicationRegistrar.messenger())
    webAuth = WebAuthSession(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

class ChatHandoff {
  static let shared = ChatHandoff()
  static var activityType: String {
    (Bundle.main.object(forInfoDictionaryKey: "NSUserActivityTypes") as? [String])?.first ?? "com.cedricziel.hermesApp.continueChat.dev"
  }
  private var activity: NSUserActivity?
  private var pending: [AnyHashable: Any]?
  private var channel: FlutterMethodChannel?

  func install(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "hermes_app/handoff", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "take":
        result(self.take())
      case "clear":
        self.activity?.invalidate()
        self.activity = nil
        result(nil)
      case "publish":
        self.activity?.invalidate()
        let next = NSUserActivity(activityType: Self.activityType)
        next.title = "Continue chat in Hermes"
        next.userInfo = call.arguments as? [AnyHashable: Any]
        next.requiredUserInfoKeys = ["version", "serverUrl", "profile", "threadId"]
        next.isEligibleForHandoff = true
        next.isEligibleForSearch = false
        next.isEligibleForPublicIndexing = false
        self.activity = next
        next.becomeCurrent()
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func take() -> [AnyHashable: Any]? {
    defer { pending = nil }
    return pending
  }

  func receive(_ activity: NSUserActivity) -> Bool {
    guard activity.activityType == Self.activityType else { return false }
    pending = activity.userInfo ?? ["error": true]
    channel?.invokeMethod("incoming", arguments: nil)
    return true
  }

  func failed(_ type: String) {
    guard type == Self.activityType else { return }
    pending = ["error": true]
    channel?.invokeMethod("incoming", arguments: nil)
  }
}

/// The URL of the Live Activity tap that launched the app, handed to Dart once.
class LiveActivityLaunch {
  static let shared = LiveActivityLaunch()
  private var url: URL?

  func install(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "hermes_app/live_activity", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "takeLaunchUrl" else { result(FlutterMethodNotImplemented); return }
      result(self?.url?.absoluteString)
      self?.url = nil
    }
  }

  func receive(_ contexts: Set<UIOpenURLContext>) {
    url = contexts.map(\.url).first { $0.scheme == "hermes-activity" }
  }
}
