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

  /// The audio route changed and the turn being heard was dropped; nothing
  /// of it was sent.
  routeChanged,

  /// The same, while an earlier turn is already submitted and answering, so
  /// the screen does not say that nothing was sent.
  routeChangedNeutral,

  /// The app was hidden, which ends a call everywhere but on iOS.
  left,

  /// A reply is running or a queue is about to send, so the turn was not sent.
  busy,

  /// A queue holds prompts that wait for the user and no reply runs: the turn
  /// was not sent.
  queuePaused,

  /// The chat refused the turn for another reason the call survives (the
  /// model, a branch, the persisted queue): nothing was sent.
  notSent,

  /// Hermes will answer the words after the reply it is running.
  hermesQueued,

  /// Hermes took the words into the reply it is running.
  hermesSteered,

  /// Hermes is adjusting the reply it is running to the words.
  hermesRedirected,
}
