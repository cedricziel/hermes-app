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

// The label is fixed: a control shows on a locked device, so it never carries
// the chat's title.
struct OpenChatControl: ControlWidget {
  struct Provider: AppIntentControlValueProvider {
    func previewValue(configuration: OpenChatControlIntent) -> OpenChatControlIntent {
      configuration
    }

    func currentValue(configuration: OpenChatControlIntent) async throws -> OpenChatControlIntent {
      configuration
    }
  }

  var body: some ControlWidgetConfiguration {
    AppIntentControlConfiguration(
      kind: "com.cedricziel.hermesApp.control.open-chat", provider: Provider()
    ) { intent in
      ControlWidgetButton(action: intent) {
        Label("Open Chat", systemImage: "bubble.left")
      }
    }
    .displayName("Open Chat")
    .description("Open a chat you choose in Hermes.")
  }
}
