import AppIntents
import Foundation

// The intents that open Hermes on a `hermes://` link and do nothing else: no
// prompt is sent, no token read, no request made. The app handles the link
// like any other (`lib/src/deep_links/`), and shows its sign-in first when
// nobody is signed in.

struct OpenChatIntent: AppIntent {
  static let title: LocalizedStringResource = "Open Chat"
  static let description = IntentDescription("Opens a chat in Hermes.")
  static var supportedModes: IntentModes { .foreground }

  @Parameter(title: "Chat")
  var chat: ChatEntity

  static var parameterSummary: some ParameterSummary {
    Summary("Open \(\.$chat) in Hermes")
  }

  func link(in directory: IntentDirectory) -> URL {
    directory.link(opening: chat)
  }

  func perform() async throws -> some IntentResult & OpensIntent {
    .result(opensIntent: OpenURLIntent(link(in: .current())))
  }
}

struct NewChatIntent: AppIntent {
  static let title: LocalizedStringResource = "New Chat"
  static let description = IntentDescription("Opens a new Hermes chat.")
  static var supportedModes: IntentModes { .foreground }

  @Parameter(title: "Profile", description: "The Hermes profile; the app's current one if empty.")
  var profile: ProfileEntity?

  static var parameterSummary: some ParameterSummary {
    Summary("New chat in \(\.$profile)")
  }

  func link(in directory: IntentDirectory) -> URL {
    directory.newChatLink(profile: profile, dictate: false)
  }

  func perform() async throws -> some IntentResult & OpensIntent {
    .result(opensIntent: OpenURLIntent(link(in: .current())))
  }
}

struct DictateIntent: AppIntent {
  static let title: LocalizedStringResource = "Dictate"
  static let description = IntentDescription(
    "Opens a new Hermes chat with the microphone on. Nothing is sent until you send it.")
  static var supportedModes: IntentModes { .foreground }

  @Parameter(title: "Profile", description: "The Hermes profile; the app's current one if empty.")
  var profile: ProfileEntity?

  static var parameterSummary: some ParameterSummary {
    Summary("Dictate in \(\.$profile)")
  }

  func link(in directory: IntentDirectory) -> URL {
    directory.newChatLink(profile: profile, dictate: true)
  }

  func perform() async throws -> some IntentResult & OpensIntent {
    .result(opensIntent: OpenURLIntent(link(in: .current())))
  }
}

/// The configuration and the action of the Open Chat control. A control is
/// added before a chat is chosen, so unlike [OpenChatIntent] its chat is
/// optional; until one is chosen it opens the chat list.
struct OpenChatControlIntent: ControlConfigurationIntent {
  static let title: LocalizedStringResource = "Open Chat"
  static let description = IntentDescription("Opens the chat you chose in Hermes.")
  static var supportedModes: IntentModes { .foreground }

  @Parameter(title: "Chat")
  var chat: ChatEntity?

  /// The chat's current title, so a rename shows without choosing it again.
  func title(in directory: IntentDirectory) -> String {
    guard let chat else { return "Open Chat" }
    return directory.chats(withIDs: [chat.id]).first?.title ?? ChatEntity.untitled
  }

  func link(in directory: IntentDirectory) -> URL {
    chat.map(directory.link(opening:)) ?? DeepLink.requests
  }

  func perform() async throws -> some IntentResult & OpensIntent {
    .result(opensIntent: OpenURLIntent(link(in: .current())))
  }
}
