import SwiftUI

struct ConversationView: View {
  @State var model: ConversationModel
  var startRecording = false
  @State private var draft = ""
  @State private var recorder = VoiceRecorder()

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 8) {
          if model.phase == .loading {
            ProgressView()
          }
          ForEach(model.messages) { message in
            MessageBubble(message: message).id(message.id)
          }
          if model.phase == .transcribing {
            Text("Transcribing…").foregroundStyle(.secondary)
          }
          if model.phase == .sending {
            Text("Hermes is thinking…").foregroundStyle(.secondary)
          }
          if case .failed(let error) = model.phase {
            ErrorView(error: error) { Task { await retry() } }
          }
          composer.id("composer")
        }
      }
      .onChange(of: model.messages.count) {
        withAnimation { proxy.scrollTo("composer") }
      }
    }
    .navigationTitle("Chat")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      if startRecording { await recorder.start() }
      await model.load()
    }
    .onDisappear { recorder.cancel() }
  }

  private var busy: Bool {
    model.phase == .sending || model.phase == .loading || model.phase == .transcribing
  }

  @ViewBuilder
  private var composer: some View {
    switch recorder.state {
    case .recording:
      Button {
        Task { await submitRecording() }
      } label: {
        Label("Stop and send", systemImage: "stop.circle.fill")
      }
      .tint(.red)
    case .idle, .denied, .failed:
      if recorder.state == .denied {
        Text("Allow microphone access for Hermes in Settings.").foregroundStyle(.secondary)
      } else if recorder.state == .failed {
        Text("Couldn't start recording.").foregroundStyle(.secondary)
      }
      HStack {
        TextField("Reply", text: $draft)
          .onSubmit { Task { await submit() } }
        Button {
          Task { await recorder.start() }
        } label: {
          Image(systemName: "mic.fill")
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Record a voice message")
      }
      .disabled(busy)
    }
  }

  private func submitRecording() async {
    guard let audio = recorder.stop() else { return }
    await model.sendVoice(audio, mimeType: VoiceRecorder.mimeType)
  }

  private func submit() async {
    let text = draft
    draft = ""
    await model.send(text)
  }

  private func retry() async {
    if let unsent = model.unsent {
      await model.send(unsent)
    } else if let audio = model.unsentVoice {
      await model.sendVoice(audio, mimeType: VoiceRecorder.mimeType)
    } else if model.phase == .failed(.noSpeech) {
      await recorder.start()
    } else {
      await model.load()
    }
  }
}

private struct MessageBubble: View {
  let message: ChatMessage

  var body: some View {
    Text(message.content)
      .padding(8)
      .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
      .background(
        message.role == .user ? Color.accentColor.opacity(0.35) : Color.gray.opacity(0.25),
        in: RoundedRectangle(cornerRadius: 10)
      )
  }
}
