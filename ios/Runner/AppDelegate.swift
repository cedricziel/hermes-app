import Flutter
import UIKit
import UniformTypeIdentifiers
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
    ClipboardFiles.install(messenger: engineBridge.applicationRegistrar.messenger())
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
