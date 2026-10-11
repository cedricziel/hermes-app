import XCTest

@testable import HermesSurfaceKit

private let now = date("2026-10-10T12:00:00Z")

private func chat(
  _ id: String, title: String? = nil, profile: String = "default", minutesAgo: Int = 5
) -> RecentChat {
  RecentChat(
    profile: profile, id: id, title: title ?? "Chat \(id)", snippet: nil,
    updatedAt: now.addingTimeInterval(TimeInterval(-60 * minutesAgo)),
    url: DeepLink.chat(profile: profile, id: id))
}

private func directory(
  signedIn: Bool = true, profile: String? = "default", profiles: [String] = ["default"],
  chats: [RecentChat] = []
) -> IntentDirectory {
  IntentDirectory(
    snapshot: SurfaceSnapshot(
      updatedAt: now, signedIn: signedIn, profile: profile, profiles: profiles,
      recentChats: chats, pending: [], kanban: nil, schedules: nil))
}

final class ChatEntityTests: XCTestCase {
  func testIdIsTheEncodedProfileAndTheThreadIdAndRoundTrips() throws {
    let entity = ChatEntity(profile: "R&D/team", threadID: "a/b", title: "T")
    XCTAssertEqual(entity.id, "R%26D%2Fteam/a/b")
    let parsed = try XCTUnwrap(ChatEntity.parse(id: entity.id))
    XCTAssertEqual(parsed.profile, "R&D/team")
    XCTAssertEqual(parsed.threadID, "a/b")
  }

  func testAnIdWithoutASlashIsNotAChat() {
    XCTAssertNil(ChatEntity.parse(id: "abc"))
  }

  func testAnEmptyTitleIsShownAsChat() {
    XCTAssertEqual(ChatEntity(profile: "p", threadID: "a", title: "").title, "Chat")
    XCTAssertEqual(ChatEntity(profile: "p", threadID: "a", title: "  ").title, "Chat")
  }
}

final class IntentDirectoryChatsTests: XCTestCase {
  func testSuggestsTheRecentChatsNewestFirst() {
    let chats = directory(chats: [
      chat("old", minutesAgo: 90), chat("new", minutesAgo: 1), chat("mid", minutesAgo: 30),
    ]).suggestedChats
    XCTAssertEqual(chats.map(\.threadID), ["new", "mid", "old"])
  }

  func testSuggestsAtMostTen() {
    let many = (0..<14).map { chat("c\($0)", minutesAgo: $0) }
    XCTAssertEqual(directory(chats: many).suggestedChats.count, 10)
  }

  func testTheSameIdInTwoProfilesStaysApart() {
    let found = directory(
      profiles: ["default", "work"],
      chats: [chat("abc", title: "A", profile: "default"), chat("abc", title: "B", profile: "work")]
    ).suggestedChats
    XCTAssertEqual(found.count, 2)
    XCTAssertEqual(Set(found.map(\.id)).count, 2)
    XCTAssertEqual(Set(found.map(\.profile)), ["default", "work"])
  }

  func testFindsAChatByIdAcrossProfiles() {
    let dir = directory(
      profiles: ["default", "work"],
      chats: [chat("abc", title: "A", profile: "default"), chat("abc", title: "B", profile: "work")])
    let work = ChatEntity(profile: "work", threadID: "abc", title: "x").id
    let found = dir.chats(withIDs: [work])
    XCTAssertEqual(found.map(\.title), ["B"])
    XCTAssertEqual(found.map(\.profile), ["work"])
  }

  func testAnUnknownIdStillOpensAsChat() {
    let id = ChatEntity(profile: "work", threadID: "gone", title: "x").id
    let found = directory(chats: [chat("abc")]).chats(withIDs: [id])
    XCTAssertEqual(found.map(\.title), ["Chat"])
    XCTAssertEqual(found.map(\.profile), ["work"])
    XCTAssertEqual(found.map(\.threadID), ["gone"])
  }

  func testAnIdThatIsNoChatIsDropped() {
    XCTAssertEqual(directory().chats(withIDs: ["nonsense"]), [])
  }

  func testIdsKeepTheOrderAsked() {
    let dir = directory(chats: [chat("a", minutesAgo: 1), chat("b", minutesAgo: 2)])
    let ids = ["b", "a"].map { ChatEntity(profile: "default", threadID: $0, title: "").id }
    XCTAssertEqual(dir.chats(withIDs: ids).map(\.threadID), ["b", "a"])
  }

  func testSearchIgnoresCaseAndDiacritics() {
    let dir = directory(chats: [
      chat("a", title: "Zürich trip"), chat("b", title: "Taxes"), chat("c", title: "ZURICH hotel"),
    ])
    XCTAssertEqual(Set(dir.chats(matching: "zurich").map(\.threadID)), ["a", "c"])
    XCTAssertEqual(dir.chats(matching: "TAX").map(\.threadID), ["b"])
    XCTAssertEqual(dir.chats(matching: "nothing"), [])
  }

