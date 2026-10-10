import SwiftUI

struct ConversationView: View {
  @State var model: ConversationModel
  /// The chat's title; nil for a new chat.
  var title: String?
  var startRecording = false
  @State private var draft = ""
  @State private var recorder = VoiceRecorder()

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        // Not lazy: a lazy stack guesses the height of unmeasured rows, and with
        // long messages the jump to the composer lands past the content on a
        // blank screen.
        VStack(alignment: .leading, spacing: 8) {
          if model.phase == .loading, model.messages.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
          }
          ForEach(model.messages) { message in
            MessageBubble(message: message).id(message.id)
          }
          if model.phase == .transcribing {
            WorkingRow(text: "Transcribing…")
          }
          if model.phase == .sending {
            WorkingRow(text: "Hermes is thinking…")
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
    .navigationTitle(title ?? "New Chat")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      if startRecording { await recorder.start() }
      await model.load()
    }
    .onDisappear { recorder.cancel() }
    .onChange(of: recorder.state) { _, state in
      if state == .finished { Task { await submitRecording() } }
    }
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
      .handGestureShortcut(.primaryAction)
    case .finished:
      ProgressView()
    case .idle, .denied, .failed:
      if recorder.state == .denied {
        Text("Allow microphone access for Hermes in Settings.").foregroundStyle(.secondary)
      } else if recorder.state == .failed {
        Text("Couldn't start recording.").foregroundStyle(.secondary)
      }
      QuickReplies(disabled: busy) { text in Task { await model.send(text) } }
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
        .handGestureShortcut(.primaryAction)
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

/// One-tap answers to the usual follow-ups; a tap sends like the field does.
private struct QuickReplies: View {
  static let texts = ["Continue", "Yes", "No", "Summarize"]

  let disabled: Bool
  let send: (String) -> Void

  var body: some View {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
      ForEach(Self.texts, id: \.self) { text in
        Button(text) { send(text) }
          .font(.footnote)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
    }
    .disabled(disabled)
  }
}

/// The user's messages sit in a bubble on the right; Hermes' replies run
/// across the screen as text, with the tools it used above them.
private struct MessageBubble: View {
  let message: ChatMessage

  var body: some View {
    switch message.role {
    case .user:
      HStack {
        Spacer(minLength: 20)
        Text(message.content)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.accentColor.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
      }
    case .assistant:
      VStack(alignment: .leading, spacing: 4) {
        if !message.tools.isEmpty {
          Label(message.tools.joined(separator: ", "), systemImage: "wrench.and.screwdriver")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        Text(WatchMarkdown.attributed(message.content))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct WorkingRow: View {
  let text: String

  var body: some View {
    HStack(spacing: 6) {
      ProgressView().frame(width: 18, height: 18)
      Text(text).foregroundStyle(.secondary)
    }
  }
}
