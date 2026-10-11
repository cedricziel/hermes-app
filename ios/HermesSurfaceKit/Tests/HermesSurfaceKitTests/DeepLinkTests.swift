import XCTest

@testable import HermesSurfaceKit

/// One case of `Fixtures/deep_links.json`, which a Dart test writes from the
/// app's `deepLinkUri`.
private struct Case {
  let name: String
  let target: [String: Any]
  let url: String

  var built: URL? {
    func string(_ key: String) -> String? { target[key] as? String }
    switch target["kind"] as? String {
    case "chat":
      guard let id = string("id") else { return nil }
      return DeepLink.chat(profile: string("profile"), id: id, prompt: string("prompt"))
    case "new":
      return DeepLink.newChat(
        profile: string("profile"), dictate: target["dictate"] as? Bool ?? false,
        prompt: string("prompt"))
    case "requests": return DeepLink.requests
    case "kanban": return DeepLink.kanban
    case "schedules": return DeepLink.schedules(profile: string("profile"), job: string("job"))
    default: return nil
    }
  }
}

private func cases() throws -> [Case] {
  let file = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures/deep_links.json")
  let rows = try XCTUnwrap(
    JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [[String: Any]])
  return try rows.map { row in
    Case(
      name: try XCTUnwrap(row["name"] as? String),
      target: try XCTUnwrap(row["target"] as? [String: Any]),
      url: try XCTUnwrap(row["url"] as? String))
  }
}

final class DeepLinkTests: XCTestCase {
  func testBuildsEveryLinkTheAppBuilds() throws {
    let all = try cases()
    XCTAssertEqual(all.count, 21)
    for item in all {
      XCTAssertEqual(item.built?.absoluteString, item.url, item.name)
    }
  }

  func testEncodesAPlusAndASpaceDifferently() {
    XCTAssertEqual(
      DeepLink.newChat(prompt: "a b+c").absoluteString, "hermes://new?prompt=a%20b%2Bc")
  }

  func testLeavesOutParametersThatAreNotSet() {
    XCTAssertEqual(DeepLink.newChat().absoluteString, "hermes://new")
    XCTAssertEqual(DeepLink.chat(profile: nil, id: "abc").absoluteString, "hermes://chat?id=abc")
    XCTAssertEqual(DeepLink.schedules().absoluteString, "hermes://schedules")
  }

  func testTheLinksAreReadBackByURLComponents() throws {
    let link = DeepLink.newChat(profile: "my bot&co", dictate: true, prompt: "C++ & 🚀")
    let items = try XCTUnwrap(URLComponents(url: link, resolvingAgainstBaseURL: false)?.queryItems)
    XCTAssertEqual(items.first { $0.name == "profile" }?.value, "my bot&co")
    XCTAssertEqual(items.first { $0.name == "prompt" }?.value, "C++ & 🚀")
    XCTAssertEqual(items.first { $0.name == "dictate" }?.value, "1")
  }
}
