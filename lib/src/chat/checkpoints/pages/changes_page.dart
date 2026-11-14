import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/l10n.dart';
import '../../../widgets/grouped_list.dart';
import '../../activity/activity_page_binding.dart';
import '../../activity/widgets/activity_page_scaffold.dart';
import '../../activity/widgets/activity_working_line.dart';
import '../../chat_controller.dart';
import '../../chat_models.dart';
import '../../widgets/relative_time.dart';
import '../checkpoint_models.dart';
import '../checkpoints_controller.dart';
import '../widgets/changed_files_list.dart';
import '../widgets/changes_page_message.dart';
import '../widgets/checkpoint_row.dart';
import '../widgets/file_diff_view.dart';
import '../widgets/restore_all_bar.dart';
import '../widgets/restore_outcome_note.dart';
import 'checkpoints_page.dart';
import 'file_change_page.dart';
import 'restore_flow.dart';

/// From this width the file list and the open file's diff sit side by side.
const double kChangesSideBySideWidth = 900;

/// The width of the file list beside the diff.
const double kChangesListWidth = 320;

/// "Changes", pushed inside the Activity panel: the files that differ from
/// checkpoint [hash], read when the page opens and dropped when it closes,
/// with the sticky "Restore all files…" bar. A file opens its own page, or,
/// from [kChangesSideBySideWidth], shows beside the list.
///
/// After Restore all files the panel goes back to the re-read checkpoint
/// list; after one file this page comes back, re-read, with the outcome note
/// on top.
class ChangesPage extends StatefulWidget {
  const ChangesPage({
    super.key,
    required this.chat,
    required this.thread,
    required this.hash,
  });

  final ChatController chat;
  final ChatThread thread;
  final String hash;

  static Route<void> route({
    required ChatController chat,
    required ChatThread thread,
    required String hash,
  }) => MaterialPageRoute<void>(
    builder: (_) => ChangesPage(chat: chat, thread: thread, hash: hash),
  );

  @override
  State<ChangesPage> createState() => _ChangesPageState();
}

