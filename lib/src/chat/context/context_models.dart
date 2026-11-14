/// What `session.context_breakdown` and `session.compress` answer, read
/// leniently. The server's labels, rule file paths, model names, summaries and
/// error text never leave this file.
library;

import '../checkpoints/checkpoint_models.dart'
    show CheckpointBusyReason, CheckpointFailureKind;

/// A token or message count above this is not believed.
const kContextCountLimit = 10000000;

/// The eight categories the server splits the window into. An id the app does
/// not know is [other], never shown under the server's own label.
enum ContextCategoryKind {
  systemPrompt,
  toolDefinitions,
  rules,
  skills,
  mcp,
  subagentDefinitions,
  memory,
  conversation,
  other,
}

class ContextCategory {
  const ContextCategory(this.kind, this.tokens);
  final ContextCategoryKind kind;
  final int tokens;
}

/// Where `context_used` came from.
enum ContextSource {
  localEstimate,
  providerUsage,
  providerUsagePlusEstimate,
  unknown,
}

ContextSource parseContextSource(Object? value) => switch (value) {
  'local_estimate' => ContextSource.localEstimate,
  'provider_usage' => ContextSource.providerUsage,
  'provider_usage_plus_estimate' => ContextSource.providerUsagePlusEstimate,
  _ => ContextSource.unknown,
};

sealed class ContextBreakdown {
  const ContextBreakdown();
}

/// Any figure the server did not send, or sent out of range, is null:
/// unknown, never zero.
final class Breakdown extends ContextBreakdown {
  const Breakdown({
    required this.categories,
    this.used,
    this.max,
    this.percent,
    this.estimated,
    this.estimatedTotal,
    this.source = ContextSource.unknown,
    this.model,
  });

  /// Largest first. Empty before the agent is built.
  final List<ContextCategory> categories;
  final int? used, max, estimatedTotal;

  /// Clamped to 0..100.
  final int? percent;
  final bool? estimated;
  final ContextSource source;

  /// Shown on the details page only; never recorded.
  final String? model;
}

final class BreakdownUnsupported extends ContextBreakdown {
  const BreakdownUnsupported();
}

final class BreakdownFailed extends ContextBreakdown {
  const BreakdownFailed(this.kind);
  final CheckpointFailureKind kind;
}

int? _count(Object? value) =>
    value is int && value >= 0 && value <= kContextCountLimit ? value : null;

ContextCategoryKind _kindOf(Object? id) => switch (id) {
  'system_prompt' => ContextCategoryKind.systemPrompt,
  'tool_definitions' => ContextCategoryKind.toolDefinitions,
  'rules' => ContextCategoryKind.rules,
  'skills' => ContextCategoryKind.skills,
  'mcp' => ContextCategoryKind.mcp,
  'subagent_definitions' => ContextCategoryKind.subagentDefinitions,
  'memory' => ContextCategoryKind.memory,
  'conversation' => ContextCategoryKind.conversation,
  _ => ContextCategoryKind.other,
};

/// Reads `session.context_breakdown`.
Breakdown parseBreakdown(Map<String, Object?> result) {
  final categories = <ContextCategory>[];
  final rows = result['categories'];
  if (rows is List) {
    for (final row in rows) {
      if (row is! Map) continue;
      final tokens = _count(row['tokens']);
      if (tokens == null) continue;
      categories.add(ContextCategory(_kindOf(row['id']), tokens));
    }
  }
  // Largest first; List.sort is not stable, so ties keep the server's order.
  final ordered =
      [for (var i = 0; i < categories.length; i++) (i, categories[i])]..sort(
        (a, b) => b.$2.tokens != a.$2.tokens
            ? b.$2.tokens.compareTo(a.$2.tokens)
            : a.$1.compareTo(b.$1),
      );
  final percent = result['context_percent'];
  final model = result['model'];
  return Breakdown(
    categories: List.unmodifiable([for (final entry in ordered) entry.$2]),
    used: _count(result['context_used']),
    max: _count(result['context_max']),
    estimatedTotal: _count(result['estimated_total']),
    percent: percent is int && percent >= 0
        ? (percent > 100 ? 100 : percent)
        : null,
    estimated: result['context_estimated'] is bool
        ? result['context_estimated'] as bool
        : null,
    source: parseContextSource(result['context_source']),
    model: model is String && model.trim().isNotEmpty ? model : null,
  );
}

sealed class CompressionResult {
  const CompressionResult();
}

final class Compressed extends CompressionResult {
  const Compressed({
    this.beforeMessages,
    this.afterMessages,
    this.beforeTokens,
    this.afterTokens,
    this.fallbackUsed = false,
  });

  /// Shown as returned: a result where `before < after` is not corrected.
  final int? beforeMessages, afterMessages, beforeTokens, afterTokens;
  final bool fallbackUsed;
}

final class NothingToCompress extends CompressionResult {
  const NothingToCompress();
}

/// The summary could not be written; the chat is unchanged.
final class CompressionAborted extends CompressionResult {
  const CompressionAborted();
}

final class WouldNotShrink extends CompressionResult {
  const WouldNotShrink();
}

final class CompressBusy extends CompressionResult {
  const CompressBusy(this.reason);
  final CheckpointBusyReason reason;
}

/// Another compression holds the lock.
final class CompressLockHeld extends CompressionResult {
  const CompressLockHeld();
}

/// A compute-host session compresses in the background.
final class CompressPending extends CompressionResult {
  const CompressPending();
}

final class CompressUnsupported extends CompressionResult {
  const CompressUnsupported();
}

/// No answer, or the connection dropped after the request went out. The app
/// re-reads and never sends again.
final class CompressMayHaveHappened extends CompressionResult {
  const CompressMayHaveHappened();
}

final class CompressFailed extends CompressionResult {
  const CompressFailed(this.kind);
  final CheckpointFailureKind kind;
}

/// Reads `session.compress`.
CompressionResult parseCompression(Map<String, Object?> result) {
  if (result['status'] == 'pending') return const CompressPending();
  if (result['lock_held'] == true) return const CompressLockHeld();
  final summary = result['summary'];
  bool flag(String key) => summary is Map && summary[key] == true;
  if (result['status'] == 'aborted' || flag('aborted')) {
    return const CompressionAborted();
  }
  if (flag('refused_would_grow')) return const WouldNotShrink();
  if (flag('noop')) return const NothingToCompress();
  if (result['status'] != 'compressed') {
    return const CompressFailed(CheckpointFailureKind.other);
  }
  return Compressed(
    beforeMessages: _count(result['before_messages']),
    afterMessages: _count(result['after_messages']),
    beforeTokens: _count(result['before_tokens']),
    afterTokens: _count(result['after_tokens']),
    fallbackUsed: flag('fallback_used'),
  );
}

/// Whether [focus] is safe to send as `focus_topic`. The server reads that
/// text as the `/compress` argument string: it strips `--preview`,
/// `--dry-run`, `--dryrun` and `--aggressive` anywhere and reads a first word
/// `here`, or text starting `up to here`, as a partial compress. So a focus
/// with any word starting `-`, a first word `here` (any case) or starting
/// `up to here` is refused.
bool isAcceptableFocus(String focus) {
  final text = focus.trim().toLowerCase();
  if (text.isEmpty) return true;
  final words = text.split(RegExp(r'\s+'));
  if (words.any((word) => word.startsWith('-'))) return false;
  if (words.first == 'here') return false;
  return !text.startsWith('up to here');
}
