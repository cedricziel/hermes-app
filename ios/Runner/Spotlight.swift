import CoreSpotlight
import Flutter
import UniformTypeIdentifiers

/// Puts items in Spotlight for Dart, over the `hermes_app/spotlight` channel,
/// and hands Dart the link of a result the user tapped.
///
/// - `replace(domain, items)` makes `items` (`url`, `title`, `text`) the whole
///   of `hermes.<domain>`.
/// - `update(domain, items, remove)` adds or changes `items` and removes the
///   items whose links are in `remove`, leaving the rest of the domain.
/// - `deleteDomain(domain)` and `deleteAll()` remove items.
/// - `isAvailable()` answers whether the protected files can be read, which
///   they cannot while the device is locked.
/// - `take()` answers the tapped link once, `nil` after that.
/// - `opened` is sent to Dart when a result was tapped, for it to `take`.
/// - `becameAvailable` is sent to Dart when the device is unlocked or the app
///   comes to the front, for it to catch up on what it could not index.
///
/// The item's identifier is its `hermes://` link, since Spotlight hands back
/// only the identifier. The index is named and completely protected, so its
/// items are not searchable while the device is locked.
final class Spotlight {
  static let shared = Spotlight()
  static let channelName = "hermes_app/spotlight"

  private let index = CSSearchableIndex(name: "hermes", protectionClass: .complete)
  private var channel: FlutterMethodChannel?
  private var pending: String?
  private var observing = false

  private func domainIdentifier(_ domain: String) -> String { "hermes.\(domain)" }

  func install(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    self.channel = channel
    if !observing {
      observing = true
      for name in [UIApplication.protectedDataDidBecomeAvailableNotification, UIApplication.didBecomeActiveNotification] {
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          self?.channel?.invokeMethod("becameAvailable", arguments: nil)
        }
      }
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      let arguments = call.arguments as? [String: Any]
      switch call.method {
      case "replace":
        guard let domain = arguments?["domain"] as? String,
          let items = arguments?["items"] as? [[String: String]]
        else { return result(FlutterError(code: "bad_arguments", message: nil, details: nil)) }
        self.replace(domain: domain, items: items, result: result)
      case "update":
        guard let domain = arguments?["domain"] as? String,
          let items = arguments?["items"] as? [[String: String]],
          let remove = arguments?["remove"] as? [String]
        else { return result(FlutterError(code: "bad_arguments", message: nil, details: nil)) }
        self.update(domain: domain, items: items, remove: remove, result: result)
      case "isAvailable":
        result(UIApplication.shared.isProtectedDataAvailable)
      case "deleteDomain":
        guard let domain = arguments?["domain"] as? String else {
          return result(FlutterError(code: "bad_arguments", message: nil, details: nil))
        }
        self.index.deleteSearchableItems(withDomainIdentifiers: [self.domainIdentifier(domain)]) {
          Self.answer($0, result)
        }
      case "deleteAll":
        self.index.deleteAllSearchableItems { Self.answer($0, result) }
      case "take":
        result(self.pending)
        self.pending = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func answer(_ error: Error?, _ result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      if let error {
        result(FlutterError(code: "index_failed", message: error.localizedDescription, details: nil))
      } else {
        result(nil)
      }
    }
  }

  private func searchableItems(_ items: [[String: String]], domain: String) -> [CSSearchableItem] {
    items.compactMap { item -> CSSearchableItem? in
      guard let url = item["url"], let title = item["title"] else { return nil }
      let attributes = CSSearchableItemAttributeSet(contentType: .text)
      attributes.title = title
      attributes.displayName = title
      attributes.contentDescription = item["text"]
      return CSSearchableItem(uniqueIdentifier: url, domainIdentifier: domainIdentifier(domain), attributeSet: attributes)
    }
  }

  private func replace(domain: String, items: [[String: String]], result: @escaping FlutterResult) {
    let searchable = searchableItems(items, domain: domain)
    index.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier(domain)]) { [index] error in
      if let error { return Self.answer(error, result) }
      if searchable.isEmpty { return Self.answer(nil, result) }
      index.indexSearchableItems(searchable) { Self.answer($0, result) }
    }
  }

  /// Indexing an item whose identifier is already there replaces it, so the
  /// unchanged items are never touched and the domain is never empty.
  private func update(domain: String, items: [[String: String]], remove: [String], result: @escaping FlutterResult) {
    let searchable = searchableItems(items, domain: domain)
    let removeDropped = { [index] (error: Error?) in
      if let error { return Self.answer(error, result) }
      if remove.isEmpty { return Self.answer(nil, result) }
      index.deleteSearchableItems(withIdentifiers: remove) { Self.answer($0, result) }
    }
    if searchable.isEmpty { return removeDropped(nil) }
    index.indexSearchableItems(searchable, completionHandler: removeDropped)
  }

  /// Takes a tap on a result. Anything but a `hermes` link is dropped, so a
  /// stale item can never open something else.
  func receive(_ activity: NSUserActivity) -> Bool {
    guard activity.activityType == CSSearchableItemActionType else { return false }
    guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
      URL(string: identifier)?.scheme == "hermes"
    else { return true }
    pending = identifier
    channel?.invokeMethod("opened", arguments: nil)
    return true
  }
}