class _ChangesPageState extends State<ChangesPage>
    with ActivityPageBinding<ChangesPage, CheckpointsController> {
  /// The file shown beside the list in a wide panel.
  String? _selected;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = this.controller;
      if (mounted && controller != null && !controller.locked) {
        unawaited(controller.openChanges(widget.hash));
      }
    });
  }

  @override
  void dispose() {
    // Leaving the page drops the diff text, unless another page has opened
    // another checkpoint's changes meanwhile.
    unbindController();
    final controller = this.controller;
    if (controller != null && controller.openHash == widget.hash) {
      // Closing notifies the panel, which may be building.
      scheduleMicrotask(() {
        if (controller.openHash == widget.hash) controller.closeChanges();
      });
    }
    super.dispose();
  }

  Checkpoint? _checkpoint(CheckpointsController controller) {
    for (final checkpoint in controller.checkpoints) {
      if (checkpoint.hash == widget.hash) return checkpoint;
    }
    return null;
  }

  String? _subtitle(AppLocalizations l10n, CheckpointsController controller) {
    final checkpoint = _checkpoint(controller);
    if (checkpoint == null) return null;
    final reason = checkpointReasonTitle(l10n, checkpoint.reason);
    final at = checkpoint.timestamp;
    final time = at == null
        ? null
        : relativeTimeLabel(l10n, at, bareDate: true);
    return time == null
        ? reason
        : l10n.chatCheckpointsPageChangesSubtitle(time, reason);
  }

  Changes? _files(CheckpointsController controller) {
    final changes = controller.changes;
    return controller.openHash == widget.hash && changes is Changes
        ? changes
        : null;
  }

  void _retry() {
    final controller = this.controller;
    if (controller != null) unawaited(controller.openChanges(widget.hash));
  }

  void _restoreAll() {
    final controller = this.controller;
    if (controller == null) return;
    unawaited(
      confirmRestoreFlow(
        context,
        controller: controller,
        changes: widget.chat,
        hash: widget.hash,
      ).then((sent) {
        if (!sent || !mounted) return;
        // The re-read list, with the outcome note on top, comes back.
        Navigator.of(context).popUntil(
          (route) =>
              route.settings.name == CheckpointsPage.routeName || route.isFirst,
        );
      }),
    );
  }

  void _restoreFile(ChangedFile file) {
    final controller = this.controller;
    if (controller == null) return;
    unawaited(
      confirmRestoreFlow(
        context,
        controller: controller,
        changes: widget.chat,
        hash: widget.hash,
        filePath: file.path,
      ),
    );
  }

  void _open(ChangedFile file, {required bool wide}) {
    if (wide) {
      setState(() => _selected = file.path);
      return;
    }
    unawaited(
      Navigator.of(context).push(
        FileChangePage.route(
          chat: widget.chat,
          thread: currentThread ?? widget.thread,
          hash: widget.hash,
          path: file.path,
        ),
      ),
    );
  }

  Widget _message(CheckpointsController controller) {
    final changes = controller.changes;
    if (controller.openHash != widget.hash ||
        changes == null ||
        controller.loadingChanges) {
      // Read again after a restore of one file: loading until it is back.
      final reading =
          controller.loadingChanges ||
          controller.restoring ||
          controller.loadingList;
      return reading
          ? const ChangesPageMessage(status: ChangesPageStatus.loading)
          : ChangesPageMessage(
              status: ChangesPageStatus.unreadable,
              onRetry: controller.notUpToDate ? null : _retry,
            );
    }
    final checkpoint = _checkpoint(controller);
    return switch (changes) {
      ChangesRefused() => const ChangesPageMessage(
        status: ChangesPageStatus.refused,
      ),
      ChangesUnreadable() || ChangesFailed() => ChangesPageMessage(
        status: ChangesPageStatus.unreadable,
        onRetry: controller.notUpToDate ? null : _retry,
      ),
      Changes() => ChangesPageMessage(
        status: ChangesPageStatus.none,
        sinceLabel: checkpoint == null
            ? null
            : checkpointTimeLabel(context.l10n, checkpoint),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = this.controller;
    if (controller == null) return const SizedBox.shrink();
    final changes = _files(controller);
    final files = changes?.files ?? const <ChangedFile>[];
    final outcome = controller.outcome;
    final showOutcome =
        outcome != null &&
        lastRestoreWasFile(controller) == true &&
        lastRestoreHash(controller) == widget.hash;
    final top = [
      if (controller.restoring)
        ActivityWorkingLine(label: l10n.chatCheckpointsPageRestoring),
      if (showOutcome)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: RestoreOutcomeNote(
            key: const Key('changes-outcome'),
            outcome: outcome,
            filesWereFile: true,
            onTryAgain: () => unawaited(
              restoreAgainFlow(
                context,
                controller: controller,
                changes: widget.chat,
              ),
            ),
          ),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= kChangesSideBySideWidth && files.isNotEmpty;
        final selected = wide
            ? files.where((file) => file.path == _selected).firstOrNull ??
                  files.first
            : null;
        final list = files.isEmpty
            ? _message(controller)
            : GroupedListView(
                children: [
                  ChangedFilesList(
                    files: files,
                    truncated: changes?.truncated ?? false,
                    selectedPath: selected?.path,
                    onOpen: (file) => _open(file, wide: wide),
                  ),
                ],
              );
        Widget body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...top,
            Expanded(child: list),
          ],
        );
        if (selected != null) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: kChangesListWidth, child: body),
              const VerticalDivider(width: 1),
              Expanded(
                child: SingleChildScrollView(
                  child: FileDiffView(
                    key: ValueKey(selected.path),
                    file: selected,
                    truncated: changes?.truncated ?? false,
                    restoreRefusal: controller.restoreRefusal(
                      filePath: selected.path,
                    ),
                    restoring: controller.restoring,
                    onRestore: () => _restoreFile(selected),
                  ),
                ),
              ),
            ],
          );
        }
        return ActivityPageScaffold(
          title: l10n.chatCheckpointsPageChangesTitle,
          subtitle: _subtitle(l10n, controller),
          onBack: () => Navigator.of(context).maybePop(),
          body: body,
          framedBottom: false,
          bottom: files.isEmpty
              ? null
              : RestoreAllBar(
                  fileCount: files.length,
                  refusal: controller.restoreRefusal(),
                  onRestoreAll: _restoreAll,
                ),
        );
      },
    );
  }
}
