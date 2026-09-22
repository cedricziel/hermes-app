import 'dart:async';

import 'package:hermes_app/src/widgets/state_message.dart';

import 'package:hermes_app/src/theme/breakpoints.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/hermes_repositories.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_controller.dart';
import '../chat/gateway/gateway_connection.dart';
import '../theme/hermes_theme.dart';
import 'kanban_board_controller.dart';
import 'kanban_boards_screen.dart';
import 'kanban_create_screen.dart';
import 'kanban_errors.dart';
import 'kanban_files.dart';
import 'kanban_models.dart';
import 'kanban_repository.dart';
import 'kanban_workers_screen.dart';
import 'widgets/kanban_board_menu.dart';
import 'widgets/kanban_board_toolbar.dart';
import 'widgets/kanban_bulk_bar.dart';
import 'widgets/kanban_card.dart';
import 'widgets/kanban_card_drag.dart';
import 'widgets/kanban_drop_strip.dart';
import 'widgets/kanban_status_chips.dart';
import 'widgets/kanban_orchestration_dialog.dart';
import 'widgets/kanban_task_panel.dart';

/// The Kanban board: status chips over a card list on a phone, real columns
/// on a wide screen. Kept current by the plugin's event stream.
class KanbanScreen extends StatefulWidget {
  const KanbanScreen({
    super.key,
    this.repository,
    this.connect,
    this.files = const PlatformKanbanFiles(),
  });

  /// The file dialogs used to attach and save attachments.
  final KanbanFiles files;

  /// Override the repository / event stream built from the signed-in client.
  final KanbanRepository? repository;
  final KanbanEventsConnect? connect;

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  late final KanbanBoardController _controller;
  late final KanbanRepository _repository;

