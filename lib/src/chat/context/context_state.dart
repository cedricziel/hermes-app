import 'context_models.dart' show ContextSource;

/// Where the user opened the Context details from.
enum ContextOpenFrom { row, suggestion, menu }

/// How full the window is, for the row's wording and emphasis.
enum ContextLevel { normal, nearlyFull, critical, full }

/// Why a compress cannot start now.
enum CompressRefusal {
  /// Nothing confirmed a live session for this chat, or the server has no
  /// `session.compress`.
  unavailable,
  disconnected,
  locked,
  replying,
  compressing,
}

enum CompressOutcomeKind {
  compressed,
  nothingToCompress,
  wouldNotShrink,
  aborted,
  busyReplying,
  busyCompressing,
  lockHeld,
  pending,

  /// No answer, or the connection dropped. The chat and usage were re-read;
  /// the action is offered again behind a new confirmation.
  couldntConfirm,
  failed,
  unsupported,
}

class CompressOutcome {
  const CompressOutcome(
    this.kind, {
    this.beforeMessages,
    this.afterMessages,
    this.beforeTokens,
    this.afterTokens,
    this.fallbackUsed = false,
  });

  final CompressOutcomeKind kind;
  final int? beforeMessages, afterMessages, beforeTokens, afterTokens;
  final bool fallbackUsed;
}

/// The figures the Context row shows, straight from the usage snapshot.
/// Anything the server did not report is null, never zero.
class ContextFigures {
  const ContextFigures({
    required this.used,
    required this.max,
    required this.percent,
    required this.estimated,
    required this.source,
  });
  final int used, max, percent;
  final bool? estimated;
  final ContextSource? source;
}
