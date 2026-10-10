import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    private var shareChannel: FlutterMethodChannel?
    private var webAuth: WebAuthSession?
    /// Holds the main window while it is closed (hidden), since the outlet is
    /// weak and conversation windows depend on its engine.
    private var mainWindow: NSWindow?
    private var appChannel: FlutterMethodChannel?
    /// Kept while no window is on screen, so App Nap does not slow the timers
    /// and sockets that deliver replies and schedule alerts.
    private var windowlessActivity: NSObjectProtocol?
    private var windowless = false

    /// The "Ask Hermes" entry in the Services menu.
    private let askService = AskHermesService()

    /// The provider must be there before the system delivers a service call,
    /// which it does as soon as it has launched the app for one.
    override func applicationWillFinishLaunching(_ notification: Notification) {
        askService.showWindow = { [weak self] in
            guard let window = self?.mainWindow ?? self?.mainFlutterWindow else { return }
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        askService.notify = { [weak self] in
            self?.shareChannel?.invokeMethod("shared", arguments: nil)
        }
        NSApp.servicesProvider = askService
        NSUpdateDynamicServices()
        super.applicationWillFinishLaunching(notification)
    }

    override func applicationDidFinishLaunching(_ notification: Notification) {
        mainWindow = mainFlutterWindow
        if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(
                name: "hermes_app/share", binaryMessenger: controller.engine.binaryMessenger
            )
            channel.setMethodCallHandler { [weak self] call, result in
                if call.method == "take" {
                    result(ShareHandoff.take() + (self?.askService.takeQueued() ?? []))
                } else {
                    result(FlutterMethodNotImplemented)
                }
            }
            shareChannel = channel
            let app = FlutterMethodChannel(
                name: "hermes_app/app", binaryMessenger: controller.engine.binaryMessenger
            )
            app.setMethodCallHandler { call, result in
                if call.method == "terminate" {
                    // terminate normally does not return, so answer first.
                    result(nil)
                    DispatchQueue.main.async { NSApp.terminate(nil) }
                } else {
                    result(FlutterMethodNotImplemented)
                }
            }
            appChannel = app
            for name in [
                NSWindow.didBecomeKeyNotification, NSWindow.didMiniaturizeNotification,
                NSWindow.didDeminiaturizeNotification, NSWindow.willCloseNotification,
            ] {
                NotificationCenter.default.addObserver(
                    forName: name, object: nil, queue: .main
                ) { [weak self] _ in
                    // A closing window is still visible while it posts this.
                    DispatchQueue.main.async { self?.refreshWindowless() }
                }
            }
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

    /// A click on the Dock icon brings back the main window when it is hidden,
    /// also while conversation windows are open.
    override func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        if let main = mainWindow, !main.isVisible {
            main.makeKeyAndOrderFront(nil)
        }
        return true
    }

    /// A tapped notification activates the app without a reopen event, so a
    /// windowless app would answer the tap with nothing on screen.
    override func applicationDidBecomeActive(_ notification: Notification) {
        super.applicationDidBecomeActive(notification)
        guard let main = mainWindow, !main.isMiniaturized, !NSApp.isHidden else { return }
        if !NSApp.windows.contains(where: { $0.isVisible && $0.canBecomeMain }) {
            main.makeKeyAndOrderFront(nil)
        }
    }

    /// Whether any window is on screen or in the Dock; with none, the app
    /// runs windowless. Takes the App Nap hold and tells the Dart side on a
    /// change, so a crash report and the Schedules page know.
    func refreshWindowless() {
        let none = !NSApp.isHidden
            && !NSApp.windows.contains { ($0.isVisible || $0.isMiniaturized) && $0.canBecomeMain }
        guard none != windowless else { return }
        windowless = none
        if none {
            windowlessActivity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Hermes keeps running replies and schedule checks without a window"
            )
        } else if let activity = windowlessActivity {
            ProcessInfo.processInfo.endActivity(activity)
            windowlessActivity = nil
        }
        appChannel?.invokeMethod("windowless", arguments: none)
    }

    /// Closing the last window leaves the app running with its Dock icon;
    /// Cmd-Q and the Quit menu item still end it. The main window is hidden,
    /// not released, so its engine keeps serving replies and schedule checks.
    override func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        return false
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
