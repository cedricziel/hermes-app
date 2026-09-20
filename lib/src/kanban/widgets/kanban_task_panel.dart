import 'package:flutter/material.dart';

import '../../chat/widgets/relative_time.dart';
import '../kanban_errors.dart';
import '../kanban_files.dart';
import '../kanban_models.dart';
import '../kanban_repository.dart';
import 'kanban_task_log_dialog.dart';

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
  if (MediaQuery.sizeOf(context).width >= 720) {
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
  KanbanTaskDetail? _detail;
  bool _failed = false;
  bool _transferring = false;
  KanbanEstimate? _estimate;
  bool _estimating = false;
  List<KanbanHomeChannel> _channels = const [];
  final _switching = <String>{};
  final _comment = TextEditingController();

  KanbanRepository get _repo => widget.repository;

  @override
  void initState() {
    super.initState();
    _load();
    _loadChannels();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final detail = await _repo.loadTask(widget.taskId, board: widget.board);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _failed = false;
      });
      _loadChannels();
    } catch (_) {
      if (mounted && _detail == null) setState(() => _failed = true);
    }
  }

  /// The home channels are an extra: a server without any, or one that
  /// refuses, simply shows no Notify section.
  Future<void> _loadChannels() async {
    try {
      final channels = await _repo.loadHomeChannels(
        widget.taskId,
        board: widget.board,
      );
      if (mounted) setState(() => _channels = channels);
    } catch (_) {}
  }

  Future<void> _toggleChannel(KanbanHomeChannel channel, bool on) async {
    if (!_switching.add(channel.platform)) return;
    setState(() {});
    final ok = await runKanbanAction(
      context,
      () => _repo.setHomeSubscription(
        widget.taskId,
        channel.platform,
        subscribed: on,
        board: widget.board,
      ),
    );
    _switching.remove(channel.platform);
    if (ok && mounted) {
      setState(() {
        _channels = [
          for (final c in _channels)
            c.platform == channel.platform ? c.withSubscribed(on) : c,
        ];
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _estimateTask() async {
    setState(() => _estimating = true);
    KanbanEstimate? estimate;
    await runKanbanAction(
      context,
      () async => estimate = await _repo.estimateTask(
        widget.taskId,
        board: widget.board,
      ),
    );
    if (mounted) {
      setState(() {
        _estimating = false;
        if (estimate != null) _estimate = estimate;
      });
    }
  }

  /// Runs a write and reloads; reports the change to the board when it works.
  Future<bool> _do(Future<void> Function() action, {bool reload = true}) async {
    final ok = await runKanbanAction(context, action);
    if (ok) {
      // The task changed, so an estimate of it no longer holds.
      if (mounted) setState(() => _estimate = null);
      widget.onChanged?.call();
      if (reload) await _load();
    }
    return ok;
  }

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
    await _do(
      () => _repo.updateTask(
        widget.taskId,
        status: status,
        blockReason: reason == null || reason.isEmpty ? null : reason,
        result: result == null || result.isEmpty ? null : result,
        board: widget.board,
      ),
    );
  }

  Future<void> _triage(
    Future<KanbanTriageOutcome> Function() run,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    KanbanTriageOutcome? outcome;
    final ok = await runKanbanAction(
      context,
      () async => outcome = await run(),
    );
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
    if (result.ok) {
      widget.onChanged?.call();
      await _load();
    }
  }

  Future<void> _terminate(KanbanRun run) async {
    if (!await confirmKanban(
      context,
      title: 'Terminate this run?',
      confirm: 'Terminate',
    )) {
      return;
    }
    await _do(() => _repo.terminateRun(run.id, board: widget.board));
  }

  Future<void> _attach() async {
    if (_transferring) return;
    setState(() => _transferring = true);
    try {
      KanbanPickedFile? file;
      final picked = await runKanbanAction(
        context,
        () async => file = await widget.files.pick(),
      );
      if (!picked || file == null || !mounted) return;
      final chosen = file!;
      await _do(
        () => _repo.uploadAttachment(
          widget.taskId,
          chosen.name,
          chosen.bytes,
          board: widget.board,
        ),
      );
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Future<void> _download(KanbanAttachment a) async {
    setState(() => _transferring = true);
    final messenger = ScaffoldMessenger.of(context);
    var saved = false;
    final ok = await runKanbanAction(context, () async {
      final bytes = await _repo.downloadAttachment(a.id, board: widget.board);
      saved = await widget.files.save(a.filename, bytes);
    });
    if (mounted) setState(() => _transferring = false);
    if (ok && saved) {
      messenger.showSnackBar(SnackBar(content: Text('Saved ${a.filename}')));
    }
  }

  Future<void> _removeAttachment(KanbanAttachment a) async {
    if (!await confirmKanban(
      context,
      title: 'Remove ${a.filename}?',
      confirm: 'Remove',
    )) {
      return;
    }
    await _do(() => _repo.removeAttachment(a.id, board: widget.board));
  }

  void _showLog() => showDialog<void>(
    context: context,
    builder: (_) => KanbanTaskLogDialog(
      repository: _repo,
      taskId: widget.taskId,
      board: widget.board,
    ),
  );

  Future<void> _reclaim() async {
    if (!await confirmKanban(
      context,
      title: 'Release the worker’s claim on this task?',
      confirm: 'Reclaim',
    )) {
      return;
    }
    await _do(() => _repo.reclaimTask(widget.taskId, board: widget.board));
  }

  Future<void> _edit(KanbanTask task) async {
    final edited = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _EditTaskDialog(task: task),
    );
    if (edited == null || edited.$1.isEmpty) return;
    await _do(
      () => _repo.updateTask(
        widget.taskId,
        title: edited.$1,
        body: edited.$2,
        board: widget.board,
      ),
    );
  }

  Future<void> _assign(KanbanTask task) async {
    List<String> names = const [];
    try {
      names = await _repo.loadAssignees(board: widget.board);
    } catch (_) {}
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
    if (picked == null || picked == (task.assignee ?? '')) return;
    await _do(
      () => _repo.updateTask(
        widget.taskId,
        assignee: picked,
        board: widget.board,
      ),
    );
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
    if (picked == null || picked == task.priority) return;
    await _do(
      () => _repo.updateTask(
        widget.taskId,
        priority: picked,
        board: widget.board,
      ),
    );
  }

  Future<void> _addParent() async {
    final id = await askKanbanText(
      context,
      title: 'Depends on',
      hint: 'Task id, e.g. t_1a2b',
      confirm: 'Add',
    );
    if (id == null || id.isEmpty) return;
    await _do(() => _repo.addLink(id, widget.taskId, board: widget.board));
  }

  Future<void> _sendComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    if (await _do(
      () => _repo.addComment(widget.taskId, text, board: widget.board),
    )) {
      _comment.clear();
    }
  }

  Future<void> _archive() async {
    if (!await confirmKanban(
      context,
      title: 'Archive this task?',
      confirm: 'Archive',
    )) {
      return;
    }
    if (await _do(
          () => _repo.archiveTask(widget.taskId, board: widget.board),
          reload: false,
        ) &&
        mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    if (!await confirmKanban(
      context,
      title: 'Delete this task for good?',
      confirm: 'Delete',
    )) {
      return;
    }
    if (await _do(
          () => _repo.deleteTask(widget.taskId, board: widget.board),
          reload: false,
        ) &&
        mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail == null) {
      return Center(
        child: _failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load the task'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      setState(() => _failed = false);
                      _load();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              )
            : const CircularProgressIndicator(),
      );
    }
    final task = detail.task;
    final theme = Theme.of(context);
    final subtle = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          '${task.id} · ${kanbanStatusLabel(task.status)}',
          style: theme.textTheme.bodySmall?.copyWith(color: subtle),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(task.title, style: theme.textTheme.titleLarge),
            ),
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(task),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.person_outline, size: 16),
              label: Text(task.assignee ?? 'Unassigned'),
              onPressed: () => _assign(task),
            ),
            ActionChip(
              avatar: const Icon(Icons.flag_outlined, size: 16),
              label: Text(task.priority == 0 ? 'Normal' : 'P${task.priority}'),
              onPressed: () => _prioritise(task),
            ),
            if (task.tenant != null) Chip(label: Text(task.tenant!)),
            PopupMenuButton<String>(
              tooltip: 'Move to',
              onSelected: _moveTo,
              itemBuilder: (_) => [
                for (final s in kanbanSettableStatuses)
                  if (s != task.status)
                    PopupMenuItem(value: s, child: Text(kanbanStatusLabel(s))),
              ],
              child: const Chip(
                avatar: Icon(Icons.swap_horiz, size: 16),
                label: Text('Move to…'),
              ),
            ),
          ],
        ),
        if (task.status == 'triage')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _triage(
                    () =>
                        _repo.decomposeTask(widget.taskId, board: widget.board),
                    'Decomposed',
                  ),
                  child: const Text('Decompose'),
                ),
                OutlinedButton(
                  onPressed: () => _triage(
                    () => _repo.specifyTask(widget.taskId, board: widget.board),
                    'Specified',
                  ),
                  child: const Text('Specify'),
                ),
              ],
            ),
          ),
        if (task.status == 'running')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              children: [
                OutlinedButton(
                  onPressed: _reclaim,
                  child: const Text('Reclaim'),
                ),
              ],
            ),
          ),
        if (task.status != 'done')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () => _moveTo('done'),
                  child: const Text('Complete'),
                ),
                if (task.status != 'blocked')
                  OutlinedButton(
                    onPressed: () => _moveTo('blocked'),
                    child: const Text('Block'),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _estimating ? null : _estimateTask,
                icon: const Icon(Icons.speed_outlined, size: 18),
                label: const Text('Estimate'),
              ),
              if (_estimating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_estimate != null)
                Text(_estimate!.summary),
            ],
          ),
        ),
        if (_estimate?.rationale != null && _estimate!.ok)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _estimate!.rationale!,
              style: theme.textTheme.bodySmall?.copyWith(color: subtle),
            ),
          ),
        if (detail.diagnostics.isNotEmpty) ...[
          const _Heading('Needs attention'),
          for (final d in detail.diagnostics)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              color: d.severity == 'warning'
                  ? Colors.amber.withValues(alpha: 0.15)
                  : theme.colorScheme.error.withValues(alpha: 0.12),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text(d.title),
                subtitle: d.detail.isEmpty ? null : Text(d.detail),
              ),
            ),
        ],
        if (task.body != null) ...[
          const _Heading('Description'),
          SelectableText(task.body!),
        ],
        if (task.latestSummary != null || task.result != null) ...[
          const _Heading('Result'),
          SelectableText(task.latestSummary ?? task.result!),
        ],
        const _Heading('Depends on'),
        Wrap(
          spacing: 6,
          children: [
            for (final id in detail.parents)
              InputChip(
                label: Text(id),
                onDeleted: () => _do(
                  () => _repo.removeLink(id, task.id, board: widget.board),
                ),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
              onPressed: _addParent,
            ),
          ],
        ),
        if (detail.childResults.isNotEmpty) ...[
          const _Heading('Subtasks'),
          for (final c in detail.childResults)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(c.title),
              subtitle: Text(
                '${c.id} · ${kanbanStatusLabel(c.status)}'
                '${c.summary == null ? '' : '\n${c.summary}'}',
              ),
            ),
        ],
        _Heading('Comments (${detail.comments.length})'),
        for (final c in detail.comments)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.author}${c.createdAt == null ? '' : ' · ${relativeTime(c.createdAt!)}'}',
                  style: theme.textTheme.bodySmall?.copyWith(color: subtle),
                ),
                SelectableText(c.body),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _comment,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Add a comment…',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _sendComment(),
              ),
            ),
            IconButton(
              tooltip: 'Send',
              icon: const Icon(Icons.send),
              onPressed: _sendComment,
            ),
          ],
        ),
        if (_channels.isNotEmpty) ...[
          const _Heading('Notify'),
          for (final c in _channels)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('Post updates to ${c.name}'),
              subtitle: Text(c.platform),
              value: c.subscribed,
              onChanged: _switching.contains(c.platform)
                  ? null
                  : (on) => _toggleChannel(c, on),
            ),
        ],
        const _Heading('Attachments'),
        if (_transferring) const LinearProgressIndicator(),
        for (final a in detail.attachments)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(a.filename),
            subtitle: Text(_size(a.size)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Save attachment',
                  icon: const Icon(Icons.download_outlined),
                  onPressed: _transferring ? null : () => _download(a),
                ),
                IconButton(
                  tooltip: 'Remove attachment',
                  icon: const Icon(Icons.close),
                  onPressed: _transferring ? null : () => _removeAttachment(a),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _transferring ? null : _attach,
            icon: const Icon(Icons.attach_file),
            label: const Text('Attach file'),
          ),
        ),
        if (detail.runs.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Runs (${detail.runs.length})'),
            children: [
              for (final r in detail.runs.reversed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '#${r.id} · ${r.profile ?? 'worker'} · '
                    '${r.active ? 'running' : (r.outcome ?? r.status)}',
                  ),
                  subtitle: r.error != null || r.summary != null
                      ? Text(r.error ?? r.summary!)
                      : null,
                  trailing: r.active && task.status == 'running'
                      ? TextButton(
                          onPressed: () => _terminate(r),
                          child: const Text('Terminate'),
                        )
                      : null,
                ),
              TextButton.icon(
                onPressed: _showLog,
                icon: const Icon(Icons.terminal),
                label: const Text('Worker log'),
              ),
            ],
          ),
        if (detail.events.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('History'),
            children: [
              for (final e in detail.events.reversed)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.kind.replaceAll('_', ' ')),
                  trailing: e.createdAt == null
                      ? null
                      : Text(relativeTime(e.createdAt!)),
                ),
            ],
          ),
        const Divider(),
        Row(
          children: [
            TextButton.icon(
              onPressed: _archive,
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archive'),
            ),
            TextButton.icon(
              onPressed: _delete,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              label: Text(
                'Delete',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _size(int bytes) => bytes < 1024
    ? '$bytes B'
    : bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 6),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 0.8,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    ),
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
