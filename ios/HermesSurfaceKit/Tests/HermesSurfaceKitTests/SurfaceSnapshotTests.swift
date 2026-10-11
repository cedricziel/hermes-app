import XCTest

@testable import HermesSurfaceKit

/// The JSON of `test/fixtures/surface_snapshot_v1.json`, which a Dart test
/// keeps equal to what the app writes.
func fixtureJSON() throws -> String {
  let url = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures/surface_snapshot_v1.json")
  return try String(contentsOf: url, encoding: .utf8)
}

func date(_ iso: String) -> Date {
  ISO8601DateFormatter().date(from: iso)!
}

final class SurfaceSnapshotTests: XCTestCase {
  func testDecodesTheFixture() throws {
    let snapshot = try XCTUnwrap(SurfaceSnapshot.decode(fixtureJSON()))

    XCTAssertTrue(snapshot.signedIn)
    XCTAssertEqual(snapshot.updatedAt, date("2026-10-10T12:00:00Z"))
    XCTAssertEqual(snapshot.profile, "default")
    XCTAssertEqual(snapshot.profiles, ["default", "work"])

    XCTAssertEqual(snapshot.recentChats.map(\.title), ["Trip plan", "C++ review", "Compiler notes", "Groceries"])
    let first = snapshot.recentChats[0]
    XCTAssertEqual(first.id, "abc")
    XCTAssertEqual(first.profile, "default")
    XCTAssertEqual(first.snippet, "Booked the flights and the first hotel.")
    XCTAssertEqual(first.updatedAt, date("2026-10-10T11:50:00Z"))
    XCTAssertEqual(first.url.absoluteString, "hermes://chat?profile=default&id=abc")
    XCTAssertEqual(snapshot.recentChats[1].url.absoluteString, "hermes://chat?profile=work&id=w%201")
    XCTAssertEqual(snapshot.recentChats[2].url.absoluteString, "hermes://chat?profile=default&id=c%2B%2B")
    XCTAssertEqual(
      URLComponents(url: snapshot.recentChats[2].url, resolvingAgainstBaseURL: false)?
        .queryItems?.first { $0.name == "id" }?.value,
      "c++")
    XCTAssertNil(snapshot.recentChats[3].snippet)

    XCTAssertEqual(snapshot.pending.map(\.kind), [.approval, .question])
    XCTAssertEqual(snapshot.pending[1].threadTitle, "C++ review")
    XCTAssertEqual(snapshot.pending[1].createdAt, date("2026-10-10T11:45:00Z"))

    XCTAssertEqual(snapshot.kanban, KanbanSummary(blocked: 1, review: 2))
    XCTAssertEqual(snapshot.schedules?.nextRunAt, date("2026-10-11T08:00:00Z"))
    XCTAssertEqual(snapshot.schedules?.nextJobName, "Daily digest")
    XCTAssertEqual(snapshot.schedules?.lastFailed?.name, "Backup")
    XCTAssertEqual(
      snapshot.schedules?.lastFailed?.url.absoluteString,
      "hermes://schedules?profile=default&job=j1")
  }

  func testSignedOutSnapshotHoldsNothing() throws {
    let snapshot = try XCTUnwrap(
      SurfaceSnapshot.decode(
        """
        {"version":1,"updatedAt":"2026-10-10T12:00:00Z","signedIn":false,"profile":null,
         "profiles":[],"recentChats":[],"pending":[],"kanban":null,"schedules":null}
        """))
    XCTAssertFalse(snapshot.signedIn)
    XCTAssertTrue(snapshot.recentChats.isEmpty)
    XCTAssertNil(snapshot.kanban)
    XCTAssertNil(snapshot.schedules)
  }

  func testRevisionIsAWriterConcernAndIgnoredHere() throws {
    let snapshot = try XCTUnwrap(
      SurfaceSnapshot.decode(
        #"{"version":1,"updatedAt":"2026-10-10T12:00:00Z","revision":"not even a number","signedIn":true}"#
      ))
    XCTAssertTrue(snapshot.signedIn)
  }

