import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    private var shareChannel: FlutterMethodChannel?
    private var webAuth: WebAuthSession?
    /// Holds the main window while it is closed (hidden), since the outlet is
    /// weak and conversation windows depend on its engine.
    private var mainWindow: NSWindow?

    override func applicationDidFinishLaunching(_ notification: Notification) {
        mainWindow = mainFlutterWindow
        if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: "hermes_app/share", binaryMessenger: controller.engine.binaryMessenger
            )
            channel.setMethodCallHandler { call, result in
                if call.method == "take" {
                    result(ShareHandoff.take())
                } else {
                    result(FlutterMethodNotImplemented)
                }
            }
            shareChannel = channel
            webAuth = WebAuthSession(messenger: controller.engine.binaryMessenger)
            ChatHandoff.shared.install(messenger: controller.engine.binaryMessenger)
        }
        super.applicationDidFinishLaunching(notification)
    }

    /// The share extension opens `hermes-share://share` once it has left the
    /// content in the App Group container.
    override func application(_: NSApplication, open urls: [URL]) {
        if urls.contains(where: { $0.scheme == ShareHandoff.urlScheme }) {
            shareChannel?.invokeMethod("shared", arguments: nil)
        }
    }

    override func application(_ application: NSApplication, continue userActivity: NSUserActivity,
                              restorationHandler: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool {
        if ChatHandoff.shared.receive(userActivity) { return true }
        return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }

    override func application(_ application: NSApplication, didFailToContinueUserActivityWithType type: String, error: Error) {
        ChatHandoff.shared.failed(type)
        super.application(application, didFailToContinueUserActivityWithType: type, error: error)
    }

    /// A click on the Dock icon with every window closed brings the main window
    /// back.
    override func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            mainWindow?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        return true
    }

    override func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        return true
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
