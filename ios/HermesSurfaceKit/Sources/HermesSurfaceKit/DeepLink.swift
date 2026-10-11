import Foundation

/// The `hermes://` links a widget, intent or other native surface opens the
/// app with. They are built exactly as the app's `deepLinkUri` builds them: a
/// Dart test writes `Tests/Fixtures/deep_links.json` from it and the Swift
/// tests match every case. Every link a native target builds comes from here.
public enum DeepLink {
  public static func chat(profile: String? = nil, id: String, prompt: String? = nil) -> URL {
    link("chat", [("profile", profile), ("id", id), ("prompt", prompt)])
  }

  public static func newChat(profile: String? = nil, dictate: Bool = false, prompt: String? = nil)
    -> URL
  {
    link("new", [("profile", profile), ("dictate", dictate ? "1" : nil), ("prompt", prompt)])
  }

  public static func schedules(profile: String? = nil, job: String? = nil) -> URL {
    link("schedules", [("profile", profile), ("job", job)])
  }

  /// The chat of the oldest open request, else the chat list.
  public static let requests = link("requests", [])
  public static let kanban = link("kanban", [])

  // Dart's Uri.encodeComponent leaves only these alone, so a space is "%20"
  // and a plus "%2B" (a reader may take a "+" in a query for a space).
  static let unreserved = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")

  private static func link(_ host: String, _ parameters: [(String, String?)]) -> URL {
    let pairs = parameters.compactMap { name, value -> String? in
      guard let value else { return nil }
      return "\(name)=\(value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "")"
    }
    let query = pairs.isEmpty ? "" : "?" + pairs.joined(separator: "&")
    return URL(string: "hermes://\(host)\(query)")!
  }
}
