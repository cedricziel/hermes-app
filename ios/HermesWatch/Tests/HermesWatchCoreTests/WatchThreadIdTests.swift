import XCTest
@testable import HermesWatchCore

final class WatchThreadIdTests: XCTestCase {
  func testDelimiterSafeCodecAndLegacyRejection() {
    let id = WatchThreadId(contextId: "opaque", profile: "a/b%?", sessionId: "s/雪")
    XCTAssertEqual(WatchThreadId.decode(id.encode()), id)
    XCTAssertEqual(id.encode(), "v2/WyJvcGFxdWUiLCJhL2IlPyIsInMv6ZuqIl0")
    XCTAssertNil(WatchThreadId.decode("default/s1"))
    XCTAssertNil(WatchThreadId.decode("v2/W10"))
  }
}
