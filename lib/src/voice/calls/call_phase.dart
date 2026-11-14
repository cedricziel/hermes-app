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
enum CallNotice { transcription, speechFailed }
