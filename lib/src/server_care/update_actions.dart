import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../widgets/dialog_presentation.dart';
import 'hermes_update_run.dart';
import 'replies_in_progress.dart';
import 'server_care_controller.dart';
import 'widgets/update_confirm_dialog.dart';
import 'widgets/update_run_view.dart';
import 'widgets/update_status_card.dart';

/// The lines of the update question, from what is running: that Hermes
/// restarts and chats pause, how many replies in this app stop, and how many
/// conversations on messaging channels stop. A count that is zero or unknown
/// leaves its line out.
List<String> updateConfirmationLines(
  AppLocalizations l10n, {
  required int replies,
  required int conversations,
}) => [
  l10n.serverCareUpdateConfirmRestarts,
  if (replies > 0) l10n.serverCareUpdateConfirmReplies(replies),
  if (conversations > 0)
    l10n.serverCareUpdateConfirmConversations(conversations),
];

/// Asks first, then updates: nothing is sent before the person confirms, and
/// Cancel sends nothing. A press while a run is going does nothing.
Future<void> runUpdate(BuildContext context) async {
  final run = context.read<HermesUpdateRun>();
  if (run.busy) return;
  final l10n = context.l10n;
  final lines = updateConfirmationLines(
    l10n,
    replies: repliesInProgressOf(context),
    conversations:
        context.read<ServerCareController>().status?.activeAgents ?? 0,
  );
  run.beginConfirmation();
  final confirmed =
      await showAppDialog<bool>(
        context: context,
        builder: (_) => UpdateConfirmDialog(
          title: l10n.serverCareUpdateConfirmTitle,
          lines: lines,
          confirmLabel: l10n.serverCareUpdateConfirmAction,
          cancelLabel: l10n.serverCareCancel,
        ),
      ) ??
      false;
  if (!confirmed || !context.mounted) {
    if (run.phase == UpdatePhase.confirming) run.dismiss();
    return;
  }
  run.confirmed();
  await run.start();
}

/// What the Update page shows for [run]; null while there is nothing to show
/// but the check (idle, or the question being asked).
UpdateRunView? updateRunViewOf(AppLocalizations l10n, HermesUpdateRun run) {
  final lines = run.lines;
  UpdateRunProgress progress(UpdateProgressStage stage) =>
      UpdateRunProgress(stage: stage, detailLines: lines);
  return switch (run.phase) {
    UpdatePhase.idle || UpdatePhase.confirming => null,
    UpdatePhase.starting => progress(UpdateProgressStage.starting),
    UpdatePhase.updating => progress(UpdateProgressStage.installing),
    UpdatePhase.restarting => progress(UpdateProgressStage.restarting),
    UpdatePhase.verifying => progress(UpdateProgressStage.checking),
    UpdatePhase.finished => switch (run.result) {
      UpdateResult.success => UpdateRunOutcome(
        kind: UpdateOutcomeKind.success,
        version: run.postVersion ?? run.versionNow,
      ),
      UpdateResult.partial => UpdateRunOutcome(
        kind: UpdateOutcomeKind.partial,
        items: run.reasons,
      ),
      UpdateResult.failed || UpdateResult.interrupted => UpdateRunOutcome(
        kind: UpdateOutcomeKind.failed,
        version: run.versionNow ?? run.versionBefore,
        detailLines: lines,
      ),
      UpdateResult.unknown || null => UpdateRunOutcome(
        kind: UpdateOutcomeKind.unconfirmed,
        version: run.versionNow,
      ),
    },
    UpdatePhase.staleServer => UpdateRunOutcome(
      kind: UpdateOutcomeKind.oldServerRunning,
      runningVersion: run.versionNow ?? run.versionBefore,
      installedVersion: run.postVersion,
    ),
    UpdatePhase.notBack => const UpdateRunOutcome(
      kind: UpdateOutcomeKind.notBack,
    ),
    UpdatePhase.refused => UpdateRunRefused(
      message: run.refusalMessage ?? l10n.serverCareUpdateOnServer,
      command: run.refusalCommand,
    ),
    // The update request itself was refused: nothing started, so this is a
    // page with a way out, not a result that may still be coming.
    UpdatePhase.unauthorized when run.nothingStarted => UpdateRunRefused(
      message: l10n.serverCareUpdateNotStartedUnauthorized,
    ),
    UpdatePhase.unauthorized => const UpdateRunOutcome(
      kind: UpdateOutcomeKind.unauthorized,
    ),
  };
}
