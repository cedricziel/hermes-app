import AppIntents
import Foundation

// What Siri, Shortcuts and the controls can pick from: the recent chats and the
// profiles of the surface snapshot. Nothing here reaches the network or secure
// storage; the snapshot is the whole source.

/// A chat of the surface snapshot, as an App Intents parameter.
struct ChatEntity: AppEntity, Equatable {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Chat"
  static let defaultQuery = ChatQuery()

  /// What a chat is called when the snapshot has no title: the chat is not
  /// among the recent ones, or App Lock is on.
  static let untitled = "Chat"

  /// `<percent-encoded profile>/<thread id>`, the shape the watch binds a
  /// thread to its profile with, so chats with one id in two profiles differ.
  let id: String
  let profile: String
  let threadID: String
  let title: String
  let updatedAt: Date?

  private let titleHidden: Bool
  private let showsProfile: Bool

  init(
    profile: String, threadID: String, title: String, updatedAt: Date? = nil,
    showsProfile: Bool = false
  ) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    self.id = Self.makeID(profile: profile, threadID: threadID)
    self.profile = profile
    self.threadID = threadID
    self.title = trimmed.isEmpty ? Self.untitled : trimmed
    self.updatedAt = updatedAt
    self.titleHidden = trimmed.isEmpty
    self.showsProfile = showsProfile
  }

  static func makeID(profile: String, threadID: String) -> String {
    "\(profile.addingPercentEncoding(withAllowedCharacters: DeepLink.unreserved) ?? "")/\(threadID)"
  }

  /// A chat named only by its [id], with no title.
  static func parse(id: String) -> ChatEntity? {
    guard let slash = id.firstIndex(of: "/"),
      let profile = String(id[..<slash]).removingPercentEncoding
    else { return nil }
    return ChatEntity(profile: profile, threadID: String(id[id.index(after: slash)...]), title: "")
  }

  /// The profile when chats of several profiles are offered, and always for a
  /// chat without a title, which needs it (and its age) to be told apart.
  func subtitle(now: Date = .now) -> String? {
    guard titleHidden else { return showsProfile ? profile : nil }
    guard let updatedAt else { return profile }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return "\(profile) · \(formatter.localizedString(for: updatedAt, relativeTo: now))"
  }

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: "\(title)",
      subtitle: subtitle().map { "\($0)" },
      image: .init(systemName: "bubble.left"))
  }
}

struct ChatQuery: EntityStringQuery {
  func entities(for identifiers: [ChatEntity.ID]) async throws -> [ChatEntity] {
    IntentDirectory.current().chats(withIDs: identifiers)
  }

  func entities(matching string: String) async throws -> [ChatEntity] {
    IntentDirectory.current().chats(matching: string)
  }

  func suggestedEntities() async throws -> [ChatEntity] {
    IntentDirectory.current().suggestedChats
  }
}

/// A Hermes profile of the server, as an App Intents parameter.
struct ProfileEntity: AppEntity, Equatable {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Profile"
  static let defaultQuery = ProfileQuery()

  /// The profile's name, which is how every `hermes://` link names it.
  let id: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(id)", image: .init(systemName: "person.crop.circle"))
  }
}

struct ProfileQuery: EntityStringQuery {
  func entities(for identifiers: [ProfileEntity.ID]) async throws -> [ProfileEntity] {
    IntentDirectory.current().profiles(withIDs: identifiers)
  }

  func entities(matching string: String) async throws -> [ProfileEntity] {
    IntentDirectory.current().profiles(matching: string)
  }

  func suggestedEntities() async throws -> [ProfileEntity] {
    IntentDirectory.current().profiles
  }
}

/// The chats, profiles and links the intents work from, all read from one
/// snapshot.
struct IntentDirectory {
  /// The most chats Siri and Shortcuts are offered.
  static let chatLimit = 10

  let snapshot: SurfaceSnapshot?

  /// The snapshot in the App Group, as it is right now.
  static func current() -> IntentDirectory {
    IntentDirectory(snapshot: SurfaceSnapshot.load(appGroup: SurfaceSnapshot.appGroup))
  }

  /// Nothing is offered while nobody is signed in or the snapshot is
  /// unreadable; links still open the app.
  private var offered: SurfaceSnapshot? {
    guard let snapshot, snapshot.signedIn else { return nil }
    return snapshot
  }

  /// The profile the app last showed.
  var currentProfile: String? { snapshot?.profile }

  private var severalProfilesInChats: Bool {
    Set(snapshot?.recentChats.map(\.profile) ?? []).count > 1
  }

  private func entity(_ chat: RecentChat) -> ChatEntity {
    ChatEntity(
      profile: chat.profile, threadID: chat.id, title: chat.title, updatedAt: chat.updatedAt,
      showsProfile: severalProfilesInChats)
  }

  /// The recent chats, newest first.
  var suggestedChats: [ChatEntity] {
    (offered?.recentChats ?? []).prefix(Self.chatLimit).map(entity)
  }

  /// A chat the snapshot no longer holds is still returned, titled "Chat": a
  /// saved shortcut or control names it, and the app fetches a missing chat.
  /// That holds while signed out too, so the app opens on its sign-in.
  func chats(withIDs ids: [String]) -> [ChatEntity] {
    ids.compactMap { id in
      guard let parsed = ChatEntity.parse(id: id) else { return nil }
      let known = snapshot?.recentChats.first {
        $0.profile == parsed.profile && $0.id == parsed.threadID
      }
      return known.map(entity) ?? parsed
    }
  }

  /// Titles that contain [query], ignoring case and diacritics. A chat
  /// without a title (App Lock) never matches.
  func chats(matching query: String) -> [ChatEntity] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !needle.isEmpty else { return suggestedChats }
    return (offered?.recentChats ?? []).filter {
      Self.matches($0.title, needle)
    }.prefix(Self.chatLimit).map(entity)
  }

  private static func matches(_ text: String, _ needle: String) -> Bool {
    text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
  }

  /// The server's profiles with the current one first; when the snapshot
  /// lists none (an older one), the current profile and those of the chats.
  var profiles: [ProfileEntity] {
    guard let offered else { return [] }
    let names =
      [offered.profile].compactMap { $0 }
      + (offered.profiles.isEmpty ? offered.recentChats.map(\.profile) : offered.profiles)
    var seen = Set<String>()
    return names.filter { !$0.isEmpty && seen.insert($0).inserted }.map(ProfileEntity.init(id:))
  }

  func profiles(withIDs ids: [String]) -> [ProfileEntity] {
    let known = profiles
    return ids.compactMap { id in known.first { $0.id == id } }
  }

  func profiles(matching query: String) -> [ProfileEntity] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    return needle.isEmpty ? profiles : profiles.filter { Self.matches($0.id, needle) }
  }

  /// The link that opens [chat] in its profile.
  func link(opening chat: ChatEntity) -> URL {
    DeepLink.chat(profile: chat.profile, id: chat.threadID)
  }

  /// A new chat in [profile], or in the app's current one.
  func newChatLink(profile: ProfileEntity?, dictate: Bool) -> URL {
    DeepLink.newChat(profile: profile?.id ?? currentProfile, dictate: dictate)
  }
}
