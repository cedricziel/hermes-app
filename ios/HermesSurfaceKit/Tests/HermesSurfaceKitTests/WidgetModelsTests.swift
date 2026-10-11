import XCTest

@testable import HermesSurfaceKit

private let now = date("2026-10-10T12:00:00Z")

private func link(_ path: String) -> URL { URL(string: "hermes://\(path)")! }

private func chat(
  _ id: String, title: String? = nil, profile: String = "default", snippet: String? = "Snippet",
  minutesAgo: Int = 5
) -> RecentChat {
  RecentChat(
    profile: profile, id: id, title: title ?? "Chat \(id)", snippet: snippet,
    updatedAt: now.addingTimeInterval(TimeInterval(-60 * minutesAgo)),
    url: link("chat?profile=\(profile)&id=\(id)"))
}

private func request(
  _ id: String, kind: PendingKind = .approval, title: String? = nil, profile: String = "default",
  minutesAgo: Int = 10
) -> PendingRequest {
  PendingRequest(
    profile: profile, threadId: id, threadTitle: title ?? "Chat \(id)", kind: kind,
    requestId: "r-\(id)-\(kind.rawValue)",
    createdAt: now.addingTimeInterval(TimeInterval(-60 * minutesAgo)),
    url: link("chat?profile=\(profile)&id=\(id)"))
}

private func snapshot(
  signedIn: Bool = true, updatedAt: Date = now.addingTimeInterval(-60), chats: [RecentChat] = [],
  pending: [PendingRequest] = [], kanban: KanbanSummary? = nil, schedules: ScheduleSummary? = nil
) -> SurfaceSnapshot {
  SurfaceSnapshot(
    updatedAt: updatedAt, signedIn: signedIn, profile: "default", profiles: ["default"],
    recentChats: chats, pending: pending, kanban: kanban, schedules: schedules)
}

final class WidgetStatusTests: XCTestCase {
  func testNoSnapshotOrSignedOutReadsSignedOut() {
    XCTAssertTrue(WidgetStatus(snapshot: nil, now: now).isSignedOut)
    XCTAssertTrue(WidgetStatus(snapshot: snapshot(signedIn: false), now: now).isSignedOut)
    XCTAssertFalse(WidgetStatus(snapshot: snapshot(), now: now).isSignedOut)
  }

  func testStaleAfterSixHours() {
    func status(hoursAgo: Double) -> WidgetStatus {
      WidgetStatus(snapshot: snapshot(updatedAt: now.addingTimeInterval(-hoursAgo * 3600)), now: now)
    }
    XCTAssertFalse(status(hoursAgo: 5.9).isStale)
    XCTAssertTrue(status(hoursAgo: 6.1).isStale)
    XCTAssertTrue(status(hoursAgo: 7).isStale)
  }

  func testSignedOutIsNotAlsoStale() {
    let old = snapshot(signedIn: false, updatedAt: now.addingTimeInterval(-86400))
    XCTAssertFalse(WidgetStatus(snapshot: old, now: now).isStale)
  }
}

final class RecentChatsModelTests: XCTestCase {
  private let chats = (1...8).map { chat("c\($0)", minutesAgo: $0) }

  func testRowsPerFamily() {
    func rows(_ family: SurfaceFamily) -> [String] {
      RecentChatsModel(snapshot: snapshot(chats: chats), family: family, now: now).rows.map(\.id)
    }
    XCTAssertEqual(rows(.small).count, 1)
    XCTAssertEqual(rows(.medium).count, 3)
    XCTAssertEqual(rows(.large).count, 6)
    XCTAssertEqual(rows(.medium), ["default/c1", "default/c2", "default/c3"])
  }

  func testProfileShownOnlyWithSeveralProfiles() {
    let one = RecentChatsModel(snapshot: snapshot(chats: chats), family: .medium, now: now)
    XCTAssertEqual(one.rows.map(\.profile), [nil, nil, nil])

    let mixed = [chat("a"), chat("b", profile: "work", minutesAgo: 9)]
    let two = RecentChatsModel(snapshot: snapshot(chats: mixed), family: .medium, now: now)
    XCTAssertEqual(two.rows.map(\.profile), ["default", "work"])
  }

  func testProfileIsShownEvenWhenOnlyOneProfileIsVisibleInTheRows() {
    let chats = [chat("a")] + (1...4).map { chat("w\($0)", profile: "work", minutesAgo: 10 + $0) }
    let model = RecentChatsModel(snapshot: snapshot(chats: chats), family: .small, now: now)
    XCTAssertEqual(model.rows.map(\.profile), ["default"])
  }

