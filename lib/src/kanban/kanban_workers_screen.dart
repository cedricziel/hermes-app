import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/widgets/dialog_presentation.dart';

import '../../l10n/l10n.dart';
import '../macos/mac_commands.dart';
import '../navigation/keyboard_shortcuts.dart';
import '../theme/app_icons.dart';
import '../theme/platform_chrome.dart';
import '../widgets/grouped_list.dart';
import '../widgets/platform_refresh.dart';
import '../widgets/settings_scaffold.dart';
import '../widgets/state_message.dart';
import 'kanban_errors.dart';
import 'kanban_models.dart';
import 'kanban_repository.dart';
import 'widgets/kanban_list_rows.dart';
import 'widgets/kanban_run_inspect_dialog.dart';
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
  bool _failed = false;
  int _loads = 0;
  bool _reloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// A reload the user asked for, from the bar or View > Reload: the button
  /// shows a spinner meanwhile.
  Future<void> _reload() async {
    setState(() => _reloading = true);
    try {
      await _load();
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
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
        _failed = false;
      });
    } on Object catch (e) {
      if (!mounted || load != _loads) return;
      final message = e is KanbanException ? e.message : null;
      if (_workers == null) {
        setState(() {
          _failure = message;
          _failed = true;
        });
      } else {
        // Keep what is on screen, but do not let a failed refresh pass
        // as a successful one.
        final l10n = context.l10n;
        final reason = message ?? l10n.kanbanWorkersLoadFailed;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.kanbanWorkersRefreshFailed(reason))),
        );
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
    await showAppDialog<void>(
      context: context,
      builder: (context) =>
          KanbanRunInspectDialog(runId: worker.runId, inspection: i),
    );
  }

  Future<void> _terminate(KanbanWorker worker) async {
    if (!await confirmKanban(
      context,
      title: context.l10n.kanbanWorkersTerminateTitle(worker.runId),
      confirm: context.l10n.kanbanWorkersTerminate,
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
    final l10n = context.l10n;
    final mac = platformChromeOf(context) == PlatformChrome.macos;
    final scaffold = SettingsScaffold(
      title: l10n.kanbanWorkersTitle,
      subtitle: workers == null
          ? null
          : l10n.kanbanWorkersRunning(workers.length),
      previousTitle: l10n.kanbanWorkersPreviousTitle,
      actions: [
        SettingsBarAction(
          label: l10n.kanbanRefreshAction,
          icon: AppIcons.refresh,
          command: MacCommand.reload,
          shortcut: mac ? '⌘R' : null,
          busy: _reloading,
          onPressed: _reload,
        ),
      ],
      body: workers == null
          ? _failed
                ? StateMessage(
                    title: _failure ?? l10n.kanbanWorkersLoadFailed,
                    action: FilledButton(
                      onPressed: () {
                        setState(() {
                          _failure = null;
                          _failed = false;
                        });
                        _load();
                      },
                      child: Text(l10n.commonRetry),
                    ),
                  )
                : const Center(child: CircularProgressIndicator.adaptive())
          : PlatformRefresh(
              onRefresh: _load,
              child: workers.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        StateMessage(title: l10n.kanbanWorkersEmpty),
                      ],
                    )
                  : GroupedListView(
                      children: [
                        GroupedSection(
                          children: [
                            for (final w in workers)
                              KanbanWorkerRow(
                                worker: w,
                                // The task's own panel can stop this very
                                // run, so the list is read again once it
                                // closes.
                                onOpen: () => showKanbanTask(
                                  context,
                                  repository: widget.repository,
                                  taskId: w.taskId,
                                  board: widget.board,
                                  onChanged: widget.onChanged,
                                ).then((_) => _load()),
                                onInspect: () => _inspect(w),
                                onTerminate: () => _terminate(w),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
    );
    if (!mac && !bindsDesktopChords(Theme.of(context).platform)) {
      return scaffold;
    }
    // View > Reload owns ⌘R, and Ctrl+R and F5 on Windows and Linux.
    return MacCommandScope(
      commands: {
        MacCommand.reload: MacCommandHandler(
          _reloading ? null : () => unawaited(_reload()),
        ),
      },
      child: scaffold,
    );
  }
}
