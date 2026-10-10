import CoreSpotlight
import Flutter
import UniformTypeIdentifiers

/// Puts items in Spotlight for Dart, over the `hermes_app/spotlight` channel,
/// and hands Dart the link of a result the user tapped.
///
/// - `replace(domain, items)` makes `items` (`url`, `title`, `text`) the whole
///   of `hermes.<domain>`.
/// - `deleteDomain(domain)` and `deleteAll()` remove items.
/// - `take()` answers the tapped link once, `nil` after that.
/// - `opened` is sent to Dart when a result was tapped, for it to `take`.
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

  private func domainIdentifier(_ domain: String) -> String { "hermes.\(domain)" }

  func install(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      let arguments = call.arguments as? [String: Any]
      switch call.method {
      case "replace":
        guard let domain = arguments?["domain"] as? String,
          let items = arguments?["items"] as? [[String: String]]
        else { return result(FlutterError(code: "bad_arguments", message: nil, details: nil)) }
        self.replace(domain: domain, items: items, result: result)
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

  private func replace(domain: String, items: [[String: String]], result: @escaping FlutterResult) {
    let identifier = domainIdentifier(domain)
    let searchable = items.compactMap { item -> CSSearchableItem? in
      guard let url = item["url"], let title = item["title"] else { return nil }
      let attributes = CSSearchableItemAttributeSet(contentType: .text)
      attributes.title = title
      attributes.displayName = title
      attributes.contentDescription = item["text"]
      return CSSearchableItem(uniqueIdentifier: url, domainIdentifier: identifier, attributeSet: attributes)
    }
    index.deleteSearchableItems(withDomainIdentifiers: [identifier]) { [index] error in
      if let error { return Self.answer(error, result) }
      if searchable.isEmpty { return Self.answer(nil, result) }
      index.indexSearchableItems(searchable) { Self.answer($0, result) }
    }
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
