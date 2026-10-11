import AppIntents
import Flutter

/// The phrases that make the intents work by voice without setup. It lives in
/// the Runner only: a second provider in the widget extension would make the
/// phrases ambiguous. The wording comes from the watch's own shortcuts.
struct HermesAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: NewChatIntent(),
      phrases: [
        "New \(.applicationName) chat",
        "Start a \(.applicationName) chat",
      ],
      shortTitle: "New Chat",
      systemImageName: "square.and.pencil"
    )
    AppShortcut(
      intent: DictateIntent(),
      phrases: [
        "Talk to \(.applicationName)",
        "Voice chat with \(.applicationName)",
        "Dictate to \(.applicationName)",
      ],
      shortTitle: "Dictate",
      systemImageName: "mic.fill"
    )
    AppShortcut(
      intent: AskHermesIntent(),
      phrases: [
        "Ask \(.applicationName)",
        "Ask \(.applicationName) something",
      ],
      shortTitle: "Ask Hermes",
      systemImageName: "text.bubble"
    )
    AppShortcut(
      intent: OpenChatIntent(),
      phrases: ["Open \(\.$chat) in \(.applicationName)"],
      shortTitle: "Open Chat",
      systemImageName: "bubble.left"
    )
    AppShortcut(
      intent: PendingRequestsIntent(),
      phrases: [
        "What does \(.applicationName) need",
        "\(.applicationName) requests",
        "Pending \(.applicationName) requests",
      ],
      shortTitle: "Pending Requests",
      systemImageName: "bell.badge"
    )
  }
}

/// `hermes_app/shortcuts`: Dart calls `refreshShortcuts` after the surface
/// snapshot changed, so Siri hears the chats as they are now. It is installed
/// in every engine, the background ones included, and does nothing else, so
/// it never competes with the App Intents channel for the app's engine.
enum ShortcutsChannel {
  static func install(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "hermes_app/shortcuts", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "refreshShortcuts" else {
          return result(FlutterMethodNotImplemented)
        }
        HermesAppShortcuts.updateAppShortcutParameters()
        result(nil)
      }
  }
}

/// `hermes_app/intents` on the app's engine, for "Ask Hermes" (`IntentsBridge`).
enum IntentsChannel {
  @MainActor
  static func install(messenger: FlutterBinaryMessenger) {
    IntentsBridge.shared.attach(messenger: messenger, isApp: true)
  }
}
