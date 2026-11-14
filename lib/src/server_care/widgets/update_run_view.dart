import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/platform_chrome.dart';
import 'update_status_card.dart';
import 'update_step_list.dart';

/// Where a running update is, as the step list shows it.
enum UpdateProgressStage { starting, installing, restarting, checking }

/// What the Update page shows once an update has been confirmed: the steps
/// while it runs, or how it ended. Plain data, so the catalog can show every
/// case without a run.
sealed class UpdateRunView {
  const UpdateRunView();
}

/// The update is going: one card of four steps.
class UpdateRunProgress extends UpdateRunView {
  const UpdateRunProgress({required this.stage, this.detailLines = const []});

  final UpdateProgressStage stage;

  /// The last lines Hermes wrote, behind "Show details".
  final List<String> detailLines;
}

/// The update ended, or stopped being followed; see [UpdateOutcomeCard] for
/// what each field says.
class UpdateRunOutcome extends UpdateRunView {
  const UpdateRunOutcome({
    required this.kind,
    this.version,
    this.items = const [],
    this.runningVersion,
    this.installedVersion,
    this.detailLines = const [],
  });

  final UpdateOutcomeKind kind;
  final String? version;
  final List<String> items;
  final String? runningVersion;
  final String? installedVersion;
  final List<String> detailLines;
}

/// Hermes (or its receipt) refused the update: its message and, when it gave
/// one, the command to run on the server.
class UpdateRunRefused extends UpdateRunView {
  const UpdateRunRefused({required this.message, this.command});

  final String message;
  final String? command;
}

/// The body of the Update page for a [view], with the buttons its outcome
/// offers wired to the callbacks.
class UpdateRunBody extends StatelessWidget {
  const UpdateRunBody({
    super.key,
    required this.view,
    this.onDone,
    this.onTryAgain,
    this.onCheckAgain,
    this.onKeepWaiting,
    this.onDismiss,
    this.onCopied,
    this.detailsInitiallyOpen = false,
  });

  final UpdateRunView view;
  final VoidCallback? onDone;
  final VoidCallback? onTryAgain;
  final VoidCallback? onCheckAgain;
  final VoidCallback? onKeepWaiting;
  final VoidCallback? onDismiss;
  final VoidCallback? onCopied;
  final bool detailsInitiallyOpen;

  @override
  Widget build(BuildContext context) => switch (view) {
    UpdateRunProgress(:final stage, :final detailLines) => UpdateStepList(
      steps: _steps(stage),
      detailLines: detailLines,
      detailsInitiallyOpen: detailsInitiallyOpen,
    ),
    UpdateRunOutcome(
      :final kind,
      :final version,
      :final items,
      :final runningVersion,
      :final installedVersion,
      :final detailLines,
    ) =>
      UpdateOutcomeCard(
        kind: kind,
        version: version,
        items: items,
        runningVersion: runningVersion,
        installedVersion: installedVersion,
        detailLines: detailLines,
        detailsInitiallyOpen: detailsInitiallyOpen,
        onDone: onDone,
        onTryAgain: onTryAgain,
        onCheckAgain: onCheckAgain,
        onKeepWaiting: onKeepWaiting,
        onDismiss: onDismiss,
      ),
    UpdateRunRefused(:final message, :final command) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UpdateStatusCard(
          status: UpdateCannotApply(message: message, command: command),
          onCopied: onCopied,
        ),
        const SizedBox(height: 16),
        TextButton(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(
              Size(0, platformChromeOf(context).isApple ? 44 : 48),
            ),
          ),
          onPressed: onDone,
          child: Text(context.l10n.serverCareUpdateOutcomeDone),
        ),
      ],
    ),
  };

  static List<UpdateStep> _steps(UpdateProgressStage stage) {
    UpdateStepState at(UpdateProgressStage step) =>
        switch (step.index.compareTo(stage.index)) {
          < 0 => UpdateStepState.done,
          0 => UpdateStepState.running,
          _ => UpdateStepState.pending,
        };
    return [
      UpdateStep.starting(at(UpdateProgressStage.starting)),
      UpdateStep.installing(at(UpdateProgressStage.installing)),
      UpdateStep.restarting(at(UpdateProgressStage.restarting)),
      UpdateStep.checking(at(UpdateProgressStage.checking)),
    ];
  }
}