  func testAChatListedTwiceShowsOnce() {
    let twice = [
      chat("a", title: "Newer", minutesAgo: 1), chat("a", title: "Older", minutesAgo: 9), chat("b"),
    ]
    let model = RecentChatsModel(snapshot: snapshot(chats: twice), family: .medium, now: now)
    XCTAssertEqual(model.rows.map(\.id), ["default/a", "default/b"])
    XCTAssertEqual(model.rows[0].title, "Newer")
  }

  func testSameIdInAnotherProfileIsAnotherChat() {
    let two = [chat("a"), chat("a", profile: "work", minutesAgo: 9)]
    let model = RecentChatsModel(snapshot: snapshot(chats: two), family: .medium, now: now)
    XCTAssertEqual(model.rows.map(\.id), ["default/a", "work/a"])
  }

  func testSnippetOnlyFromMedium() {
    let small = RecentChatsModel(snapshot: snapshot(chats: chats), family: .small, now: now)
    let medium = RecentChatsModel(snapshot: snapshot(chats: chats), family: .medium, now: now)
    XCTAssertNil(small.rows[0].snippet)
    XCTAssertEqual(medium.rows[0].snippet, "Snippet")
  }

  func testTapTargets() {
    let small = RecentChatsModel(snapshot: snapshot(chats: chats), family: .small, now: now)
    XCTAssertEqual(small.url, link("chat?profile=default&id=c1"))
    let medium = RecentChatsModel(snapshot: snapshot(chats: chats), family: .medium, now: now)
    XCTAssertEqual(medium.rows[1].url, link("chat?profile=default&id=c2"))
  }

  func testNoChatsOpensANewChat() {
    let model = RecentChatsModel(snapshot: snapshot(), family: .medium, now: now)
    XCTAssertTrue(model.rows.isEmpty)
    XCTAssertTrue(model.isEmpty)
    XCTAssertEqual(model.url, link("new"))
    XCTAssertFalse(model.showsOpenRow)
  }

  func testLargeWithFewChatsFillsWithOpenRow() {
    let few = [chat("a"), chat("b")]
    XCTAssertTrue(RecentChatsModel(snapshot: snapshot(chats: few), family: .large, now: now).showsOpenRow)
    XCTAssertFalse(RecentChatsModel(snapshot: snapshot(chats: few), family: .medium, now: now).showsOpenRow)
    XCTAssertFalse(RecentChatsModel(snapshot: snapshot(chats: chats), family: .large, now: now).showsOpenRow)
  }

  func testSignedOutShowsNothingAndLinksNowhere() {
    let model = RecentChatsModel(snapshot: nil, family: .medium, now: now)
    XCTAssertTrue(model.status.isSignedOut)
    XCTAssertTrue(model.rows.isEmpty)
    XCTAssertNil(model.url)
    XCTAssertFalse(model.showsOpenRow)
  }

  func testRowsWithoutTitleAreRedactedAndKeepAgeAndLink() {
    let locked = [chat("a", title: "", snippet: nil, minutesAgo: 7)]
    let row = RecentChatsModel(snapshot: snapshot(chats: locked), family: .medium, now: now).rows[0]
    XCTAssertTrue(row.isRedacted)
    XCTAssertNil(row.title)
    XCTAssertNil(row.snippet)
    XCTAssertEqual(row.updatedAt, now.addingTimeInterval(-7 * 60))
    XCTAssertEqual(row.url, link("chat?profile=default&id=a"))
  }

  func testRowWithTitleIsNotRedacted() {
    let row = RecentChatsModel(snapshot: snapshot(chats: [chat("a")]), family: .medium, now: now).rows[0]
    XCTAssertFalse(row.isRedacted)
    XCTAssertEqual(row.title, "Chat a")
  }
}

final class NeedsYouModelTests: XCTestCase {
  func testCountsEveryRequest() {
    let pending = [request("a"), request("a", kind: .question), request("b", kind: .input)]
    let model = NeedsYouModel(snapshot: snapshot(pending: pending), family: .small, now: now)
    XCTAssertEqual(model.count, 3)
    XCTAssertFalse(model.isEmpty)
  }

  func testSmallListsNoChats() {
    let model = NeedsYouModel(snapshot: snapshot(pending: [request("a")]), family: .small, now: now)
    XCTAssertTrue(model.rows.isEmpty)
  }