  /// The card a phone is dragging by its handle, while it is.
  String? _dragId;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    final repositories = widget.repository == null || widget.connect == null
        ? HermesRepositories.of(context)
        : null;
    _repository = widget.repository ?? repositories!.kanban;
    KanbanEventsConnect connect;
    if (widget.connect != null) {
      connect = widget.connect!;
    } else {
      final socket = hermesSocketConnect(
        baseUrl: auth.baseUrl!,
        authRequired: auth.status?.authRequired ?? true,
        api: repositories!.api,
        path: '/api/plugins/kanban/events',
      );
      connect = ({required since, board}) =>
          socket({'since': '$since', 'board': ?board});
    }
    _controller = KanbanBoardController(
      repository: _repository,
      connect: connect,
      prefs: SharedPreferencesAsync(),
      prefsKey: 'hermes.kanban.board.${auth.baseUrl}',
    )..start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => Scaffold(
        appBar: _controller.selecting
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close),
                  onPressed: _controller.stopSelecting,
                ),
                title: Text('${_controller.selected.length} selected'),
              )
            : AppBar(
                title: const Text('Kanban'),
                actions: [
                  if (_controller.boards.isNotEmpty)
                    KanbanBoardMenu(
                      boards: _controller.boards,
                      selected: _controller.boardSlug,
                      onSelected: _controller.selectBoard,
                      onManage: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => KanbanBoardsScreen(
                            controller: _controller,
                            repository: _repository,
                          ),
                        ),
                      ),
                    ),
                  KanbanLiveDot(live: _controller.live),
                  if (_controller.board != null) _moreMenu(),
                  const SizedBox(width: 4),
                ],
              ),
        bottomNavigationBar: _controller.selecting
            ? KanbanBulkBar(
                selectedCount: _controller.selected.length,
                assignees: _controller.board?.assignees ?? const [],
                onMove: (status) => unawaited(_bulk(status: status)),
                onAssign: (assignee) => unawaited(_bulk(assignee: assignee)),
                onPriority: (priority) => unawaited(_bulk(priority: priority)),
                onArchive: () => unawaited(_bulk(archive: true)),
              )
            : null,
        body: _body(context),
        floatingActionButton: _controller.board == null || _controller.selecting
            ? null
            : FloatingActionButton.extended(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New task'),
              ),
      ),
    );
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => KanbanCreateScreen(
          repository: _repository,
          board: _controller.boardSlug,
          tenant: _controller.tenant,
        ),
      ),
    );
    if (created == true) unawaited(_controller.refresh());
  }

  void _open(KanbanTask task) => showKanbanTask(
    context,
    repository: _repository,
    files: widget.files,
    taskId: task.id,
    board: _controller.boardSlug,
    onChanged: _controller.refresh,
  );

  Future<void> _move(KanbanTask task, String status) async {
    setState(() => _dragId = null);
    if (task.status == status) return;
    await runKanbanAction(context, () => _controller.moveTask(task, status));
    unawaited(_controller.refresh());
  }

  Widget _moreMenu() => PopupMenuButton<String>(
    onSelected: (value) {
      switch (value) {
        case 'select':
          _controller.startSelecting();
        case 'dispatch':
          _dispatch();
        case 'workers':
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => KanbanWorkersScreen(
                repository: _repository,
                board: _controller.boardSlug,
                onChanged: _controller.refresh,
              ),
            ),
          );
        case 'orchestration':
          showDialog<void>(
            context: context,
            builder: (_) => KanbanOrchestrationDialog(
              repository: _repository,
              board: _controller.boardSlug,
            ),
          );
      }
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'select', child: Text('Select tasks')),
      PopupMenuItem(value: 'dispatch', child: Text('Run dispatcher now')),
      PopupMenuItem(value: 'workers', child: Text('Active workers…')),
      PopupMenuItem(value: 'orchestration', child: Text('Orchestration…')),
    ],
  );

  Future<void> _dispatch() async {
    final ok = await runKanbanAction(context, _controller.dispatch);
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Dispatcher nudged')));
    unawaited(_controller.refresh());
  }

  /// Applies one change to every selected task, reporting the ones it could
  /// not apply to.
  Future<void> _bulk({
    String? status,
    String? assignee,
    int? priority,
    bool archive = false,
  }) async {
    final count = _controller.selected.length;
    if (count == 0) return;
    var failures = const <KanbanBulkFailure>[];
    final ok = await runKanbanAction(context, () async {
      failures = await _controller.bulkUpdate(
        status: status,
        assignee: assignee,
        priority: priority,
        archive: archive,
      );
    });
    if (!ok || !mounted || failures.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${failures.length} of $count could not be changed: '
          '${failures.first.error}',
        ),
      ),
    );
  }

  Widget _card(KanbanTask task, {bool longPressSelects = false}) {
    final selecting = _controller.selecting;
    return KanbanCard(
      task: task,
      selected: _controller.isSelected(task.id),
      onTap: selecting
          ? () => _controller.toggleSelected(task.id)
          : () => _open(task),
      onLongPress: longPressSelects && !selecting
          ? () => _controller.startSelecting(task.id)
          : null,
      handle: longPressSelects && !selecting
          ? KanbanDragHandle(
              task: task,
              onDragStarted: () => setState(() => _dragId = task.id),
              onDragEnd: () => setState(() => _dragId = null),
            )
          : null,
    );
  }

  /// A card in a list or a column. Its key follows the task, so a card that
  /// a refetch moved here is a new widget and can arrive with an animation.
  Widget _item(KanbanTask task, {required bool narrow}) => KanbanArrival(
    key: ValueKey(task.id),
    animate: _controller.arrived(task.id),
    child: narrow
        ? _card(task, longPressSelects: true)
        : KanbanDraggableCard(task: task, child: _card(task)),
  );

  Widget _body(BuildContext context) {
    final board = _controller.board;
    if (board == null) {
      if (_controller.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return StateMessage(
        icon: _controller.unavailable
            ? Icons.extension_off_outlined
            : Icons.error_outline,
        title: _controller.unavailable
            ? 'Kanban isn’t available'
            : 'Could not load the board',
        detail: _controller.unavailable
            ? 'The plugin was turned off on this server.'
            : null,
        action: _controller.unavailable
            ? null
            : FilledButton(
                onPressed: _controller.refresh,
                child: const Text('Retry'),
              ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kKanbanColumnsBreakpoint;
        return Column(
          children: [
            if (_controller.refreshFailed)
              KanbanRefreshFailedNotice(onRetry: _controller.refresh),
            KanbanBoardToolbar(
              assignees: board.assignees,
              tenants: board.tenants,
              assignee: _controller.assignee,
              tenant: _controller.tenant,
              includeArchived: _controller.includeArchived,
              wide: wide,
              onQueryChanged: _controller.setQuery,
              onAssigneeChanged: _controller.setAssignee,
              onTenantChanged: _controller.setTenant,
              onIncludeArchivedChanged: _controller.setIncludeArchived,
              onRefresh: _controller.refresh,
            ),
            Expanded(child: wide ? _columns(context) : _list(context)),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context) {
    final columns = _controller.columns;
    final shown = _controller.shownStatus;
    final tasks =
        columns.where((c) => c.name == shown).firstOrNull?.tasks ?? const [];
    return Column(
      children: [
        KanbanStatusChips(
          columns: columns,
          selected: shown,
          onSelected: _controller.showStatus,
        ),
        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: _controller.refresh,
                child: tasks.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text('No tasks here')),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: tasks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _item(tasks[i], narrow: true),
                      ),
              ),
              if (tasks.any((t) => t.id == _dragId))
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: KanbanDropStrip(onDrop: _move),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _columns(BuildContext context) {
    final columns = _controller.columns;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      itemCount: columns.length,
      separatorBuilder: (_, _) => const SizedBox(width: 12),
      itemBuilder: (context, i) {
        final column = columns[i];
        final droppable = kanbanSettableStatuses.contains(column.name);
        return SizedBox(
          width: 260,
          child: DragTarget<KanbanTask>(
            onWillAcceptWithDetails: (d) =>
                droppable && d.data.status != column.name,
            onAcceptWithDetails: (d) => _move(d.data, column.name),
            builder: (context, candidates, _) => DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(kHermesRadius),
                color: candidates.isEmpty
                    ? null
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4),
                    child: Text(
                      '${kanbanStatusLabel(column.name)}  ${column.tasks.length}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: column.tasks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, j) =>
                          _item(column.tasks[j], narrow: false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
