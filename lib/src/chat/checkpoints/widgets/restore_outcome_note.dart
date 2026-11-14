import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../widgets/app_banner.dart';
import '../checkpoint_models.dart';
import '../checkpoints_state.dart';

/// What a restore ended with, as a banner in the Activity panel: the words and
/// the icon carry it, the tone only helps. It says only what is known. A
/// failure part-way never says nothing changed, a safety checkpoint is
/// claimed only when [RestoreOutcome.safetyCheckpoint] is true, and no file
/// name appears, so the polite announcement is always in fixed words.
///
/// [filesWereFile] is true for a restore of one file (the chat is not
/// touched) and false for all files. [onTryAgain] draws the Try again button
/// for the outcomes that offer it (no answer, session gone); the caller asks
/// for a new confirmation first. [RestoreOutcomeKind.unsupported] draws
/// nothing.
class RestoreOutcomeNote extends StatelessWidget {
  const RestoreOutcomeNote({
    super.key,
    required this.outcome,
    required this.filesWereFile,
    this.onTryAgain,
  });

  final RestoreOutcome outcome;
  final bool filesWereFile;
  final VoidCallback? onTryAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = restoreOutcomeParts(
      l10n,
      outcome,
      filesWereFile: filesWereFile,
    );
    if (parts == null) return const SizedBox.shrink();
    final tryAgain = parts.offersTryAgain ? onTryAgain : null;
    return AppBanner(
      tone: parts.tone,
      title: parts.title,
      detail: parts.detail,
      action: tryAgain == null
          ? null
          : TextButton(
              onPressed: tryAgain,
              child: Text(l10n.chatCheckpointsOutcomeTryAgain),
            ),
    );
  }
}

/// The words and tone of one outcome, before they are drawn.
class RestoreOutcomeParts {
  const RestoreOutcomeParts({
    required this.tone,
    required this.title,
    this.detail = '',
    this.offersTryAgain = false,
  });

  final AppBannerTone tone;
  final String title;

  /// Sentences, one per line.
  final String detail;
  final bool offersTryAgain;
}