  func testUnknownVersionIsUnreadable() {
    XCTAssertNil(SurfaceSnapshot.decode(#"{"version":2,"updatedAt":"2026-10-10T12:00:00Z","signedIn":true}"#))
  }

  func testVersionMustBeTheNumberOne() {
    for version in ["true", "1.5", #""1""#, "null"] {
      XCTAssertNil(
        SurfaceSnapshot.decode(
          #"{"version":\#(version),"updatedAt":"2026-10-10T12:00:00Z","signedIn":true}"#),
        "version \(version)")
    }
  }

  func testFlagsAndCountsMustBeOfTheirOwnType() throws {
    let snapshot = try XCTUnwrap(
      SurfaceSnapshot.decode(
        #"{"version":1,"updatedAt":"2026-10-10T12:00:00Z","signedIn":1,"kanban":{"blocked":true,"review":2}}"#))
    XCTAssertFalse(snapshot.signedIn)
    XCTAssertNil(snapshot.kanban)
  }

  func testBadJSONIsUnreadable() {
    XCTAssertNil(SurfaceSnapshot.decode("{not json"))
    XCTAssertNil(SurfaceSnapshot.decode("[]"))
    XCTAssertNil(SurfaceSnapshot.decode(nil))
    XCTAssertNil(SurfaceSnapshot.decode(#"{"version":1,"signedIn":true}"#))
  }

  func testMalformedRowsAreSkipped() throws {
    let snapshot = try XCTUnwrap(
      SurfaceSnapshot.decode(
        """
        {"version":1,"updatedAt":"2026-10-10T12:00:00Z","signedIn":true,
         "recentChats":[
           {"profile":"p","id":"a","title":"Kept","updatedAt":"2026-10-10T11:00:00Z","url":"hermes://chat?profile=p&id=a"},
           {"profile":"p","title":"No id","updatedAt":"2026-10-10T11:00:00Z","url":"hermes://chat?profile=p"},
           {"profile":"p","id":"b","title":"No time","url":"hermes://chat?profile=p&id=b"},
           {"profile":"p","id":"c","title":"Other scheme","updatedAt":"2026-10-10T11:00:00Z","url":"https://example.com"},
           {"profile":"p","id":"d","title":"No link","updatedAt":"2026-10-10T11:00:00Z"},
           "nonsense"
         ],
         "pending":[
           {"profile":"p","threadId":"a","threadTitle":"T","kind":"approval","requestId":"r","createdAt":"2026-10-10T11:00:00Z","url":"hermes://chat?profile=p&id=a"},
           {"profile":"p","threadId":"a","kind":"approval","requestId":"r","createdAt":"2026-10-10T11:00:00Z","url":"hermes://chat?profile=p&id=a"}
         ]}
        """))
    XCTAssertEqual(snapshot.recentChats.map(\.id), ["a"])
    XCTAssertEqual(snapshot.pending.count, 1)
  }

  func testUnknownRequestKindStillCounts() throws {
    let snapshot = try XCTUnwrap(
      SurfaceSnapshot.decode(
        """
        {"version":1,"updatedAt":"2026-10-10T12:00:00Z","signedIn":true,
         "pending":[{"profile":"p","threadId":"a","threadTitle":"T","kind":"future","requestId":"r",
         "createdAt":"2026-10-10T11:00:00Z","url":"hermes://chat?profile=p&id=a"}]}
        """))
    XCTAssertEqual(snapshot.pending.map(\.kind), [.input])
  }

  func testMissingSectionsAreUnavailable() throws {
    let snapshot = try XCTUnwrap(
      SurfaceSnapshot.decode(#"{"version":1,"updatedAt":"2026-10-10T12:00:00Z","signedIn":true}"#))
    XCTAssertNil(snapshot.kanban)
    XCTAssertNil(snapshot.schedules)
    XCTAssertEqual(snapshot.profiles, [])
    XCTAssertTrue(snapshot.recentChats.isEmpty)
  }

  func testMalformedProfilesReadAsEmptyOrSkipTheBadEntries() throws {
    let head = #"{"version":1,"updatedAt":"2026-10-10T12:00:00Z","signedIn":true,"profiles":"#
    XCTAssertEqual(try XCTUnwrap(SurfaceSnapshot.decode(head + #""default"}"#)).profiles, [])
    XCTAssertEqual(
      try XCTUnwrap(SurfaceSnapshot.decode(head + #"["default",3,null,"work"]}"#)).profiles,
      ["default", "work"])
  }

  func testSchedulesWithNothingScheduledAreStillOffered() throws {
    let snapshot = try XCTUnwrap(
      SurfaceSnapshot.decode(
        #"{"version":1,"updatedAt":"2026-10-10T12:00:00Z","signedIn":true,"schedules":{"nextRunAt":null,"nextJobName":null,"lastFailed":null}}"#
      ))
    XCTAssertEqual(snapshot.schedules, ScheduleSummary(nextRunAt: nil, nextJobName: nil, lastFailed: nil))
  }

  func testReadsFractionalSeconds() throws {
    let snapshot = try XCTUnwrap(
      SurfaceSnapshot.decode(#"{"version":1,"updatedAt":"2026-10-10T12:00:00.250Z","signedIn":true}"#))
    XCTAssertEqual(snapshot.updatedAt.timeIntervalSince1970, date("2026-10-10T12:00:00Z").timeIntervalSince1970 + 0.25, accuracy: 0.001)
  }

  func testChatsAreNewestFirst() throws {
    let snapshot = try XCTUnwrap(
      SurfaceSnapshot.decode(
        """
        {"version":1,"updatedAt":"2026-10-10T12:00:00Z","signedIn":true,"recentChats":[
         {"profile":"p","id":"old","title":"Old","updatedAt":"2026-10-10T08:00:00Z","url":"hermes://chat?profile=p&id=old"},
         {"profile":"p","id":"new","title":"New","updatedAt":"2026-10-10T11:00:00Z","url":"hermes://chat?profile=p&id=new"}]}
        """))
    XCTAssertEqual(snapshot.recentChats.map(\.id), ["new", "old"])
  }
}
