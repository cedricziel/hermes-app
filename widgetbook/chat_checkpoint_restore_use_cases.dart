import 'package:flutter/material.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoint_models.dart';
import 'package:hermes_app/src/chat/checkpoints/checkpoints_state.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/restore_all_confirmation.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/restore_file_confirmation.dart';
import 'package:hermes_app/src/chat/checkpoints/widgets/restore_outcome_note.dart';
import 'package:widgetbook/widgetbook.dart';

import 'frame.dart';

const _lastPrompt = 'Split the token refresh out';

const _longPrompt =
    'Split the token refresh out of the auth controller into its own class, '
    'keep the public API the same, move the retry rules next to it, add a '
    'test for the expired-token path and for two refreshes at once, and '
    'then update the architecture note so it says where the lock lives and '
    'why a second refresh waits for the first one instead of starting its own.';

/// A confirmation as a sheet shows it: a bounded surface of at most
/// [maxHeight], so a body that is too long for it scrolls. [scale] is the text
/// scale factor.
Widget _sheet(Widget content, {double scale = 1, double maxHeight = 800}) =>
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: content,
            ),
          ),
        ),
      ),
    );

RestoreFileConfirmation _file({bool agentWorking = false}) =>
    RestoreFileConfirmation(
      fileName: 'src/auth/token_refresh.dart',
      timeLabel: '12 min ago',
      reason: CheckpointReason.beforeEdit,
      agentWorking: agentWorking,
      onConfirm: () {},
      onCancel: () {},
    );

RestoreAllConfirmation _all({
  int? differingFiles = 5,
  String? quotedPrompt = _lastPrompt,
  bool replying = false,
  CheckpointReason reason = CheckpointReason.beforeEdit,
}) => RestoreAllConfirmation(
  timeLabel: '12 min ago',
  reason: reason,
  differingFiles: differingFiles,
  quotedPrompt: quotedPrompt,
  replying: replying,
  onConfirm: () {},
  onCancel: () {},
);

WidgetbookUseCase _outcome(
  String name,
  RestoreOutcome outcome, {
  bool oneFile = false,
  bool tryAgain = false,
  double scale = 1,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) => frame(
    Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: RestoreOutcomeNote(
          outcome: outcome,
          filesWereFile: oneFile,
          onTryAgain: tryAgain ? () {} : null,
        ),
      ),
    ),
    maxWidth: 420,
  ),
);