  func testMediumListsOldestFirstOneRowPerChatUpToThree() {
    let pending = [
      request("new", minutesAgo: 1),
      request("old", minutesAgo: 30),
      request("old", kind: .question, minutesAgo: 20),
      request("mid", kind: .input, minutesAgo: 10),
      request("extra", minutesAgo: 5),
    ]
    let model = NeedsYouModel(snapshot: snapshot(pending: pending), family: .medium, now: now)
    XCTAssertEqual(model.count, 5)
    XCTAssertEqual(model.rows.map(\.id), ["default/old", "default/mid", "default/extra"])
    XCTAssertEqual(model.rows.map(\.kind), [.approval, .input, .approval])
  }

  func testKindLabels() {
    XCTAssertEqual(NeedsYouModel.label(for: .approval), "Approval")
    XCTAssertEqual(NeedsYouModel.label(for: .question), "Question")
    XCTAssertEqual(NeedsYouModel.label(for: .input), "Waiting for you")
  }

  func testTapOpensTheOldestRequestsChat() {
    let pending = [request("new", minutesAgo: 1), request("old", minutesAgo: 30)]
    let model = NeedsYouModel(snapshot: snapshot(pending: pending), family: .small, now: now)
    XCTAssertEqual(model.url, link("chat?profile=default&id=old"))
  }

  func testNothingWaitingOpensTheRequestsFallback() {
    let model = NeedsYouModel(snapshot: snapshot(), family: .medium, now: now)
    XCTAssertTrue(model.isEmpty)
    XCTAssertEqual(model.url, link("requests"))
  }

  func testSignedOutLinksNowhere() {
    let model = NeedsYouModel(snapshot: nil, family: .small, now: now)
    XCTAssertTrue(model.status.isSignedOut)
    XCTAssertNil(model.url)
    XCTAssertEqual(model.count, 0)
  }

  func testRowsWithoutTitleAreRedactedAndKeepKindAgeAndLink() {
    let locked = [request("a", kind: .question, title: "", minutesAgo: 12)]
    let model = NeedsYouModel(snapshot: snapshot(pending: locked), family: .medium, now: now)
    XCTAssertEqual(model.count, 1)
    let row = model.rows[0]
    XCTAssertTrue(row.isRedacted)
    XCTAssertNil(row.title)
    XCTAssertEqual(row.kind, .question)
    XCTAssertEqual(row.createdAt, now.addingTimeInterval(-12 * 60))
    XCTAssertEqual(row.url, link("chat?profile=default&id=a"))
  }
}

final class BoardModelTests: XCTestCase {
  private let failed = FailedJob(
    profile: "default", jobId: "j1", name: "Backup", at: now.addingTimeInterval(-3600),
    url: link("schedules?profile=default&job=j1"))

  private func schedules(
    next: Date? = now.addingTimeInterval(3600), name: String? = "Daily digest", failed: FailedJob? = nil
  ) -> ScheduleSummary {
    ScheduleSummary(nextRunAt: next, nextJobName: name, lastFailed: failed)
  }

  func testMediumShowsEveryPartInOrder() {
    let model = BoardModel(
      snapshot: snapshot(kanban: KanbanSummary(blocked: 1, review: 2), schedules: schedules(failed: failed)),
      family: .medium, now: now)
    XCTAssertEqual(
      model.parts,
      [
        .kanban(blocked: 1, review: 2, url: link("kanban")),
        .failedJob(name: "Backup", at: failed.at, url: failed.url),
        .nextRun(name: "Daily digest", at: now.addingTimeInterval(3600), isDue: false, url: link("schedules")),
      ])
    XCTAssertNil(model.emptyText)
  }

  func testSmallKeepsTwoParts() {
    let model = BoardModel(
      snapshot: snapshot(kanban: KanbanSummary(blocked: 0, review: 0), schedules: schedules(failed: failed)),
      family: .small, now: now)
    XCTAssertEqual(model.parts.count, 2)
  }

  func testSmallOpensTheFailedJobItShows() {
    let model = BoardModel(
      snapshot: snapshot(kanban: KanbanSummary(blocked: 1, review: 0), schedules: schedules(failed: failed)),
      family: .small, now: now)
    XCTAssertEqual(model.url, failed.url)
  }

  func testSmallWithoutAFailureOpensItsFirstPart() {
    let model = BoardModel(
      snapshot: snapshot(kanban: KanbanSummary(blocked: 1, review: 0), schedules: schedules()),
      family: .small, now: now)
    XCTAssertEqual(model.url, link("kanban"))
  }

  func testServerWithoutKanbanShowsOnlySchedules() {
    let model = BoardModel(snapshot: snapshot(schedules: schedules()), family: .medium, now: now)
    XCTAssertEqual(model.parts.count, 1)
    guard case .nextRun = model.parts[0] else { return XCTFail("expected the next run") }
  }

