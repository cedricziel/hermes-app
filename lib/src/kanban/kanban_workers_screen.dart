import 'package:flutter/material.dart';

import '../chat/widgets/relative_time.dart';
import 'kanban_errors.dart';
import 'kanban_models.dart';
import 'kanban_repository.dart';
import 'widgets/kanban_task_panel.dart';

/// The workers the dispatcher has running tasks right now, with a look at
/// each one's process and a way to stop it.
class KanbanWorkersScreen extends StatefulWidget {
  const KanbanWorkersScreen({
    super.key,
    required this.repository,
    this.board,
    this.onChanged,
  });

  final KanbanRepository repository;
  final String? board;

  /// Called after a run was stopped, so the board can refresh.
  final VoidCallback? onChanged;

  @override
  State<KanbanWorkersScreen> createState() => _KanbanWorkersScreenState();
}

class _KanbanWorkersScreenState extends State<KanbanWorkersScreen> {
  List<KanbanWorker>? _workers;
  String? _failure;
  int _loads = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Overlapping loads (refresh, retry, the reload after Terminate) can
    // finish out of order; only the newest may apply.
    final load = ++_loads;
    try {
      final workers = await widget.repository.loadActiveWorkers(
        board: widget.board,
      );
      if (!mounted || load != _loads) return;
      setState(() {
        _workers = workers;
        _failure = null;
      });
    } catch (e) {
      if (!mounted || load != _loads) return;
      final reason = e is KanbanException
          ? e.message
          : 'Could not load the workers';
      if (_workers == null) {
        setState(() => _failure = reason);
      } else {
        // Keep what is on screen, but do not let a failed refresh pass
        // as a successful one.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not refresh: $reason')));
      }
    }
  }

  Future<void> _inspect(KanbanWorker worker) async {
    KanbanRunInspection? inspection;
    final ok = await runKanbanAction(
      context,
      () async => inspection = await widget.repository.inspectRun(
        worker.runId,
        board: widget.board,
      ),
    );
    if (!ok || inspection == null || !mounted) return;
    final i = inspection!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Run #${worker.runId}'),
        content: Text(
          i.alive
              ? [
                  if (i.pid != null) 'Process ${i.pid}',
                  if (i.status != null) 'Status: ${i.status}',
                  if (i.memoryBytes != null)
                    'Memory: ${(i.memoryBytes! / (1024 * 1024)).toStringAsFixed(0)} MB',
                  if (i.threads != null) 'Threads: ${i.threads}',
                  if (i.note != null) i.note!,
                ].join('\n')
              : 'The process is not running${i.note == null ? '' : ': ${i.note}'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _terminate(KanbanWorker worker) async {
    if (!await confirmKanban(
      context,
      title: 'Terminate run #${worker.runId}?',
      confirm: 'Terminate',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await runKanbanAction(
      context,
      () => widget.repository.terminateRun(worker.runId, board: widget.board),
    );
    if (ok) {
      widget.onChanged?.call();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final workers = _workers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active workers'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: workers == null
          ? Center(
              child: _failure != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_failure!),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () {
                            setState(() => _failure = null);
                            _load();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: workers.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No workers are running')),
                      ],
                    )
                  : ListView.separated(
                      itemCount: workers.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final w = workers[i];
                        return ListTile(
                          title: Text(w.taskTitle),
                          subtitle: Text(
                            [
                              '${w.taskId} · run #${w.runId}',
                              if (w.profile != null) w.profile!,
                              if (w.startedAt != null)
                                'started ${relativeTime(w.startedAt!)}',
                              if (w.lastHeartbeatAt != null)
                                'heartbeat ${relativeTime(w.lastHeartbeatAt!)}',
                            ].join(' · '),
                          ),
                          // The task's own panel can stop this very run, so the
                          // list is read again once it closes.
                          onTap: () => showKanbanTask(
                            context,
                            repository: widget.repository,
                            taskId: w.taskId,
                            board: widget.board,
                            onChanged: widget.onChanged,
                          ).then((_) => _load()),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) => action == 'inspect'
                                ? _inspect(w)
                                : _terminate(w),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'inspect',
                                child: Text('Inspect process'),
                              ),
                              PopupMenuItem(
                                value: 'terminate',
                                child: Text('Terminate'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
