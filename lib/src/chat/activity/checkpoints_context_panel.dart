import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../chat_controller.dart';
import '../chat_models.dart';
import '../checkpoints/checkpoints_controller.dart';
import '../checkpoints/pages/checkpoints_page.dart';
import '../checkpoints/pages/restore_flow.dart';
import '../checkpoints/widgets/file_checkpoints_row.dart';
import '../checkpoints/widgets/restore_outcome_note.dart';
import '../context/context_controller.dart';
import '../context/pages/compress_flow.dart';
import '../context/pages/context_details_page.dart';
import '../context/widgets/compress_outcome_note.dart';
import '../context/widgets/context_row.dart';
import 'widgets/activity_working_line.dart';

/// The Context and File checkpoints parts of one chat's Activity panel.
///
/// Both are reference activity: they add rows under This session and, while
/// a compress or restore the user confirmed runs, a working line under Now.
/// They never add a Needs-you item, mark the Activity button, reach the
/// activity line or post a notification, at any percentage.
class CheckpointsContextPanel {
  const CheckpointsContextPanel({
    required this.chat,
    required this.thread,
    this.context,
    this.checkpoints,
  });

  final ChatController chat;
  final ChatThread thread;
  final ContextController? context;
  final CheckpointsController? checkpoints;

  /// What the panel listens to, besides the chat.
  List<Listenable> get listenables => [?context, ?checkpoints];

  /// The working lines under Now.
  List<Widget> now(BuildContext context) {
    final l10n = context.l10n;
    final row = this.context, checkpoints = this.checkpoints;
    return [
      if (row != null && row.compressing && !row.locked)
        ActivityWorkingLine(
          key: const Key('working-compress'),
          label: l10n.chatContextCompressing,
        ),
      if (checkpoints != null && checkpoints.restoring && !checkpoints.locked)
        ActivityWorkingLine(
          key: const Key('working-restore'),
          label: l10n.chatCheckpointsPageRestoring,
        ),
    ];
  }

  /// The rows under This session, first in it: Context, File checkpoints,
  /// then the outcome notes of a compress and a restore.
  List<Widget> session(BuildContext context) {
    final row = this.context, checkpoints = this.checkpoints;
    final figures = row?.figures;
    final compressOutcome = row?.outcome;
    final restoreOutcome = checkpoints?.outcome;
    return [
      if (row != null && figures != null)
        ContextRow(
          key: const Key('context-row'),
          figures: figures,
          level: row.level,
          notUpToDate: row.notUpToDate,
          locked: row.locked,
          compressing: row.compressing,
          suggestionVisible: row.suggestionVisible,
          onOpen: () => _openContext(context),
          onCompress: () =>
              _openContext(context, from: ContextOpenFrom.suggestion),
          onDismissSuggestion: row.dismissSuggestion,
        ),
      if (checkpoints != null &&
          checkpoints.rowState != CheckpointsRowState.hidden)
        FileCheckpointsRow(
          state: checkpoints.rowState,
          count: checkpoints.count,
          locked: checkpoints.locked,
          onOpen: checkpoints.locked ? null : () => _openCheckpoints(context),
        ),
      if (row != null && compressOutcome != null && !row.locked)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: CompressOutcomeNote(
            key: const Key('panel-compress-outcome'),
            outcome: compressOutcome,
            onTryAgain: () => unawaited(
              confirmCompressFlow(context, controller: row, changes: chat),
            ),
          ),
        ),
      if (checkpoints != null && restoreOutcome != null && !checkpoints.locked)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: RestoreOutcomeNote(
            key: const Key('panel-restore-outcome'),
            outcome: restoreOutcome,
            filesWereFile: lastRestoreWasFile(checkpoints) ?? false,
            onTryAgain: () => unawaited(
              restoreAgainFlow(context, controller: checkpoints, changes: chat),
            ),
          ),
        ),
    ];
  }

  /// The suggestion's Compress… opens the details with the confirmation
  /// over them, so the user sees what compressing frees.
  void _openContext(
    BuildContext context, {
    ContextOpenFrom from = ContextOpenFrom.row,
  }) {
    unawaited(
      Navigator.of(context).push(
        ContextDetailsPage.route(
          chat: chat,
          thread: thread,
          from: from,
          compressOnOpen: from == ContextOpenFrom.suggestion,
        ),
      ),
    );
  }

  void _openCheckpoints(BuildContext context) {
    unawaited(
      Navigator.of(context)
          .push(CheckpointsPage.route(chat: chat, thread: thread)),
    );
  }
}

/// Tells [controller] the Activity panel is open while this widget is
/// shown, so the File checkpoints row lists the live session's checkpoints;
/// a stored chat without one waits for its row to be opened.
class CheckpointsPanelPresence extends StatefulWidget {
  const CheckpointsPanelPresence({
    super.key,
    required this.controller,
    required this.child,
  });

  final CheckpointsController? controller;
  final Widget child;

  @override
  State<CheckpointsPanelPresence> createState() =>
      _CheckpointsPanelPresenceState();
}

class _CheckpointsPanelPresenceState extends State<CheckpointsPanelPresence> {
  @override
  void initState() {
    super.initState();
    _open(widget.controller);
  }

  @override
  void didUpdateWidget(CheckpointsPanelPresence old) {
    super.didUpdateWidget(old);
    if (identical(old.controller, widget.controller)) return;
    _close(old.controller);
    _open(widget.controller);
  }

  @override
  void dispose() {
    _close(widget.controller);
    super.dispose();
  }

  /// Closing drops an open diff and notifies, so it waits for the build.
  void _close(CheckpointsController? controller) {
    if (controller != null) scheduleMicrotask(controller.panelClosed);
  }

  void _open(CheckpointsController? controller) {
    if (controller == null) return;
    // After the frame: opening notifies, and this runs while the panel
    // builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(widget.controller, controller)) {
        unawaited(controller.panelOpened());
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The Activity panel's own pages: [child] (the panel) is the first page,
/// and the Context and checkpoint pages push over it inside the sheet or the
/// inspector, with Back, Escape, ⌘[ and the system back gesture.
///
/// When the panel turns to another chat ([thread] with another id), its
/// pages close. The same chat read again, or given a new id by a compress,
/// keeps them.
class ActivityPanelNavigator extends StatefulWidget {
  const ActivityPanelNavigator({
    super.key,
    required this.thread,
    required this.child,
  });

  final ChatThread thread;
  final Widget child;

  @override
  State<ActivityPanelNavigator> createState() => _ActivityPanelNavigatorState();
}

class _ActivityPanelNavigatorState extends State<ActivityPanelNavigator> {
  final _navigator = GlobalKey<NavigatorState>();
  late ChatThread _thread = widget.thread;
  late String _threadId = widget.thread.id;

  @override
  void didUpdateWidget(ActivityPanelNavigator old) {
    super.didUpdateWidget(old);
    final thread = widget.thread;
    final switched = !identical(thread, _thread) && thread.id != _threadId;
    _thread = thread;
    _threadId = thread.id;
    if (switched) _navigator.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) => NavigatorPopHandler(
    onPopWithResult: (_) => _navigator.currentState?.maybePop(),
    child: Navigator(
      key: _navigator,
      pages: [
        MaterialPage<void>(
          key: const ValueKey('activity-panel-root'),
          // The cards' ink needs a Material inside the route, which page
          // transitions paint over.
          child: Material(type: MaterialType.transparency, child: widget.child),
        ),
      ],
      onDidRemovePage: (_) {},
    ),
  );
}
