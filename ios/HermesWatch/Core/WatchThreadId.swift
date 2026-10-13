import Foundation

struct WatchThreadId: Equatable {
  let contextId: String
  let profile: String?
  let sessionId: String

  func encode() -> String {
    let tuple: [Any] = [contextId, profile as Any? ?? NSNull(), sessionId]
    let data = try! JSONSerialization.data(withJSONObject: tuple, options: [.withoutEscapingSlashes])
    return "v2/" + data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
  }

  static func decode(_ value: String) -> WatchThreadId? {
    guard value.hasPrefix("v2/") else { return nil }
    var encoded = String(value.dropFirst(3)).replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
    guard let data = Data(base64Encoded: encoded),
      let tuple = try? JSONSerialization.jsonObject(with: data) as? [Any], tuple.count == 3,
      let context = tuple[0] as? String, !context.isEmpty,
      tuple[1] is NSNull || tuple[1] is String,
      let session = tuple[2] as? String, !session.isEmpty else { return nil }
    return WatchThreadId(contextId: context, profile: tuple[1] as? String, sessionId: session)
  }
}
