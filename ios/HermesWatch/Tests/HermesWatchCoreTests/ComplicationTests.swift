import XCTest

@testable import HermesWatchCore

final class ComplicationUpdateTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_000_000)

  func testAWorkingChatDecodes() {
    let update = ComplicationUpdate(
      payload: ["v": 1, "state": "working", "updatedAt": 999_000, "title": "Backup", "threadId": "w/s1"],
      now: now)

    XCTAssertEqual(
      update,
      .show(
        ComplicationStatus(
          state: .working, updatedAt: Date(timeIntervalSince1970: 999_000), title: "Backup", threadId: "w/s1")))
  }

  func testEveryStateDecodes() {
    for state in ["working", "waiting", "ready", "failed"] {
      let update = ComplicationUpdate(payload: ["v": 1, "state": state, "updatedAt": 1], now: now)

      guard case .show(let status) = update else { return XCTFail("\(state) was not shown") }
      XCTAssertEqual(status.state.rawValue, state)
    }
  }

  func testNoneClears() {
    XCTAssertEqual(ComplicationUpdate(payload: ["v": 1, "state": "none"], now: now), .clear)
  }

  func testAStateWithoutATitleOrChatIsStillShown() {
    let update = ComplicationUpdate(payload: ["v": 1, "state": "ready", "updatedAt": 5], now: now)

    guard case .show(let status) = update else { return XCTFail("not shown") }
    XCTAssertNil(status.title)
    XCTAssertNil(status.threadId)
  }

  func testABlankTitleOrChatIsDropped() {
    let update = ComplicationUpdate(
      payload: ["v": 1, "state": "ready", "updatedAt": 5, "title": "  ", "threadId": ""], now: now)

    guard case .show(let status) = update else { return XCTFail("not shown") }
    XCTAssertNil(status.title)
    XCTAssertNil(status.threadId)
  }

  func testAMissingTimeIsNow() {
    let update = ComplicationUpdate(payload: ["v": 1, "state": "working"], now: now)

    guard case .show(let status) = update else { return XCTFail("not shown") }
    XCTAssertEqual(status.updatedAt, now)
  }

  func testWhatItDoesNotUnderstandIsIgnored() {
    XCTAssertNil(ComplicationUpdate(payload: ["v": 1, "state": "dancing"], now: now))
    XCTAssertNil(ComplicationUpdate(payload: ["v": 2, "state": "working"], now: now))
    XCTAssertNil(ComplicationUpdate(payload: ["state": "working"], now: now))
    XCTAssertNil(ComplicationUpdate(payload: [:], now: now))
  }

  func testEachStateHasItsWord() {
    XCTAssertEqual(ComplicationStatus.State.working.label, "Working")
    XCTAssertEqual(ComplicationStatus.State.waiting.label, "Waiting for you")
    XCTAssertEqual(ComplicationStatus.State.ready.label, "Reply ready")
    XCTAssertEqual(ComplicationStatus.State.failed.label, "Failed")
  }
}

final class ComplicationStoreTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suite: String!

  override func setUp() {
    suite = "complication-tests-\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suite)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suite)
  }

  private func status(_ state: ComplicationStatus.State = .working, title: String? = "Backup", threadId: String? = "w/s1")
    -> ComplicationStatus
  {
    ComplicationStatus(state: state, updatedAt: Date(timeIntervalSince1970: 500), title: title, threadId: threadId)
  }

  func testNothingIsStoredAtFirst() {
    XCTAssertNil(ComplicationStore(defaults: defaults).status())
  }

  func testAShownStatusIsKeptForTheWidget() {
    ComplicationStore(defaults: defaults).apply(.show(status()))

    XCTAssertEqual(ComplicationStore(defaults: defaults).status(), status())
  }

  func testAClearForgetsIt() {
    let store = ComplicationStore(defaults: defaults)
    store.apply(.show(status()))

    store.apply(.clear)

    XCTAssertNil(store.status())
  }

  func testALaterStatusReplacesTheEarlierOne() {
    let store = ComplicationStore(defaults: defaults)
    store.apply(.show(status(.working)))

    store.apply(.show(status(.ready)))

    XCTAssertEqual(store.status()?.state, .ready)
  }

  func testAnUnnamedChatTakesTheTitleTheWatchSaved() {
    let store = ComplicationStore(defaults: defaults)

    store.apply(.show(status(title: nil, threadId: "w/s1")), savedTitle: { $0 == "w/s1" ? "Trip" : nil })

    XCTAssertEqual(store.status()?.title, "Trip")
  }

  func testAChatWithATitleKeepsIt() {
    let store = ComplicationStore(defaults: defaults)

    store.apply(.show(status(title: "Backup")), savedTitle: { _ in "Other" })

    XCTAssertEqual(store.status()?.title, "Backup")
  }

  func testAChatWithoutAnIdHasNoSavedTitleToTake() {
    let store = ComplicationStore(defaults: defaults)

    store.apply(.show(status(title: nil, threadId: nil)), savedTitle: { _ in "Trip" })

    XCTAssertNil(store.status()?.title)
  }

  func testGarbageInTheStoreIsNoStatus() {
    defaults.set(Data("nonsense".utf8), forKey: ComplicationStore.key)

    XCTAssertNil(ComplicationStore(defaults: defaults).status())
  }
}

