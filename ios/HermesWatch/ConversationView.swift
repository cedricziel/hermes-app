import SwiftUI

struct ConversationView: View {
  @Environment(\.dismiss) private var dismiss
  @State var model: ConversationModel
  /// The chat's title; nil for a new chat.
  var title: String?
  var startRecording = false
  @State private var draft = ""
  @State private var recorder = VoiceRecorder()
  @AppStorage("voiceFastSend") private var voiceFastSend = false
  @State private var reading = ConversationReadingPosition()
  @FocusState private var editingDraft: Bool
  @State private var restoringUnsentDraft = false
  @State private var draftLifecycle = 0
  @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

  init(model: ConversationModel, title: String? = nil, startRecording: Bool = false, draft: String = "") {
    self.model = model
    self.title = title
    self.startRecording = startRecording
    self._draft = State(initialValue: draft)
  }

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
            VStack(alignment: .leading, spacing: 4) {
              MessageBubble(message: message)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(ConversationPresentation.messageLabel(role: message.role, content: message.content))
              if let state = model.deliveryStates[message.id], state != .completed {
                Text(model.deliveryLabel(messageId: message.id) ?? ConversationPresentation.deliveryLabel(state))
                  .font(.footnote)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }.id(message.id)
          }
          if model.phase == .transcribing {
            WorkingRow(text: "Transcribing…")
          }
          if model.phase == .sending {
            WorkingRow(text: "Hermes is thinking…")
          }
          if case .waiting(let waiting) = model.phase {
            WorkingRow(text: waiting == .question ? "Hermes has a question" : "Waiting for your approval")
            Button("Stop waiting") { model.stopWaiting() }
          }
          if model.phase == .failed(.contextChanged) {
            Text(HermesClientError.contextChanged.message)
            Button("Open chat list") { dismiss() }
          } else if case .failed(let error) = model.phase, model.recovery == nil, model.unsent == nil, model.voice.state == .idle {
            ErrorView(error: error) { Task { await retry() } }
          }
          if let unsent = model.unsent, model.recovery == nil {
            if case .failed(let error) = model.phase { Text(error.message).fixedSize(horizontal: false, vertical: true) }
            RecoveryControls(state: .notSent, hasThread: false,
              checked: model.phase != .failed(.updateRequired) && model.phase != .failed(.recoveryStorage) && model.phase != .failed(.recoveryCapacity),
              disabled: model.busy, check: {}, open: {},
              resend: { Task { await model.send(unsent) } }, forget: {},
              edit: editUnsentAction,
              discard: { Task { await model.discardUnsent() } })
          }
          if let recovery = model.recovery {
            if case .failed(let error) = model.phase { Text(error.message).fixedSize(horizontal: false, vertical: true) }
            RecoveryControls(state: recovery.recoveryState, hasThread: recovery.threadId != nil,
              checked: model.canSendAgain, disabled: model.busy,
              check: { Task { await model.checkResult() } },
              open: { Task { await model.openRecoveryChat() } },
              resend: { Task { await model.requestSendAgain() } },
              forget: { Task { await model.forgetRecovery() } },
              edit: editUnsentAction,
              discard: { Task { await model.discardUnsent() } })
          }
          Color.clear.frame(height: 1)
            .background(GeometryReader { geometry in
              Color.clear.preference(key: CurrentTurnPosition.self,
                value: geometry.frame(in: .named("conversationViewport")).minY)
            })
          if model.phase != .failed(.signedOut), model.phase != .failed(.contextChanged) { composer.id("composer") }
        }
      }
      .coordinateSpace(name: "conversationViewport")
      .background(GeometryReader { geometry in
        Color.clear.preference(key: ConversationViewportHeight.self, value: geometry.size.height)
      })
      .overlay(alignment: .bottom) {
        if reading.newReplyId != nil {
          Button("New reply") {
            if let id = reading.revealReply() { withAnimation { proxy.scrollTo(id, anchor: .top) } }
          }
          .accessibilityHint("Moves to the beginning of the new Hermes answer")
        }
      }
      .onPreferenceChange(CurrentTurnPosition.self) { position in
        reading.setFollowing(position >= 0 && position <= viewportHeight)
      }
      .onPreferenceChange(ConversationViewportHeight.self) { viewportHeight = $0 }
      .onChange(of: model.completedReplyId) { _, completion in
        if let id = reading.completedReply(id: completion, preservingFocus: voiceOverEnabled || editingDraft || model.voice.state != .idle) {
          withAnimation { proxy.scrollTo(id, anchor: .top) }
        }
      }
    }
    .alert("Send this request again?", isPresented: Binding(get: { model.resendConfirmation }, set: { _ in })) {
      Button("Cancel", role: .cancel) { model.cancelSendAgain() }
      Button("Send again") { Task { await model.confirmSendAgain() } }
    } message: {
      Text("The original message may already have reached Hermes. Sending again can run the request twice.")
    }
    .navigationTitle(model.permitsOriginalTitle ? (title ?? "New Chat") : "New Chat")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      if startRecording { await recorder.start() }
      await model.load()
      #if DEBUG
        if DemoClient.enabled, let text = DemoClient.startupText { await model.send(text) }
      #endif
    }
    .onDisappear { draftLifecycle += 1; recorder.cancel(); model.discardVoice(); model.leaveConversation(); draft = "" }
    .onChange(of: model.phase) { _, phase in
      if phase == .failed(.signedOut) || phase == .failed(.contextChanged) { draftLifecycle += 1; draft = ""; recorder.cancel() }
    }
    .advertisesHandoff(model.threadId.map { WatchSessionState.shared.owns($0) } == true ? model.handoff : nil)
    .onChange(of: recorder.state) { _, state in
      if state == .finished { Task { await submitRecording() } }
    }
  }

  private var busy: Bool { !model.canCompose || restoringUnsentDraft }
  private var editUnsentAction: (() -> Void)? {
    guard ConversationPresentation.canRestoreUnsentDraft(composer: draft, handoffInProgress: restoringUnsentDraft) else { return nil }
    return { Task { await restoreUnsentDraft() } }
  }

  private func restoreUnsentDraft() async {
    guard ConversationPresentation.canRestoreUnsentDraft(composer: draft, handoffInProgress: restoringUnsentDraft) else { return }
    restoringUnsentDraft = true
    let lifecycle = draftLifecycle
    defer { restoringUnsentDraft = false }
    if let text = await model.editUnsent(), lifecycle == draftLifecycle,
      model.phase != .failed(.signedOut), model.phase != .failed(.contextChanged) {
      draft = text
      editingDraft = true
    }
  }
  @State private var viewportHeight: CGFloat = 0

  @ViewBuilder
  private var composer: some View {
    if model.voice.state != .idle {
      VoiceReviewControls(state: model.voice.state,
        text: Binding(get: { model.voiceText }, set: { model.voiceText = $0 }),
        error: voiceError, retryDisabled: model.busy, sendDisabled: !model.canCompose, send: { Task { await model.sendVoiceDraft() } },
        retry: { Task { await model.retryVoice() } },
        recordAgain: { model.discardVoice(); Task { await recorder.start() } },
        discard: { model.discardVoice() })
    } else {
      switch recorder.state {
      case .recording:
        TimelineView(.periodic(from: .now, by: 1)) { context in
          Text("Recording \(Int(min(context.date.timeIntervalSince(recorder.startedAt ?? context.date), VoiceRecorder.maxDuration))) of 30 seconds")
            .accessibilityLabel("Recording")
            .accessibilityValue("\(Int(min(context.date.timeIntervalSince(recorder.startedAt ?? context.date), VoiceRecorder.maxDuration))) of 30 seconds")
        }
        Button {
          Task { await submitRecording() }
        } label: {
          Label(voiceFastSend ? "Stop and send" : "Stop and review", systemImage: "stop.circle.fill")
        }
        .accessibilityHint(voiceFastSend ? "Stops recording and sends after transcription" : "Stops recording for transcript review")
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
        Toggle("Send after manual stop", isOn: $voiceFastSend)
          .accessibilityHint("Off by default. Manually stopped recordings send after transcription. Interrupted or capped recordings always need review.")
          .disabled(busy)
        QuickReplies(disabled: busy) { text in Task { await model.send(text) } }
        HStack {
          TextField("Reply", text: $draft)
            .focused($editingDraft)
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
        if !draft.isEmpty {
          Button("Discard draft") { draft = ""; editingDraft = false }
            .accessibilityHint("Clears the editable draft without sending")
        }
      }
    }
  }

  private var voiceError: String? {
    if case .failed(let error) = model.phase { return error.message }
    return nil
  }

  private func submitRecording() async {
    let fastSend = voiceFastSend
    guard let recording = recorder.stop() else { return }
    await model.sendVoice(recording.audio, mimeType: VoiceRecorder.mimeType, reason: recording.reason, fastSend: fastSend)
  }

  private func submit() async {
    guard model.canCompose else { return }
    let text = draft
    draft = ""
    await model.send(text)
  }

  private func retry() async {
    if let unsent = model.unsent {
      await model.send(unsent)
    } else if model.unsentVoice != nil {
      await model.retryVoice()
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
          .fixedSize(horizontal: false, vertical: true)
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
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct CurrentTurnPosition: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct ConversationViewportHeight: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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

extension View {
  /// Lets a nearby iPhone or Mac continue the chat. The type is the one the
  /// apps declare, merged into this target's Info.plist from the same
  /// `HERMES_HANDOFF_TYPE` setting.
  @ViewBuilder
  fileprivate func advertisesHandoff(_ target: HandoffTarget?) -> some View {
    if let type = (Bundle.main.object(forInfoDictionaryKey: "NSUserActivityTypes") as? [String])?.first {
      userActivity(type, isActive: target != nil) { activity in
        guard let target else { return }
        activity.title = "Continue chat in Hermes"
        activity.userInfo = target.userInfo
        activity.requiredUserInfoKeys = HandoffTarget.requiredKeys
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false
        activity.isEligibleForPublicIndexing = false
      }
    } else {
      self
    }
  }
}

#if DEBUG
  #Preview("Empty new chat") {
    NavigationStack { ConversationView(model: ConversationModel(client: DemoClient(), threadId: nil)) }
  }
  #Preview("Editable starter draft") {
    NavigationStack {
      ConversationView(model: ConversationModel(client: DemoClient(), threadId: nil), draft: "Review the backup plan")
    }.environment(\.dynamicTypeSize, .accessibility5)
  }
  #Preview("Conversation at maximum text size") {
    NavigationStack {
      ConversationView(model: ConversationModel(client: DemoClient(), threadId: DemoClient.threads[0].id))
    }.environment(\.dynamicTypeSize, .accessibility5)
  }
  #Preview("Signed out") {
    let session = WatchSessionState()
    session.invalidate()
    return NavigationStack {
      ConversationView(model: ConversationModel(client: DemoClient(), threadId: nil, session: session))
    }
  }
#endif
