import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../widgets/app_banner.dart';
import '../context_state.dart';
import 'context_format.dart';

/// The messages part of a compress result, "42 → 9 messages", or null when
/// the server did not report both counts.
String? _messages(AppLocalizations l10n, CompressOutcome outcome) {
  final before = outcome.beforeMessages, after = outcome.afterMessages;
  if (before == null || after == null) return null;
  return l10n.chatContextOutcomeMessages(before, after);
}

String? _tokens(AppLocalizations l10n, CompressOutcome outcome) {
  final before = outcome.beforeTokens, after = outcome.afterTokens;
  if (before == null || after == null) return null;
  return l10n.chatContextOutcomeTokens(
    contextTokensShort(l10n, before),
    contextTokensShort(l10n, after),
  );
}

/// The muted line the transcript shows after a compress, "Conversation
/// compressed · 42 → 9 messages": counts only, never the summary or the focus.
/// Null for every other outcome, which is a note in the panel.
String? transcriptLineForCompress(
  AppLocalizations l10n,
  CompressOutcome outcome,
) {
  if (outcome.kind != CompressOutcomeKind.compressed) return null;
  final before = outcome.beforeMessages, after = outcome.afterMessages;
  if (before == null || after == null) return l10n.chatContextOutcomeCompressed;
  return l10n.chatContextTranscriptCompressed(before, after);
}

/// The note in the Activity panel for a compress result, in the shared
/// [AppBanner] (a polite live region). Success is green, results that changed
/// nothing are neutral, "may have happened" is a warning and a failure is red.
/// [onTryAgain] is offered where trying again makes sense, and opens a new
/// confirmation. An unsupported server draws nothing.
class CompressOutcomeNote extends StatelessWidget {
  const CompressOutcomeNote({
    super.key,
    required this.outcome,
    this.onTryAgain,
  });

  final CompressOutcome outcome;
  final VoidCallback? onTryAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = outcome.kind;
    final (tone, title, detail) = switch (kind) {
      CompressOutcomeKind.compressed => (
        AppBannerTone.success,
        l10n.chatContextOutcomeCompressed,
        [
          switch ((_messages(l10n, outcome), _tokens(l10n, outcome))) {
            (final m?, final t?) => l10n.chatContextOutcomeJoined(m, t),
            (final m?, null) => m,
            (null, final t?) => t,
            _ => '',
          },
          if (outcome.fallbackUsed) l10n.chatContextOutcomeFallback,
        ].where((line) => line.isNotEmpty).join('\n'),
      ),
      CompressOutcomeKind.nothingToCompress => (
        AppBannerTone.neutral,
        l10n.chatContextOutcomeNothing,
        '',
      ),
      CompressOutcomeKind.wouldNotShrink => (
        AppBannerTone.neutral,
        l10n.chatContextOutcomeWouldNotShrink,
        '',
      ),
      CompressOutcomeKind.aborted => (
        AppBannerTone.neutral,
        l10n.chatContextOutcomeAborted,
        '',
      ),
      CompressOutcomeKind.busyReplying => (
        AppBannerTone.neutral,
        l10n.chatContextOutcomeBusyReplying,
        '',
      ),
      CompressOutcomeKind.busyCompressing => (
        AppBannerTone.neutral,
        l10n.chatContextOutcomeBusyCompressing,
        '',
      ),
      CompressOutcomeKind.lockHeld => (
        AppBannerTone.neutral,
        l10n.chatContextOutcomeLockHeld,
        '',
      ),
      CompressOutcomeKind.pending => (
        AppBannerTone.neutral,
        l10n.chatContextOutcomePending,
        l10n.chatContextOutcomePendingDetail,
      ),
      CompressOutcomeKind.couldntConfirm => (
        AppBannerTone.warning,
        l10n.chatContextOutcomeCouldntConfirm,
        l10n.chatContextOutcomeCouldntConfirmDetail,
      ),
      CompressOutcomeKind.failed => (
        AppBannerTone.error,
        l10n.chatContextOutcomeFailed,
        '',
      ),
      CompressOutcomeKind.unsupported => (AppBannerTone.neutral, '', ''),
    };
    if (kind == CompressOutcomeKind.unsupported) return const SizedBox.shrink();
    final retry =
        (kind == CompressOutcomeKind.aborted ||
            kind == CompressOutcomeKind.couldntConfirm) &&
        onTryAgain != null;
    return AppBanner(
      tone: tone,
      title: title,
      detail: detail,
      action: retry
          ? TextButton(
              style: contextButtonStyle(context),
              onPressed: onTryAgain,
              child: Text(l10n.chatContextOutcomeTryAgain),
            )
          : null,
    );
  }
}
