import SwiftUI

struct VoiceReviewControls: View {
  let state: VoiceDraft.State
  @Binding var text: String
  let error: String?
  var retryDisabled = false
  var sendDisabled = false
  let send: () -> Void
  let retry: () -> Void
  let recordAgain: () -> Void
  let discard: () -> Void
  @State private var editing = false

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      switch state {
      case .review:
        Text("Review voice message").font(.headline)
        if editing {
          TextField("Voice message", text: $text)
            .accessibilityLabel("Edit voice transcript")
            .accessibilityHint("Changes the message that Send submits")
        } else {
          Text(text).fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Voice transcript: \(text)")
        }
        Button("Send voice message", action: send)
          .disabled(sendDisabled || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .accessibilityHint("Sends the reviewed transcript to Hermes")
        Button(editing ? "Done editing" : "Edit transcript") { editing.toggle() }
          .accessibilityHint("Changes the voice message before sending")
      case .failed:
        Text(error ?? "Couldn't transcribe recording.").fixedSize(horizontal: false, vertical: true)
        Button("Retry transcription", action: retry)
          .disabled(retryDisabled)
          .accessibilityHint("Transcribes the saved recording again without sending")
      case .noSpeech:
        Text("No speech was recognized.").fixedSize(horizontal: false, vertical: true)
        Button("Record again", action: recordAgain)
          .accessibilityHint("Starts a new voice recording")
      case .transcribing:
        Label("Transcribing voice message", systemImage: "waveform")
      case .idle:
        EmptyView()
      }
      if state != .idle {
        Button("Discard voice message", role: .destructive, action: discard)
          .accessibilityHint("Deletes the transcript and recording without sending")
      }
    }
  }
}

#if DEBUG
#Preview("Voice transcript, maximum text") {
  ScrollView {
    VoiceReviewControls(state: .review,
      text: .constant("Please review the backup schedule for each server and explain why the nightly backup copies all media again. Keep the existing backup and do not change any files."),
      error: nil, send: {}, retry: {}, recordAgain: {}, discard: {})
  }.environment(\.dynamicTypeSize, .accessibility5)
}
#Preview("Voice transcription failed") {
  ScrollView {
    VoiceReviewControls(state: .failed, text: .constant(""), error: "Phone isn't reachable.",
      send: {}, retry: {}, recordAgain: {}, discard: {})
  }
}
#Preview("Voice no speech") {
  VoiceReviewControls(state: .noSpeech, text: .constant(""), error: nil,
    send: {}, retry: {}, recordAgain: {}, discard: {})
}
#Preview("Voice pending, VoiceOver labels") {
  VoiceReviewControls(state: .transcribing, text: .constant(""), error: nil,
    send: {}, retry: {}, recordAgain: {}, discard: {})
}
#endif