  func testServerWithoutSchedulesShowsOnlyKanban() {
    let model = BoardModel(
      snapshot: snapshot(kanban: KanbanSummary(blocked: 3, review: 0)), family: .medium, now: now)
    XCTAssertEqual(model.parts, [.kanban(blocked: 3, review: 0, url: link("kanban"))])
  }

  func testNeitherFeatureSaysSo() {
    let model = BoardModel(snapshot: snapshot(), family: .medium, now: now)
    XCTAssertTrue(model.parts.isEmpty)
    XCTAssertEqual(model.emptyText, "No board or schedules on this server")
  }

  func testSchedulesWithNothingScheduled() {
    let model = BoardModel(
      snapshot: snapshot(schedules: schedules(next: nil, name: nil)), family: .medium, now: now)
    XCTAssertTrue(model.parts.isEmpty)
    XCTAssertEqual(model.emptyText, "Nothing scheduled")
  }

  func testNextRunIsDueOnceItsTimePassed() {
    let past = now.addingTimeInterval(-60)
    let model = BoardModel(snapshot: snapshot(schedules: schedules(next: past)), family: .medium, now: now)
    XCTAssertEqual(model.parts, [.nextRun(name: "Daily digest", at: past, isDue: true, url: link("schedules"))])
  }

  func testNamesAreRedactedWhileAppLockIsOn() {
    let locked = FailedJob(
      profile: "default", jobId: "j1", name: "", at: failed.at, url: failed.url)
    let model = BoardModel(
      snapshot: snapshot(schedules: schedules(name: nil, failed: locked)), family: .medium, now: now)
    XCTAssertEqual(
      model.parts,
      [
        .failedJob(name: nil, at: failed.at, url: failed.url),
        .nextRun(name: nil, at: now.addingTimeInterval(3600), isDue: false, url: link("schedules")),
      ])
  }

  func testSignedOutLinksNowhere() {
    let model = BoardModel(snapshot: nil, family: .small, now: now)
    XCTAssertTrue(model.status.isSignedOut)
    XCTAssertNil(model.url)
    XCTAssertTrue(model.parts.isEmpty)
  }
}

final class SurfaceTimelineTests: XCTestCase {
  private func dates(_ snapshot: SurfaceSnapshot?, followsNextRun: Bool = false) -> [Date] {
    SurfaceTimeline.dates(snapshot: snapshot, now: now, followsNextRun: followsNextRun)
  }

  func testAddsAnEntryWhenTheSnapshotTurnsStale() {
    let written = now.addingTimeInterval(-3600)
    XCTAssertEqual(
      dates(snapshot(updatedAt: written)), [now, written.addingTimeInterval(surfaceStaleAfter)])
  }

  func testAlreadyStaleIsOneEntry() {
    XCTAssertEqual(dates(snapshot(updatedAt: now.addingTimeInterval(-7 * 3600))), [now])
  }

  func testBoardAddsAnEntryWhenTheNextRunComesDue() {
    let next = now.addingTimeInterval(1800)
    let snap = snapshot(schedules: ScheduleSummary(nextRunAt: next, nextJobName: "x", lastFailed: nil))
    XCTAssertEqual(
      dates(snap, followsNextRun: true),
      [now, next, snap.updatedAt.addingTimeInterval(surfaceStaleAfter)])
    XCTAssertFalse(dates(snap).contains(next))
  }

  func testPastRunAddsNoEntry() {
    let snap = snapshot(
      schedules: ScheduleSummary(nextRunAt: now.addingTimeInterval(-5), nextJobName: "x", lastFailed: nil))
    XCTAssertFalse(dates(snap, followsNextRun: true).contains { $0 < now })
  }

  func testSignedOutIsOneEntry() {
    XCTAssertEqual(dates(nil), [now])
    XCTAssertEqual(dates(snapshot(signedIn: false)), [now])
  }
}

final class SampleSnapshotTests: XCTestCase {
  func testSampleFillsEverySection() {
    let sample = SurfaceSnapshot.sample(now: now)
    XCTAssertTrue(sample.signedIn)
    XCTAssertGreaterThanOrEqual(sample.recentChats.count, 6)
    XCTAssertGreaterThanOrEqual(sample.pending.count, 2)
    XCTAssertNotNil(sample.kanban)
    XCTAssertNotNil(sample.schedules?.lastFailed)
    XCTAssertFalse(WidgetStatus(snapshot: sample, now: now).isStale)
  }
}
