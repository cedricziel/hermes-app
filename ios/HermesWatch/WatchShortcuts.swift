import AppIntents
import Observation

/// What a shortcut asked the app to open. The thread list picks it up and
/// clears it.
@MainActor
@Observable
final class LaunchRequests {
  enum Request: Equatable {
    case newChat
    case voiceChat
    case thread(id: String, title: String)
  }

  static let shared = LaunchRequests()

  var pending: Request?

  /// Queues what a tap on a complication asked for. A link to the app alone
  /// asks for nothing.
  func open(_ url: URL) {
    switch ComplicationLink(url: url) {
    case .voice: pending = .voiceChat
    case .chat(let id, let title): pending = .thread(id: id, title: title ?? "Hermes")
    case .open, nil: break
    }
  }
}

struct NewChatIntent: AppIntent {
  static let title: LocalizedStringResource = "New Chat"
  static let description = IntentDescription("Opens a new Hermes chat.")
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    LaunchRequests.shared.pending = .newChat
    return .result()
  }
}

struct VoiceChatIntent: AppIntent {
  static let title: LocalizedStringResource = "Voice Chat"
  static let description = IntentDescription("Starts recording a voice message to Hermes in a new chat.")
  static let openAppWhenRun = true

  @MainActor
  func perform() async throws -> some IntentResult {
    LaunchRequests.shared.pending = .voiceChat
    return .result()
  }
}

/// Makes both intents show up in Shortcuts on the watch, so they can be put on
/// the Action button.
struct HermesWatchShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: VoiceChatIntent(),
      phrases: ["Talk to \(.applicationName)", "Voice chat with \(.applicationName)"],
      shortTitle: "Voice Chat",
      systemImageName: "mic.fill"
    )
    AppShortcut(
      intent: NewChatIntent(),
      phrases: ["New \(.applicationName) chat"],
      shortTitle: "New Chat",
      systemImageName: "square.and.pencil"
    )
  }
}
