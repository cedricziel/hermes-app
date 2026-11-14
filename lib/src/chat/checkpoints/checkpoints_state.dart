import 'checkpoint_models.dart' show CheckpointFailureKind;

/// What the File checkpoints row says.
enum CheckpointsRowState {
  hidden,

  /// A stored chat with no live session: "Not checked yet".
  notChecked,
  loading,
  count,

  /// Off on the server, and the chat ran an edit tool call.
  off,
  failed,
}

/// Why a restore cannot start now.
enum RestoreRefusal {
  unavailable,
  disconnected,
  locked,

  /// A full restore waits for the reply to finish.
  replying,
  restoring,

  /// Only a path read back exactly from this checkpoint's `stat` is offered.
  fileNotOffered,
}

enum RestoreOutcomeKind {
  restored,
  historyNotRewound,
  refused,
  busyReplying,
  busyCompressing,

  /// No answer or a dropped connection: the files may have been restored.
  mayHaveHappened,
  failedMaybeChanged,
  failedNothingChanged,
  sessionGone,
  unsupported,
}

class RestoreOutcome {
  const RestoreOutcome(
    this.kind, {
    this.filesRestored,
    this.historyRemoved = 0,
    this.refusal,
    this.safetyCheckpoint,
    this.lastMessageNotRemoved = false,
  });

  final RestoreOutcomeKind kind;

  /// Only when read from this checkpoint's changes since the last turn ended
  /// ("Restored N files"); null reads "Files restored".
  final int? filesRestored;
  final int historyRemoved;
  final CheckpointFailureKind? refusal;

  /// Whether the re-read list holds a new "Before a restore" checkpoint for
  /// this restore: true, false, or null when the list could not be re-read.
  final bool? safetyCheckpoint;

  /// A full restore that removed messages but not the one the confirmation
  /// quoted, so the composer was left alone.
  final bool lastMessageNotRemoved;
}
