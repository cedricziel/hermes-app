import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../theme/app_icons.dart';
import '../../activity/activity_page_binding.dart';
import '../../activity/widgets/activity_page_scaffold.dart';
import '../../activity/widgets/activity_working_line.dart';
import '../../chat_controller.dart';
import '../../chat_models.dart';
import '../checkpoint_models.dart';
import '../checkpoints_controller.dart';
import '../widgets/checkpoint_list_body.dart';
import '../widgets/restore_outcome_note.dart';
import 'changes_page.dart';
import 'restore_flow.dart';

/// The "File checkpoints" page, pushed inside the Activity panel: the
/// checkpoints of [thread]'s folder, newest first, with Refresh in the bar
/// and pull to refresh. A tap opens a checkpoint's changes; its menu offers
/// Restore all files…, behind a confirmation.
///
/// A stored chat that was not checked yet is resumed and listed when the
/// page opens. After a restore of all files the re-read list comes back with
/// the outcome note on top.
class CheckpointsPage extends StatefulWidget {
  const CheckpointsPage({super.key, required this.chat, required this.thread});

  final ChatController chat;
  final ChatThread thread;

  /// The name of this page's route, so a flow can come back to it.
  static const routeName = 'activity/checkpoints';

  static Route<void> route({
    required ChatController chat,
    required ChatThread thread,
  }) => MaterialPageRoute<void>(
    settings: const RouteSettings(name: routeName),
    builder: (_) => CheckpointsPage(chat: chat, thread: thread),
  );

  @override
  State<CheckpointsPage> createState() => _CheckpointsPageState();
}

class _CheckpointsPageState extends State<CheckpointsPage>
    with ActivityPageBinding<CheckpointsPage, CheckpointsController> {
  /// Whether this page opened the list itself, outside a panel.
  var _openedHere = false;

  @override
  ChatController get chat => widget.chat;

  @override
  ChatThread get thread => widget.thread;

  @override
  CheckpointsController? lookUpController() => switch (currentThread) {
    final thread? => widget.chat.checkpointsIn(thread),
    null => null,
  };

  @override
  bool lockedOf(CheckpointsController controller) => controller.locked;

  @override
  void initState() {
    super.initState();
    bindController();
    // After the first frame: reading notifies, and this runs while the
    // navigator builds.
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  void _read() {
    final controller = this.controller;
    if (!mounted || controller == null || controller.locked) return;
    // A page with no panel under it (a standalone route) keeps the list
    // current for as long as it is open, so it holds the lifecycle itself.
    if (!controller.panelOpen) {
      _openedHere = true;
      unawaited(controller.panelOpened());
    }
    if (controller.rowState == CheckpointsRowState.notChecked) {
      unawaited(controller.openResuming());
    }
  }

  @override
  void dispose() {
    unbindController();
    final controller = this.controller;
    if (_openedHere && controller != null) {
      scheduleMicrotask(controller.panelClosed);
    }
    super.dispose();
  }

  Future<void> _refresh() async => controller?.openResuming();

  CheckpointListStatus _status(CheckpointsController controller) {
    if (controller.locked) return CheckpointListStatus.locked;
    final listed = controller.checkpoints;
    if (controller.loadingList && listed.isEmpty) {
      return CheckpointListStatus.loading;
    }
    return switch (controller.rowState) {
      CheckpointsRowState.count =>
        listed.isEmpty
            ? CheckpointListStatus.empty
            : CheckpointListStatus.loaded,
      CheckpointsRowState.off => CheckpointListStatus.off,
      CheckpointsRowState.failed =>
        controller.listFailure == CheckpointFailureKind.container
            ? CheckpointListStatus.notCovered
            : CheckpointListStatus.failed,
      CheckpointsRowState.loading => CheckpointListStatus.loading,
      // Not read: the resume did not start (no connection) or the server
      // has no list for this chat. Try again reads it.
      CheckpointsRowState.notChecked => CheckpointListStatus.failed,
      CheckpointsRowState.hidden => CheckpointListStatus.empty,
    };
  }

  void _seeChanges(String hash) {
    unawaited(
      Navigator.of(context).push(
        ChangesPage.route(
          chat: widget.chat,
          thread: currentThread ?? widget.thread,
          hash: hash,
        ),
      ),
    );
  }

  void _restoreAll(String hash) {
    final controller = this.controller;
    if (controller == null) return;
    unawaited(
      confirmRestoreFlow(
        context,
        controller: controller,
        changes: widget.chat,
        hash: hash,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = this.controller;
    if (controller == null) return const SizedBox.shrink();
    final outcome = controller.outcome;
    // A file's outcome goes on its Changes page; this list shows the others.
    final showOutcome =
        outcome != null &&
        !controller.locked &&
        lastRestoreWasFile(controller) != true;
    return ActivityPageScaffold(
      title: l10n.chatCheckpointsPageTitle,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        ActivityPageAction(
          key: const Key('checkpoints-refresh'),
          label: l10n.chatCheckpointsPageRefresh,
          icon: AppIcons.refresh,
          onPressed: controller.loadingList || controller.notUpToDate
              ? null
              : _refresh,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.restoring)
            ActivityWorkingLine(label: l10n.chatCheckpointsPageRestoring),
          if (showOutcome)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: RestoreOutcomeNote(
                key: const Key('checkpoints-outcome'),
                outcome: outcome,
                filesWereFile: false,
                onTryAgain: () => unawaited(
                  restoreAgainFlow(
                    context,
                    controller: controller,
                    changes: widget.chat,
                  ),
                ),
              ),
            ),
          Expanded(
            child: CheckpointListBody(
              status: _status(controller),
              items: [
                for (final checkpoint in controller.checkpoints)
                  CheckpointListItem(
                    checkpoint: checkpoint,
                    timeLabel: _startOfLine(
                      checkpointTimeLabel(l10n, checkpoint),
                    ),
                    timeSemanticsLabel: checkpointTimeSemantics(
                      l10n,
                      checkpoint,
                    ),
                  ),
              ],
              disconnected: controller.notUpToDate,
              restoreRefusal: controller.restoreRefusal(),
              lockedCount: controller.count,
              onSeeChanges: _seeChanges,
              onRestoreAll: _restoreAll,
              onRetry: () => unawaited(_refresh()),
              onRefresh: controller.notUpToDate ? null : _refresh,
            ),
          ),
        ],
      ),
    );
  }
}

/// [label] as it starts a line: "yesterday" reads "Yesterday" under a row's
/// title, though the same words go lower case inside a sentence.
String? _startOfLine(String? label) => label == null || label.isEmpty
    ? label
    : label[0].toUpperCase() + label.substring(1);
