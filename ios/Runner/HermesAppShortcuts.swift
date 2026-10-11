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

/// `hermes_app/intents`: Dart calls `refreshShortcuts` after the surface
/// snapshot changed, so Siri hears the chats as they are now.
enum IntentsChannel {
  static func install(messenger: FlutterBinaryMessenger) {
    FlutterMethodChannel(name: "hermes_app/intents", binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "refreshShortcuts" else {
          return result(FlutterMethodNotImplemented)
        }
        HermesAppShortcuts.updateAppShortcutParameters()
        result(nil)
      }
  }
}
