import AppIntents
import SwiftUI
import WidgetKit

// Control Center, Lock Screen and Action button controls. Each runs an intent
// that opens Hermes on a `hermes://` link; iOS asks to unlock a locked device
// first. The intents and the chat picker live in HermesSurfaceKit and read
// only the surface snapshot.

struct NewChatControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "com.cedricziel.hermesApp.control.new-chat") {
      ControlWidgetButton(action: NewChatIntent()) {
        Label("New Chat", systemImage: "square.and.pencil")
      }
    }
    .displayName("New Chat")
    .description("Start a new chat in Hermes.")
  }
}

struct DictateControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "com.cedricziel.hermesApp.control.dictate") {
      ControlWidgetButton(action: DictateIntent()) {
        Label("Dictate", systemImage: "mic.fill")
      }
    }
    .displayName("Dictate")
    .description("Start a new chat and speak your message.")
  }
}

struct OpenChatControl: ControlWidget {
  struct Value: Sendable {
    let intent: OpenChatControlIntent
    let title: String
  }

  struct Provider: AppIntentControlValueProvider {
    // The gallery never shows the user's own chats.
    func previewValue(configuration: OpenChatControlIntent) -> Value {
      Value(intent: configuration, title: "Open Chat")
    }

    func currentValue(configuration: OpenChatControlIntent) async throws -> Value {
      Value(intent: configuration, title: configuration.title(in: .current()))
    }
  }

  var body: some ControlWidgetConfiguration {
    AppIntentControlConfiguration(
      kind: "com.cedricziel.hermesApp.control.open-chat", provider: Provider()
    ) { value in
      ControlWidgetButton(action: value.intent) {
        Label(value.title, systemImage: "bubble.left")
      }
    }
    .displayName("Open Chat")
    .description("Open a chat you choose in Hermes.")
  }
}
