enum CallPhase {
  connecting,
  listening,

  /// From the end of what the user said until the prompt reached the chat.
  /// End or mute in this phase sends nothing.
  sending,
  thinking,
  speaking,
  attention,
  ended,
  failed,
}

/// Why the call shows a notice, in fixed words the screen turns into text.
enum CallNotice {
  transcription,
  speechFailed,

  /// The microphone could not be confirmed closed when the call ended.
  microphoneMayBeOpen,

  /// Five minutes of silence ended the call.
  idle,

  /// The app was hidden, which ends a call everywhere but on iOS.
  left,
}
