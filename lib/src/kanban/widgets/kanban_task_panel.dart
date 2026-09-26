import 'dart:async';

import 'package:hermes_app/src/theme/breakpoints.dart';

import 'package:flutter/material.dart';

import '../../models/model_provider_option.dart';
import '../../models/widgets/model_picker.dart';
import '../kanban_errors.dart';
import '../kanban_files.dart';
import '../kanban_models.dart';
import '../kanban_repository.dart';
import '../kanban_task_controller.dart';
import 'kanban_task_log_dialog.dart';
import 'task_panel/kanban_task_actions.dart';
import 'task_panel/kanban_task_attachments.dart';
import 'task_panel/kanban_task_channels.dart';
import 'task_panel/kanban_task_comments.dart';
import 'task_panel/kanban_task_fields.dart';
import 'task_panel/kanban_task_header.dart';
import 'task_panel/kanban_task_runs.dart';

/// Opens a task as a bottom sheet on a phone and a dialog on a wide screen.
Future<void> showKanbanTask(
  BuildContext context, {
  required KanbanRepository repository,
  required String taskId,
  KanbanFiles files = const PlatformKanbanFiles(),
  String? board,
  VoidCallback? onChanged,
}) {
  final panel = KanbanTaskPanel(
    repository: repository,
    files: files,
    taskId: taskId,
    board: board,
    onChanged: onChanged,
  );
  if (MediaQuery.sizeOf(context).width >= kKanbanColumnsBreakpoint) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: Padding(padding: const EdgeInsets.only(top: 16), child: panel),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: panel),
  );
}

/// A task's detail: status actions, description, dependencies, comments and
/// history.
class KanbanTaskPanel extends StatefulWidget {
  const KanbanTaskPanel({
    super.key,
    required this.repository,
    required this.taskId,
    this.files = const PlatformKanbanFiles(),
    this.board,
    this.onChanged,
  });

  final KanbanRepository repository;

  /// The file dialogs used to attach and save attachments.
  final KanbanFiles files;
  final String taskId;
  final String? board;

  /// Called after every change that went through, so the board can refresh.
  final VoidCallback? onChanged;

  @override
  State<KanbanTaskPanel> createState() => _KanbanTaskPanelState();
}

class _KanbanTaskPanelState extends State<KanbanTaskPanel> {
  late final KanbanTaskController _task = KanbanTaskController(
    repository: widget.repository,
    files: widget.files,
    taskId: widget.taskId,
    board: widget.board,
    onChanged: widget.onChanged,
  );

  @override
  void initState() {
    super.initState();
    unawaited(_task.start());
  }

  @override
  void dispose() {
    _task.dispose();
    super.dispose();
  }

  Future<bool> _run(Future<void> Function() action) =>
      runKanbanAction(context, action);

  Future<void> _moveTo(String status) async {
    String? reason;
    String? result;
    if (status == 'blocked') {
      reason = await askKanbanText(
        context,
        title: 'Why is it blocked?',
        hint: 'Optional',
        confirm: 'Block',
      );
      if (reason == null) return;
    } else if (status == 'done') {
      result = await askKanbanText(
        context,
        title: 'Result',
        hint: 'Optional — what came out of it',
        confirm: 'Complete',
        multiline: true,
      );
      if (result == null) return;
    }
    if (!mounted) return;
    await _run(() => _task.moveTo(status, reason: reason, result: result));
  }

