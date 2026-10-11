import CoreSpotlight
import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

final class Spotlight {
  static let shared = Spotlight()
  static let channelName = "hermes_app/spotlight"

  private let index = CSSearchableIndex(name: "hermes")
  private var channel: FlutterMethodChannel?
  private var pending: String?
  private var observing = false

  private func domainIdentifier(_ domain: String) -> String { "hermes.\(domain)" }

  func install(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    self.channel = channel
    if !observing {
      observing = true
      NotificationCenter.default.addObserver(
        forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
      ) { [weak self] _ in
        self?.channel?.invokeMethod("becameAvailable", arguments: nil)
      }
    }
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      self.handle(call, result)
    }
  }

  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
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
      result(CSSearchableIndex.isIndexingAvailable())
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
      result(self.take())
    default:
      result(FlutterMethodNotImplemented)
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

  func take() -> String? {
    defer { pending = nil }
    return pending
  }

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