  func testAnEmptySearchSuggestsTheRecentChats() {
    let dir = directory(chats: [chat("a"), chat("b", minutesAgo: 9)])
    XCTAssertEqual(dir.chats(matching: " "), dir.suggestedChats)
  }

  func testNothingIsOfferedWhileSignedOutOrWithoutASnapshot() {
    let out = directory(signedIn: false, chats: [chat("a", title: "Trip")])
    XCTAssertEqual(out.suggestedChats, [])
    XCTAssertEqual(out.chats(matching: "trip"), [])
    XCTAssertEqual(IntentDirectory(snapshot: nil).suggestedChats, [])
  }

  func testAChatAskedForByIdStillOpensWhileSignedOut() {
    let id = ChatEntity(profile: "default", threadID: "a", title: "").id
    XCTAssertEqual(directory(signedIn: false).chats(withIDs: [id]).map(\.threadID), ["a"])
    XCTAssertEqual(IntentDirectory(snapshot: nil).chats(withIDs: [id]).map(\.threadID), ["a"])
  }

  func testUnnamedChatsKeepTheLabelTheAppWrote() {
    let found = directory(chats: [chat("a", title: "New chat")]).suggestedChats
    XCTAssertEqual(found.map(\.title), ["New chat"])
  }

  func testAppLockShowsChatAndMatchesNoTitle() {
    let locked = directory(
      profiles: ["default", "work"],
      chats: [chat("a", title: "", profile: "default"), chat("b", title: "", profile: "work")])
    XCTAssertEqual(locked.suggestedChats.map(\.title), ["Chat", "Chat"])
    XCTAssertEqual(locked.chats(matching: "chat"), [])
    XCTAssertEqual(locked.chats(matching: "Chat a"), [])
    XCTAssertEqual(locked.suggestedChats.map(\.profile), ["default", "work"])
  }

  func testAnOpenTitleAndALockedOneNeverMeetInASearch() {
    let open = directory(chats: [chat("a", title: "Chat about taxes")])
    XCTAssertEqual(open.chats(matching: "taxes").map(\.threadID), ["a"])
  }
}

final class ChatSubtitleTests: XCTestCase {
  func testNoSubtitleWhenAllChatsShareOneProfile() {
    let found = directory(chats: [chat("a"), chat("b")]).suggestedChats
    XCTAssertEqual(found.map { $0.subtitle(now: now) }, [nil, nil])
  }

  func testTheProfileWhenChatsOfSeveralProfilesAreOffered() {
    let found = directory(
      profiles: ["default", "work"],
      chats: [chat("a", profile: "default"), chat("b", profile: "work", minutesAgo: 9)]
    ).suggestedChats
    XCTAssertEqual(found.map { $0.subtitle(now: now) }, ["default", "work"])
  }

  func testALockedChatShowsItsProfileAndAge() {
    let found = directory(chats: [chat("a", title: "", minutesAgo: 120)]).suggestedChats
    let subtitle = found[0].subtitle(now: now)
    XCTAssertTrue(subtitle?.hasPrefix("default · ") == true, subtitle ?? "nil")
  }
}

final class IntentDirectoryProfilesTests: XCTestCase {
  func testTheSnapshotsProfilesWithTheCurrentOneFirst() {
    let dir = directory(profile: "work", profiles: ["default", "work", "play"])
    XCTAssertEqual(dir.profiles.map(\.id), ["work", "default", "play"])
  }

  func testNoDuplicates() {
    let dir = directory(profile: "work", profiles: ["work", "work", "default"])
    XCTAssertEqual(dir.profiles.map(\.id), ["work", "default"])
  }

  func testOffersProfilesWithoutRecentChats() {
    let dir = directory(profiles: ["default", "work"], chats: [chat("a", profile: "default")])
    XCTAssertEqual(dir.profiles.map(\.id), ["default", "work"])
  }

  func testFallsBackToTheCurrentProfileAndThoseOfTheChats() {
    let dir = directory(
      profile: "default", profiles: [],
      chats: [chat("a", profile: "work"), chat("b", profile: "play", minutesAgo: 9)])
    XCTAssertEqual(dir.profiles.map(\.id), ["default", "work", "play"])
  }

  func testNothingWhileSignedOutOrWithoutASnapshot() {
    XCTAssertEqual(directory(signedIn: false).profiles, [])
    XCTAssertEqual(IntentDirectory(snapshot: nil).profiles, [])
  }

  func testLooksUpOnlyKnownProfiles() {
    let dir = directory(profiles: ["default", "work"])
    XCTAssertEqual(dir.profiles(withIDs: ["work", "gone"]).map(\.id), ["work"])
  }