  Future<void> _triage(
    Future<KanbanTriageOutcome> Function() run,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    KanbanTriageOutcome? outcome;
    final ok = await _run(() async => outcome = await run());
    if (!ok) return;
    final result = outcome!;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.ok
              ? (result.childIds.isEmpty
                    ? done
                    : '$done into ${result.childIds.length} tasks')
              : result.reason ?? 'That did not work out.',
        ),
      ),
    );
  }

  Future<void> _confirmThen(
    String title,
    String confirm,
    Future<void> Function() action, {
    bool close = false,
  }) async {
    if (!await confirmKanban(context, title: title, confirm: confirm) ||
        !mounted) {
      return;
    }
    if (await _run(action) && close && mounted) Navigator.pop(context);
  }

  Future<void> _download(KanbanAttachment a) async {
    final messenger = ScaffoldMessenger.of(context);
    var saved = false;
    final ok = await _run(() async => saved = await _task.download(a));
    if (ok && saved) {
      messenger.showSnackBar(SnackBar(content: Text('Saved ${a.filename}')));
    }
  }

  void _showLog() => showDialog<void>(
    context: context,
    builder: (_) => KanbanTaskLogDialog(
      repository: widget.repository,
      taskId: widget.taskId,
      board: widget.board,
    ),
  );

  Future<void> _edit(KanbanTask task) async {
    final edited = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _EditTaskDialog(task: task),
    );
    if (edited == null || edited.$1.isEmpty || !mounted) return;
    await _run(() => _task.update(title: edited.$1, body: edited.$2));
  }

  Future<void> _assign(KanbanTask task) async {
    final names = await _task.loadAssignees();
    if (!mounted) return;
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Assign to'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Nobody'),
          ),
          for (final n in names)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, n),
              child: Text(n),
            ),
        ],
      ),
    );
    if (picked == null || picked == (task.assignee ?? '') || !mounted) return;
    await _run(() => _task.update(assignee: picked));
  }

  Future<void> _prioritise(KanbanTask task) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Priority'),
        children: [
          for (final p in [0, 1, 2, 3])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p),
              child: Text(p == 0 ? 'Normal' : 'P$p'),
            ),
        ],
      ),
    );
    if (picked == null || picked == task.priority || !mounted) return;
    await _run(() => _task.update(priority: picked));
  }

  /// Opens the model picker and applies the last pick once it closes, so
  /// choosing a model and then an effort is one change.
  Future<void> _editModel(KanbanTask task) async {
    final options = await _task.modelOptions();
    if (!mounted) return;
    if (options.providers.isEmpty) {
      final name = await askKanbanText(
        context,
        title: 'Model',
        hint: 'Empty for the profile default',
        initial: task.modelOverride,
        confirm: 'Save',
      );
      if (name != null && mounted) await _run(() => _task.setModelName(name));
      return;
    }
    final model = task.modelOverride;
    var picked = model == null
        ? null
        : ModelChoice(
            task.providerOverride ?? '',
            model,
            effort: task.reasoningEffort,
          );
    var touched = false;
    await showModelPicker(
      context,
      options: options,
      selected: picked,
      onChanged: (choice) {
        picked = choice;
        touched = true;
      },
      onUseDefault: () {
        picked = null;
        touched = true;
      },
    );
    if (touched && mounted) await _run(() => _task.setModel(picked));
  }

  Future<void> _addParent() async {
    final id = await askKanbanText(
      context,
      title: 'Depends on',
      hint: 'Task id, e.g. t_1a2b',
      confirm: 'Add',
    );
    if (id == null || id.isEmpty || !mounted) return;
    await _run(() => _task.addParent(id));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _task,
    builder: (context, _) {
      final detail = _task.detail;
      if (detail == null) {
        return Center(
          child: _task.failed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load the task'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _task.retry,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        );
      }
      final task = detail.task;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          KanbanTaskHeader(
            task: task,
            onEdit: () => _edit(task),
            onAssign: () => _assign(task),
            onPrioritise: () => _prioritise(task),
            onMove: _moveTo,
          ),
          KanbanTaskActions(
            task: task,
            estimate: _task.estimate,
            estimating: _task.estimating,
            onDecompose: () => _triage(_task.decompose, 'Decomposed'),
            onSpecify: () => _triage(_task.specify, 'Specified'),
            onReclaim: () => _confirmThen(
              'Release the worker’s claim on this task?',
              'Reclaim',
              _task.reclaim,
            ),
            onComplete: () => _moveTo('done'),
            onBlock: () => _moveTo('blocked'),
            onEstimate: () => _run(_task.estimateTask),
          ),
          KanbanTaskFields(
            detail: detail,
            onAddParent: _addParent,
            onRemoveParent: (id) => _run(() => _task.removeParent(id)),
            onEditModel: () => _editModel(task),
          ),
          KanbanTaskComments(
            comments: detail.comments,
            onSend: (text) => _run(() => _task.addComment(text)),
          ),
          KanbanTaskChannels(
            channels: _task.channels,
            switching: _task.switching,
            onToggle: (channel, on) =>
                _run(() => _task.setChannel(channel, on)),
          ),
          KanbanTaskAttachments(
            attachments: detail.attachments,
            transferring: _task.transferring,
            onAttach: () => _run(_task.attach),
            onDownload: _download,
            onRemove: (a) => _confirmThen(
              'Remove ${a.filename}?',
              'Remove',
              () => _task.removeAttachment(a),
            ),
          ),
          KanbanTaskRuns(
            runs: detail.runs,
            events: detail.events,
            taskRunning: task.status == 'running',
            onTerminate: (run) => _confirmThen(
              'Terminate this run?',
              'Terminate',
              () => _task.terminateRun(run),
            ),
            onShowLog: _showLog,
          ),
          const Divider(),
          KanbanTaskFooter(
            onArchive: () => _confirmThen(
              'Archive this task?',
              'Archive',
              _task.archive,
              close: true,
            ),
            onDelete: () => _confirmThen(
              'Delete this task for good?',
              'Delete',
              _task.delete,
              close: true,
            ),
          ),
        ],
      );
    },
  );
}

class _EditTaskDialog extends StatefulWidget {
  const _EditTaskDialog({required this.task});

  final KanbanTask task;

  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  late final _title = TextEditingController(text: widget.task.title);
  late final _body = TextEditingController(text: widget.task.body ?? '');

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit task'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _title,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _body,
          minLines: 3,
          maxLines: 8,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () =>
            Navigator.pop(context, (_title.text.trim(), _body.text.trim())),
        child: const Text('Save'),
      ),
    ],
  );
}