final class ComplicationTimelineTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_000_000)

  private func status(_ state: ComplicationStatus.State, age: TimeInterval) -> ComplicationStatus {
    ComplicationStatus(state: state, updatedAt: now.addingTimeInterval(-age), title: "Backup", threadId: "w/s1")
  }

  func testNothingToShowIsOneQuietEntry() {
    let plan = ComplicationTimeline.plan(for: nil, now: now)

    XCTAssertEqual(plan, [ComplicationEntry(date: now, status: nil, relevance: 0, duration: nil)])
  }

  func testAChatWaitingForTheUserIsTheMostRelevant() {
    let plan = ComplicationTimeline.plan(for: status(.waiting, age: 60), now: now)

    XCTAssertEqual(plan.first?.relevance, 1.0)
    XCTAssertEqual(plan.first?.status?.state, .waiting)
    XCTAssertGreaterThan(plan.first?.relevance ?? 0, ComplicationTimeline.plan(for: status(.working, age: 60), now: now)[0].relevance)
  }

  func testAWorkingChatIsModeratelyRelevant() {
    let plan = ComplicationTimeline.plan(for: status(.working, age: 60), now: now)

    XCTAssertEqual(plan.first?.relevance, 0.5)
  }

  func testWorkingAndWaitingFadeAfterHalfAnHourWithoutNews() {
    for state in [ComplicationStatus.State.working, .waiting] {
      let plan = ComplicationTimeline.plan(for: status(state, age: 60), now: now)

      XCTAssertEqual(plan.count, 2)
      XCTAssertEqual(plan[0].duration, 29 * 60)
      XCTAssertEqual(plan[1].date, now.addingTimeInterval(29 * 60))
      XCTAssertNil(plan[1].status)
      XCTAssertEqual(plan[1].relevance, 0)
    }
  }

  func testAStaleWorkingChatIsNotShown() {
    for state in [ComplicationStatus.State.working, .waiting] {
      let plan = ComplicationTimeline.plan(for: status(state, age: 31 * 60), now: now)

      XCTAssertEqual(plan, [ComplicationEntry(date: now, status: nil, relevance: 0, duration: nil)])
    }
  }

  func testAFreshReplyRisesInTheStackForTenMinutes() {
    for state in [ComplicationStatus.State.ready, .failed] {
      let plan = ComplicationTimeline.plan(for: status(state, age: 120), now: now)

      XCTAssertEqual(plan.count, 3)
      XCTAssertEqual(plan[0].relevance, 0.8)
      XCTAssertEqual(plan[0].duration, 8 * 60)
      XCTAssertEqual(plan[1].date, now.addingTimeInterval(8 * 60))
      XCTAssertEqual(plan[1].status?.state, state)
      XCTAssertEqual(plan[1].relevance, 0.1)
      XCTAssertEqual(plan[2].date, now.addingTimeInterval(6 * 3600 - 120))
      XCTAssertNil(plan[2].status)
    }
  }

  func testAnOlderReplyStaysButBarelyRanks() {
    let plan = ComplicationTimeline.plan(for: status(.ready, age: 3600), now: now)

    XCTAssertEqual(plan.count, 2)
    XCTAssertEqual(plan[0].relevance, 0.1)
    XCTAssertEqual(plan[0].status?.state, .ready)
    XCTAssertNil(plan[1].status)
  }

  func testAVeryOldReplyIsNotShown() {
    let plan = ComplicationTimeline.plan(for: status(.ready, age: 7 * 3600), now: now)

    XCTAssertEqual(plan, [ComplicationEntry(date: now, status: nil, relevance: 0, duration: nil)])
  }

  func testAStatusFromTheFutureCountsAsJustNow() {
    let early = ComplicationStatus(
      state: .waiting, updatedAt: now.addingTimeInterval(120), title: nil, threadId: nil)

    let plan = ComplicationTimeline.plan(for: early, now: now)

    XCTAssertEqual(plan[0].duration, 30 * 60)
  }

  func testEntriesNeverGoBackInTime() {
    for age in [0.0, 60, 599, 600, 601, 3600, 21_599, 21_600] {
      for state in [ComplicationStatus.State.working, .waiting, .ready, .failed] {
        let dates = ComplicationTimeline.plan(for: status(state, age: age), now: now).map(\.date)

        XCTAssertEqual(dates, dates.sorted(), "\(state) at \(age)")
        XCTAssertEqual(dates.first, now)
      }
    }
  }
}

final class ComplicationLinkTests: XCTestCase {
  func testEveryLinkSurvivesTheUrl() throws {
    let links: [ComplicationLink] = [
      .voice,
      .open,
      .chat(id: "wör k/s1&x=y", title: "Why is 100% of it slow? #1"),
    ]

    for link in links {
      let url = try XCTUnwrap(link.url)
      XCTAssertEqual(url.scheme, "hermes-watch")
      XCTAssertEqual(ComplicationLink(url: url), link)
    }
  }

  func testAChatWithoutATitleHasNoTitleToCarry() throws {
    let url = try XCTUnwrap(ComplicationLink.chat(id: "w/s1", title: nil).url)

    XCTAssertEqual(ComplicationLink(url: url), .chat(id: "w/s1", title: nil))
  }

  func testOtherUrlsAreNotOurs() throws {
    XCTAssertNil(ComplicationLink(url: try XCTUnwrap(URL(string: "https://example.com/voice"))))
    XCTAssertNil(ComplicationLink(url: try XCTUnwrap(URL(string: "hermes-watch://dance"))))
    XCTAssertNil(ComplicationLink(url: try XCTUnwrap(URL(string: "hermes-watch://chat"))))
  }
}