WidgetbookFolder chatCheckpointRestoreNode() => WidgetbookFolder(
  name: 'Chat checkpoint restore',
  children: [
    WidgetbookComponent(
      name: 'RestoreFileConfirmation',
      useCases: [
        ...onEachPlatform('Idle', (_) => _sheet(_file())),
        ...onEachPlatform(
          'Agent working',
          (_) => _sheet(_file(agentWorking: true)),
        ),
        ...onEachPlatform(
          'Largest text',
          (_) => _sheet(_file(agentWorking: true), scale: 3, maxHeight: 560),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'RestoreAllConfirmation',
      useCases: [
        ...onEachPlatform('N files known', (_) => _sheet(_all())),
        WidgetbookUseCase(
          name: 'N files unknown',
          builder: (_) => _sheet(_all(differingFiles: null)),
        ),
        WidgetbookUseCase(
          name: 'No message to quote',
          builder: (_) => _sheet(_all(quotedPrompt: null)),
        ),
        WidgetbookUseCase(
          name: 'Long quoted message (fade)',
          builder: (_) => _sheet(_all(quotedPrompt: _longPrompt)),
        ),
        WidgetbookUseCase(
          name: 'Checkpoint taken before a restore',
          builder: (_) => _sheet(_all(reason: CheckpointReason.beforeRestore)),
        ),
        ...onEachPlatform(
          'Replying (disabled)',
          (_) => _sheet(_all(replying: true)),
        ),
        WidgetbookUseCase(
          name: 'Largest text, 2x',
          builder: (_) =>
              _sheet(_all(quotedPrompt: _longPrompt), scale: 2, maxHeight: 800),
        ),
        ...onEachPlatform(
          'Largest text, 3x',
          (_) =>
              _sheet(_all(quotedPrompt: _longPrompt), scale: 3, maxHeight: 800),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'RestoreOutcomeNote',
      useCases: [
        _outcome(
          'Restored 3 files, new safety checkpoint',
          const RestoreOutcome(
            RestoreOutcomeKind.restored,
            filesRestored: 3,
            historyRemoved: 2,
            safetyCheckpoint: true,
          ),
        ),
        _outcome(
          'Restored, count unknown, no new safety checkpoint',
          const RestoreOutcome(
            RestoreOutcomeKind.restored,
            historyRemoved: 2,
            safetyCheckpoint: false,
          ),
        ),
        _outcome(
          'Restored, list could not be re-read',
          const RestoreOutcome(
            RestoreOutcomeKind.restored,
            filesRestored: 1,
            historyRemoved: 2,
          ),
        ),
        _outcome(
          'Restored, no message removed',
          const RestoreOutcome(
            RestoreOutcomeKind.restored,
            filesRestored: 3,
            safetyCheckpoint: true,
          ),
        ),
        _outcome(
          'Restored, last message not the one removed',
          const RestoreOutcome(
            RestoreOutcomeKind.restored,
            historyRemoved: 2,
            safetyCheckpoint: true,
            lastMessageNotRemoved: true,
          ),
        ),
        _outcome(
          'Restored one file',
          const RestoreOutcome(
            RestoreOutcomeKind.restored,
            filesRestored: 1,
            safetyCheckpoint: true,
          ),
          oneFile: true,
        ),
        _outcome(
          'Restored one file, no new safety checkpoint',
          const RestoreOutcome(
            RestoreOutcomeKind.restored,
            filesRestored: 1,
            safetyCheckpoint: false,
          ),
          oneFile: true,
        ),
        _outcome(
          'Files restored, chat not rewound',
          const RestoreOutcome(RestoreOutcomeKind.historyNotRewound),
        ),
        _outcome(
          'Refused: nested projects',
          const RestoreOutcome(
            RestoreOutcomeKind.refused,
            refusal: CheckpointFailureKind.nestedRepositories,
          ),
        ),
        _outcome(
          'Refused: checkpoint gone',
          const RestoreOutcome(
            RestoreOutcomeKind.refused,
            refusal: CheckpointFailureKind.notFound,
          ),
        ),
        _outcome(
          'Refused: workspace not covered',
          const RestoreOutcome(
            RestoreOutcomeKind.refused,
            refusal: CheckpointFailureKind.container,
          ),
        ),
        _outcome(
          'Refused: other',
          const RestoreOutcome(
            RestoreOutcomeKind.refused,
            refusal: CheckpointFailureKind.pathRejected,
          ),
        ),
        _outcome(
          'Busy: replying',
          const RestoreOutcome(RestoreOutcomeKind.busyReplying),
        ),
        _outcome(
          'Busy: compressing',
          const RestoreOutcome(RestoreOutcomeKind.busyCompressing),
        ),
        _outcome(
          'No answer, with Try again',
          const RestoreOutcome(RestoreOutcomeKind.mayHaveHappened),
          tryAgain: true,
        ),
        _outcome(
          'Failed part-way, some may have changed',
          const RestoreOutcome(RestoreOutcomeKind.failedMaybeChanged),
        ),
        _outcome(
          'Failed part-way, one file',
          const RestoreOutcome(RestoreOutcomeKind.failedMaybeChanged),
          oneFile: true,
        ),
        _outcome(
          'Failed, nothing changed',
          const RestoreOutcome(RestoreOutcomeKind.failedNothingChanged),
        ),
        _outcome(
          'Chat connection lost, with Try again',
          const RestoreOutcome(RestoreOutcomeKind.sessionGone),
          tryAgain: true,
        ),
        _outcome(
          'Largest text, no answer with Try again',
          const RestoreOutcome(RestoreOutcomeKind.mayHaveHappened),
          tryAgain: true,
          scale: 3,
        ),
      ],
    ),
  ],
);