  func testSearchesTheNamesIgnoringCaseAndDiacritics() {
    let dir = directory(profiles: ["default", "Büro"])
    XCTAssertEqual(dir.profiles(matching: "buro").map(\.id), ["Büro"])
  }
}

final class IntentLinksTests: XCTestCase {
  func testOpenChatOpensTheChatInItsProfile() {
    let entity = ChatEntity(profile: "work", threadID: "abc", title: "T")
    XCTAssertEqual(
      directory().link(opening: entity).absoluteString, "hermes://chat?profile=work&id=abc")
  }

  func testOpenChatEncodesLikeTheApp() {
    let entity = ChatEntity(profile: "R&D team", threadID: "c++", title: "T")
    XCTAssertEqual(
      directory().link(opening: entity).absoluteString,
      "hermes://chat?profile=R%26D%20team&id=c%2B%2B")
  }

  func testNewChatWithAGivenProfile() {
    let work = ProfileEntity(id: "R&D team")
    XCTAssertEqual(
      directory().newChatLink(profile: work, dictate: false).absoluteString,
      "hermes://new?profile=R%26D%20team")
  }

  func testNewChatDefaultsToTheAppsCurrentProfile() {
    XCTAssertEqual(
      directory(profile: "work").newChatLink(profile: nil, dictate: false).absoluteString,
      "hermes://new?profile=work")
  }

  func testNewChatWithoutAnyKnownProfileCarriesNone() {
    XCTAssertEqual(
      directory(profile: nil).newChatLink(profile: nil, dictate: false).absoluteString,
      "hermes://new")
    XCTAssertEqual(
      IntentDirectory(snapshot: nil).newChatLink(profile: nil, dictate: false).absoluteString,
      "hermes://new")
  }

  func testDictateAddsTheFlag() {
    XCTAssertEqual(
      directory(profile: "work").newChatLink(profile: nil, dictate: true).absoluteString,
      "hermes://new?profile=work&dictate=1")
    XCTAssertEqual(
      IntentDirectory(snapshot: nil).newChatLink(profile: nil, dictate: true).absoluteString,
      "hermes://new?dictate=1")
  }

  func testAGivenProfileBeatsTheCurrentOne() {
    XCTAssertEqual(
      directory(profile: "work").newChatLink(profile: ProfileEntity(id: "play"), dictate: false)
        .absoluteString,
      "hermes://new?profile=play")
  }
}

final class OpenIntentsTests: XCTestCase {
  func testOpenChatOpensThePickedChat() {
    let intent = OpenChatIntent()
    intent.chat = ChatEntity(profile: "work", threadID: "abc", title: "T")
    XCTAssertEqual(intent.link(in: directory()).absoluteString, "hermes://chat?profile=work&id=abc")
  }

  func testNewChatTakesTheProfileGivenOrTheCurrentOne() {
    let intent = NewChatIntent()
    XCTAssertEqual(
      intent.link(in: directory(profile: "work")).absoluteString, "hermes://new?profile=work")
    intent.profile = ProfileEntity(id: "R&D team")
    XCTAssertEqual(
      intent.link(in: directory(profile: "work")).absoluteString,
      "hermes://new?profile=R%26D%20team")
    XCTAssertEqual(
      NewChatIntent().link(in: IntentDirectory(snapshot: nil)).absoluteString, "hermes://new")
  }

  func testDictateStartsTheMicrophone() {
    let intent = DictateIntent()
    XCTAssertEqual(
      intent.link(in: directory(profile: "work")).absoluteString,
      "hermes://new?profile=work&dictate=1")
    intent.profile = ProfileEntity(id: "play")
    XCTAssertEqual(
      intent.link(in: directory(profile: "work")).absoluteString,
      "hermes://new?profile=play&dictate=1")
    XCTAssertEqual(
      DictateIntent().link(in: IntentDirectory(snapshot: nil)).absoluteString,
      "hermes://new?dictate=1")
  }

  func testTheOpenChatControlOpensItsChatOrTheChatList() {
    let control = OpenChatControlIntent()
    XCTAssertEqual(control.link(in: directory()).absoluteString, "hermes://requests")
    control.chat = ChatEntity(profile: "default", threadID: "abc", title: "T")
    XCTAssertEqual(
      control.link(in: directory()).absoluteString, "hermes://chat?profile=default&id=abc")
  }

  func testTheControlTitleFollowsARenamedChat() {
    let control = OpenChatControlIntent()
    XCTAssertEqual(control.title(in: directory()), "Open Chat")
    control.chat = ChatEntity(profile: "default", threadID: "abc", title: "Old name")
    XCTAssertEqual(
      control.title(in: directory(chats: [chat("abc", title: "New name")])), "New name")
    XCTAssertEqual(control.title(in: directory()), "Chat")
  }
}
