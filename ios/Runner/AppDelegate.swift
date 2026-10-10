import Flutter
import UIKit
import UniformTypeIdentifiers
import UserNotifications
import flutter_local_notifications

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
    // The engine the plugin starts for a notification button that answers in
    // the background, without opening the app.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
      BackgroundTask.install(registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    NotificationCategories.install(messenger: engineBridge.applicationRegistrar.messenger())
    ChatHandoff.shared.install(messenger: engineBridge.applicationRegistrar.messenger())
    LiveActivityLaunch.shared.install(messenger: engineBridge.applicationRegistrar.messenger())
    watchRelay = WatchRelay(messenger: engineBridge.applicationRegistrar.messenger())
    webAuth = WebAuthSession(messenger: engineBridge.applicationRegistrar.messenger())
    ClipboardFiles.install(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// Registers the request notification categories with their hidden-preview
/// placeholders, which flutter_local_notifications cannot set. Every launch
/// the plugin replaces the whole set, so the categories made for single
/// questions are remembered and added again, or a question still on screen
/// would lose its buttons.
enum NotificationCategories {
  private static let rememberedKey = "hermes.requestCategories"
  private static let questionPrefix = "hermes.request.question."
  private static let remembered = 20

  static func install(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "hermes_app/notification_categories", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "register",
          let specs = (call.arguments as? [String: Any])?["categories"] as? [[String: Any]]
        else { result(FlutterMethodNotImplemented); return }
        register(specs) { result(nil) }
      }
  }

  static func register(_ specs: [[String: Any]], done: @escaping () -> Void) {
    let defaults = UserDefaults.standard
    var kept = defaults.array(forKey: rememberedKey) as? [[String: Any]] ?? []
    let questions = specs.filter { ($0["id"] as? String)?.hasPrefix(questionPrefix) == true }
    let ids = Set(questions.compactMap { $0["id"] as? String })
    kept.removeAll { ids.contains($0["id"] as? String ?? "") }
    kept = Array((kept + questions).suffix(remembered))
    defaults.set(kept, forKey: rememberedKey)
    let center = UNUserNotificationCenter.current()
    center.getNotificationCategories { current in
      var byId = [String: UNNotificationCategory]()
      for category in current { byId[category.identifier] = category }
      for spec in kept + specs {
        if let category = category(spec) { byId[category.identifier] = category }
      }
      center.setNotificationCategories(Set(byId.values))
      DispatchQueue.main.async(execute: done)
    }
  }

  private static func category(_ spec: [String: Any]) -> UNNotificationCategory? {
    guard let id = spec["id"] as? String else { return nil }
    let actions: [UNNotificationAction] = (spec["actions"] as? [[String: Any]] ?? []).compactMap { action in
      guard let id = action["id"] as? String, let title = action["title"] as? String else { return nil }
      let options = UNNotificationActionOptions(rawValue: (action["options"] as? NSNumber)?.uintValue ?? 0)
      if let button = action["buttonTitle"] as? String {
        return UNTextInputNotificationAction(
          identifier: id, title: title, options: options,
          textInputButtonTitle: button,
          textInputPlaceholder: action["placeholder"] as? String ?? "")
      }
      return UNNotificationAction(identifier: id, title: title, options: options)
    }
    return UNNotificationCategory(
      identifier: id, actions: actions, intentIdentifiers: [],
      hiddenPreviewsBodyPlaceholder: spec["placeholder"] as? String ?? "",
      options: [])
  }
}

/// Lets the background isolate keep the app awake while it sends an answer:
/// the plugin calls the system's completion handler before Dart runs.
enum BackgroundTask {
  static func install(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "HermesBackgroundTask") else { return }
    FlutterMethodChannel(name: "hermes_app/background_task", binaryMessenger: registrar.messenger())
      .setMethodCallHandler { call, result in
        switch call.method {
        case "begin":
          var task = UIBackgroundTaskIdentifier.invalid
          task = UIApplication.shared.beginBackgroundTask(withName: "notification-answer") {
            UIApplication.shared.endBackgroundTask(task)
          }
          result(task.rawValue)
        case "end":
          if let raw = call.arguments as? Int {
            UIApplication.shared.endBackgroundTask(UIBackgroundTaskIdentifier(rawValue: raw))
          }
          result(nil)
        default: result(FlutterMethodNotImplemented)
        }
      }
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

/// Lets the composer paste images and files, which Flutter's clipboard
/// cannot: `hasFiles` looks at the types only, so iOS does not ask the user,
/// and `read` copies each item into a temporary file.
enum ClipboardFiles {
  static func install(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "hermes_app/clipboard", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        switch call.method {
        case "hasFiles": result(hasFiles(.general))
        case "read": read(.general) { result($0) }
        default: result(FlutterMethodNotImplemented)
        }
      }
  }

  static func hasFiles(_ pasteboard: UIPasteboard) -> Bool {
    if pasteboard.hasImages { return true }
    // Text, even with a file type beside it, is pasted as text.
    if pasteboard.hasStrings || pasteboard.hasURLs { return false }
    return pasteboard.types.contains { fileType($0) != nil }
  }

  /// [path, name?, mimeType?] for each item that holds an image or a file.
  static func read(_ pasteboard: UIPasteboard, done: @escaping ([[String: String]]) -> Void) {
    let images = pasteboard.hasImages
    let providers = pasteboard.itemProviders
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("pasted", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    var files = [[String: String]?](repeating: nil, count: providers.count)
    let lock = NSLock()
    let group = DispatchGroup()
    for (index, provider) in providers.enumerated() {
      let types = provider.registeredTypeIdentifiers.compactMap(fileType)
      guard let type = types.first(where: { $0.conforms(to: .image) })
        ?? (images ? nil : types.first)
      else { continue }
      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
        defer { group.leave() }
        guard let url else { return }
        let ext = type.preferredFilenameExtension ?? url.pathExtension
        var name = provider.suggestedName
        if let base = name, !ext.isEmpty, (base as NSString).pathExtension.isEmpty {
          name = "\(base).\(ext)"
        }
        let target = folder.appendingPathComponent(
          name ?? (ext.isEmpty ? "pasted-\(index)" : "pasted-\(index).\(ext)"))
        do {
          try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
          try? FileManager.default.removeItem(at: target)
          // The provider deletes its file once this handler returns.
          try FileManager.default.copyItem(at: url, to: target)
        } catch {
          return
        }
        var file = ["path": target.path]
        file["name"] = name
        file["mimeType"] = type.preferredMIMEType
        lock.withLock { files[index] = file }
      }
    }
    group.notify(queue: .main) { done(files.compactMap { $0 }) }
  }

  /// The type of a file or image, or nil for text, links and types this
  /// system does not know.
  private static func fileType(_ identifier: String) -> UTType? {
    guard let type = UTType(identifier), !type.isDynamic,
      type.conforms(to: .data),
      !type.conforms(to: .text), !type.conforms(to: .url),
      !type.conforms(to: .rtfd), !type.conforms(to: .flatRTFD)
    else { return nil }
    return type
  }
}
