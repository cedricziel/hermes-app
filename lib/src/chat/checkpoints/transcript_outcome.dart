/// What a transcript outcome line reports.
enum TranscriptOutcomeKind { compressed, restored }

/// A line under the transcript after a compress or a restore settled well,
/// such as "Conversation compressed · 42 → 9 messages". It holds counts and
/// flags only, never text, and lives in memory with its chat: it is not a
/// message, so a re-read of the chat keeps it.
class TranscriptOutcome {
  const TranscriptOutcome({
    required this.kind,
    required this.at,
    this.beforeMessages,
    this.afterMessages,
    this.files,
    this.removedMessages = false,
    this.fallbackUsed = false,
  });

  final TranscriptOutcomeKind kind;

  /// The message counts of a compress, when Hermes reported them.
  final int? beforeMessages, afterMessages;

  /// The files a restore put back, when known.
  final int? files;

  /// A full restore also removed the chat's last turn.
  final bool removedMessages;

  /// Hermes used a placeholder summary for the compress.
  final bool fallbackUsed;

  /// When the outcome settled, for ordering only.
  final DateTime at;
}