/// The words of [outcome], or null for [RestoreOutcomeKind.unsupported], which
/// is not drawn. [l10n] is passed in so the wording stays in one place and a
/// test can read it without a widget.
RestoreOutcomeParts? restoreOutcomeParts(
  AppLocalizations l10n,
  RestoreOutcome outcome, {
  required bool filesWereFile,
}) {
  String lines(List<String> sentences) => sentences.join('\n');
  final listReread = filesWereFile
      ? l10n.chatCheckpointsOutcomeListReread
      : l10n.chatCheckpointsOutcomeListAndChatReread;
  switch (outcome.kind) {
    case RestoreOutcomeKind.unsupported:
      return null;
    case RestoreOutcomeKind.restored:
      final count = outcome.filesRestored;
      final title = filesWereFile
          ? l10n.chatCheckpointsOutcomeRestoredCount(1)
          : count == null
          ? l10n.chatCheckpointsOutcomeRestoredUnknown
          : l10n.chatCheckpointsOutcomeRestoredCount(count);
      return RestoreOutcomeParts(
        tone: AppBannerTone.success,
        title: title,
        detail: lines([
          if (filesWereFile) l10n.chatCheckpointsOutcomeChatUnchanged,
          ?switch (outcome.safetyCheckpoint) {
            true => l10n.chatCheckpointsOutcomeSafetySaved,
            false => l10n.chatCheckpointsOutcomeSafetyNone,
            null => null,
          },
          if (!filesWereFile && outcome.lastMessageNotRemoved)
            l10n.chatCheckpointsOutcomeLastMessageNotRemoved,
        ]),
      );
    case RestoreOutcomeKind.historyNotRewound:
      return RestoreOutcomeParts(
        tone: AppBannerTone.warning,
        title: l10n.chatCheckpointsOutcomeHistoryNotRewoundTitle,
        detail: lines([
          l10n.chatCheckpointsOutcomeHistoryNotRewoundDetail,
          l10n.chatCheckpointsOutcomeListAndChatReread,
        ]),
      );
    case RestoreOutcomeKind.refused:
      return switch (outcome.refusal) {
        CheckpointFailureKind.nestedRepositories => RestoreOutcomeParts(
          tone: AppBannerTone.neutral,
          title: l10n.chatCheckpointsOutcomeRefusedNested,
          detail: l10n.chatCheckpointsOutcomeNothingChanged,
        ),
        CheckpointFailureKind.notFound => RestoreOutcomeParts(
          tone: AppBannerTone.neutral,
          title: l10n.chatCheckpointsOutcomeRefusedNotFound,
          detail: l10n.chatCheckpointsOutcomeListReread,
        ),
        CheckpointFailureKind.container => RestoreOutcomeParts(
          tone: AppBannerTone.neutral,
          title: l10n.chatCheckpointsOutcomeRefusedContainer,
          detail: l10n.chatCheckpointsOutcomeNothingChanged,
        ),
        _ => RestoreOutcomeParts(
          tone: AppBannerTone.neutral,
          title: l10n.chatCheckpointsOutcomeFailedTitle,
          detail: l10n.chatCheckpointsOutcomeNothingChanged,
        ),
      };
    case RestoreOutcomeKind.busyReplying:
      return RestoreOutcomeParts(
        tone: AppBannerTone.neutral,
        title: l10n.chatCheckpointsOutcomeBusyReplying,
      );
    case RestoreOutcomeKind.busyCompressing:
      return RestoreOutcomeParts(
        tone: AppBannerTone.neutral,
        title: l10n.chatCheckpointsOutcomeBusyCompressing,
      );
    case RestoreOutcomeKind.mayHaveHappened:
      return RestoreOutcomeParts(
        tone: AppBannerTone.warning,
        title: l10n.chatCheckpointsOutcomeMayHaveHappenedTitle,
        detail: lines([
          l10n.chatCheckpointsOutcomeMayHaveHappenedDetail,
          l10n.chatCheckpointsOutcomeListAndChatReread,
        ]),
        offersTryAgain: true,
      );
    case RestoreOutcomeKind.failedMaybeChanged:
      return RestoreOutcomeParts(
        tone: AppBannerTone.error,
        title: l10n.chatCheckpointsOutcomeFailedTitle,
        detail: lines([
          l10n.chatCheckpointsOutcomeFailedMaybeChangedDetail,
          listReread,
        ]),
      );
    case RestoreOutcomeKind.failedNothingChanged:
      return RestoreOutcomeParts(
        tone: AppBannerTone.neutral,
        title: l10n.chatCheckpointsOutcomeFailedTitle,
        detail: l10n.chatCheckpointsOutcomeNothingChanged,
      );
    case RestoreOutcomeKind.sessionGone:
      return RestoreOutcomeParts(
        tone: AppBannerTone.warning,
        title: l10n.chatCheckpointsOutcomeSessionGone,
        offersTryAgain: true,
      );
  }
}

/// The centred transcript line after a restore, for `TranscriptOutcomeLine`,
/// or null when the outcome is not a success. [removedMessages] is true when
/// the server removed the last message (history_removed above zero); the line
/// then says so, and otherwise claims no message removed. The count is used
/// only when it was read, else "Files restored".
String? transcriptLineForRestore(
  AppLocalizations l10n,
  RestoreOutcome outcome, {
  required bool removedMessages,
}) {
  if (outcome.kind != RestoreOutcomeKind.restored) return null;
  final count = outcome.filesRestored;
  if (removedMessages && outcome.lastMessageNotRemoved) {
    // History was removed, but not the message this app expected to lose:
    // say the chat was rewound without naming a message.
    return count == null
        ? l10n.chatCheckpointsOutcomeTranscriptRestoredUnknownRewound
        : l10n.chatCheckpointsOutcomeTranscriptRestoredCountRewound(count);
  }
  if (removedMessages) {
    return count == null
        ? l10n.chatCheckpointsOutcomeTranscriptRestoredUnknownRemoved
        : l10n.chatCheckpointsOutcomeTranscriptRestoredCountRemoved(count);
  }
  return count == null
      ? l10n.chatCheckpointsOutcomeRestoredUnknown
      : l10n.chatCheckpointsOutcomeRestoredCount(count);
}
