import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
import 'widgets/kanban_card.dart';
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
  static const double _columnsBreakpoint = 720;

  late final KanbanBoardController _controller;
  late final KanbanRepository _repository;
  String _status = 'running';

  /// The card a phone is dragging by its handle, while it is.
  String? _dragId;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    final api = auth.api;
    _repository = widget.repository ?? KanbanRepository(api!);
    KanbanEventsConnect connect;
    if (widget.connect != null) {
      connect = widget.connect!;
    } else {
      final socket = hermesSocketConnect(
        baseUrl: auth.baseUrl!,
        authRequired: auth.status?.authRequired ?? true,
        api: api!,
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
                    _BoardMenu(
                      controller: _controller,
                      onManage: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => KanbanBoardsScreen(
                            controller: _controller,
                            repository: _repository,
                          ),
                        ),
                      ),
                    ),
                  _LiveDot(live: _controller.live),
                  if (_controller.board != null) _moreMenu(),
                  const SizedBox(width: 4),
                ],
              ),
        bottomNavigationBar: _controller.selecting ? _bulkBar() : null,
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
    if (created == true) _controller.refresh();
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
    _controller.previewMove(task.id, status);
    await runKanbanAction(
      context,
      () => _repository.updateTask(
        task.id,
        status: status,
        board: _controller.boardSlug,
      ),
    );
    _controller.refresh();
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
    final ok = await runKanbanAction(
      context,
      () => _repository.dispatch(board: _controller.boardSlug),
    );
    if (!ok || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Dispatcher nudged')));
    _controller.refresh();
  }

  /// Applies one change to every selected task, reporting the ones it could
  /// not apply to.
  Future<void> _bulk({
    String? status,
    String? assignee,
    int? priority,
    bool archive = false,
  }) async {
    final ids = _controller.selected.toList();
    if (ids.isEmpty) return;
    var failures = const <KanbanBulkFailure>[];
    final ok = await runKanbanAction(context, () async {
      failures = await _repository.bulkUpdate(
        ids,
        status: status,
        assignee: assignee,
        priority: priority,
        archive: archive,
        board: _controller.boardSlug,
      );
    });
    if (!ok || !mounted) return;
    if (failures.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${failures.length} of ${ids.length} could not be changed: '
            '${failures.first.error}',
          ),
        ),
      );
    }
    if (failures.isEmpty) {
      _controller.stopSelecting();
    } else {
      // A refusal without a task id cannot say which to keep, so keep all.
      final failed = failures.map((f) => f.id).where((id) => id.isNotEmpty);
      if (failed.isNotEmpty) _controller.keepSelected(failed);
    }
    _controller.refresh();
  }

  Future<T?> _pick<T>(String title, List<(String, T)> options) => showDialog<T>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(title),
      children: [
        for (final (label, value) in options)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, value),
            child: Text(label),
          ),
      ],
    ),
  );

  Widget _bulkBar() {
    final none = _controller.selected.isEmpty;
    return BottomAppBar(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: none
                  ? null
                  : () async {
                      final status = await _pick('Move to', [
                        for (final s in kanbanSettableStatuses)
                          (kanbanStatusLabel(s), s),
                      ]);
                      if (status != null) _bulk(status: status);
                    },
              child: const Text('Move'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: none
                  ? null
                  : () async {
                      final names = _controller.board?.assignees ?? const [];
                      final assignee = await _pick('Assign to', [
                        ('Nobody', ''),
                        for (final n in names) (n, n),
                      ]);
                      if (assignee != null) _bulk(assignee: assignee);
                    },
              child: const Text('Assign'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: none
                  ? null
                  : () async {
                      final priority = await _pick('Priority', [
                        ('Normal', 0),
                        for (final p in [1, 2, 3]) ('P$p', p),
                      ]);
                      if (priority != null) _bulk(priority: priority);
                    },
              child: const Text('Priority'),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: none
                  ? null
                  : () async {
                      if (await confirmKanban(
                        context,
                        title: 'Archive ${_controller.selected.length} tasks?',
                        confirm: 'Archive',
                      )) {
                        _bulk(archive: true);
                      }
                    },
              child: const Text('Archive'),
            ),
          ),
        ],
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
      handle: longPressSelects && !selecting ? _handle(task) : null,
    );
  }

  /// A card in a list or a column. Its key follows the task, so a card that
  /// a refetch moved here is a new widget and can arrive with an animation.
  Widget _item(KanbanTask task, {required bool narrow}) => _Arrival(
    key: ValueKey(task.id),
    animate: _controller.arrived(task.id),
    child: narrow ? _card(task, longPressSelects: true) : _draggable(task),
  );

  Widget _feedback(KanbanTask task) => SizedBox(
    width: 240,
    child: Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(kHermesRadius),
      child: KanbanCard(task: task),
    ),
  );

  /// A mouse or trackpad drags at once; a finger has to hold first, or it
  /// could not scroll the column. Which one applies follows the pointer in
  /// use, not the platform: a tablet takes both.
  Widget _draggable(KanbanTask task) {
    final childWhenDragging = Opacity(
      opacity: 0.4,
      child: KanbanCard(task: task),
    );
    return _PointerDraggable(
      data: task,
      feedback: _feedback(task),
      childWhenDragging: childWhenDragging,
      child: _TouchDraggable(
        data: task,
        feedback: _feedback(task),
        childWhenDragging: childWhenDragging,
        child: _card(task),
      ),
    );
  }

  /// On a phone a long press selects, so the card is dragged by its handle.
  Widget _handle(KanbanTask task) => Draggable<KanbanTask>(
    data: task,
    feedback: _feedback(task),
    onDragStarted: () => setState(() => _dragId = task.id),
    onDragEnd: (_) => setState(() => _dragId = null),
    child: Tooltip(
      message: 'Drag to move',
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          Icons.drag_indicator,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
    ),
  );

  Widget _body(BuildContext context) {
    final board = _controller.board;
    if (board == null) {
      if (_controller.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return _Message(
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
        final wide = constraints.maxWidth >= _columnsBreakpoint;
        return Column(
          children: [
            if (_controller.refreshFailed)
              _RefreshFailedNotice(onRetry: _controller.refresh),
            _Toolbar(controller: _controller, board: board, wide: wide),
            Expanded(child: wide ? _columns(context) : _list(context)),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context) {
    final columns = _controller.columns;
    final shown = columns.any((c) => c.name == _status)
        ? _status
        : (columns.isEmpty ? _status : columns.first.name);
    final tasks =
        columns.where((c) => c.name == shown).firstOrNull?.tasks ?? const [];
    return Column(
      children: [
        _StatusChips(
          columns: columns,
          selected: shown,
          onSelected: (name) => setState(() => _status = name),
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
                  child: _DropStrip(onDrop: _move),
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

/// A draggable that only a mouse or trackpad starts, at once.
class _PointerDraggable extends Draggable<KanbanTask> {
  const _PointerDraggable({
    required super.data,
    required super.feedback,
    required super.childWhenDragging,
    required super.child,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) => ImmediateMultiDragGestureRecognizer(
    supportedDevices: {PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
  )..onStart = onStart;
}

/// A draggable that only a finger or stylus starts, after a long press.
class _TouchDraggable extends LongPressDraggable<KanbanTask> {
  const _TouchDraggable({
    required super.data,
    required super.feedback,
    required super.childWhenDragging,
    required super.child,
  });

  @override
  DelayedMultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) =>
      DelayedMultiDragGestureRecognizer(
          delay: delay,
          supportedDevices: {PointerDeviceKind.touch, PointerDeviceKind.stylus},
        )
        ..onStart = (position) {
          final drag = onStart(position);
          if (drag != null && hapticFeedbackOnStart) {
            HapticFeedback.selectionClick();
          }
          return drag;
        };
}

/// The statuses a card dragged on a phone can be dropped on. The chip row
/// scrolls and would hide most of them, so they are laid out all at once,
/// over the top of the list while a drag lasts.
class _DropStrip extends StatelessWidget {
  const _DropStrip({required this.onDrop});

  final void Function(KanbanTask task, String status) onDrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final status in kanbanSettableStatuses)
              DragTarget<KanbanTask>(
                onWillAcceptWithDetails: (d) => d.data.status != status,
                onAcceptWithDetails: (d) => onDrop(d.data, status),
                builder: (context, over, rejected) => Chip(
                  label: Text(kanbanStatusLabel(status)),
                  backgroundColor: over.isEmpty
                      ? null
                      : theme.colorScheme.primaryContainer,
                  side: BorderSide(
                    color: over.isEmpty
                        ? theme.colorScheme.outline
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fades and grows its child in when it first appears, if [animate]: a card
/// that another client just moved here, arriving where it can be seen.
class _Arrival extends StatefulWidget {
  const _Arrival({super.key, required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<_Arrival> createState() => _ArrivalState();
}

class _ArrivalState extends State<_Arrival>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: widget.animate ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _animation.forward();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _animation,
      curve: Curves.easeOutCubic,
    );
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      // The size transition loosens its child, which would shrink the card
      // to its content instead of the column.
      child: FadeTransition(
        opacity: curved,
        child: SizedBox(width: double.infinity, child: widget.child),
      ),
    );
  }
}

/// The row of status chips on a narrow screen. It brings the selected chip
/// into view when it first appears (a fresh row starts at the left, which may
/// hide it, e.g. after the screen is rotated) and whenever the selection moves.
class _StatusChips extends StatefulWidget {
  const _StatusChips({
    required this.columns,
    required this.selected,
    required this.onSelected,
  });

  final List<KanbanColumn> columns;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  State<_StatusChips> createState() => _StatusChipsState();
}

class _StatusChipsState extends State<_StatusChips> {
  final _selectedChip = GlobalKey();

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(_StatusChips old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _reveal();
  }

  void _reveal() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final chip = _selectedChip.currentContext;
    if (chip != null && mounted) Scrollable.ensureVisible(chip, alignment: 0.5);
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (final c in widget.columns)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: c.name == widget.selected ? _selectedChip : null,
                label: Text('${kanbanStatusLabel(c.name)} ${c.tasks.length}'),
                selected: c.name == widget.selected,
                onSelected: (_) => widget.onSelected(c.name),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.board,
    required this.wide,
  });

  final KanbanBoardController controller;
  final KanbanBoard board;

  /// A wide screen has no pull-to-refresh, so it gets a refresh button.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: 'Search tasks',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(kHermesRadius),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: controller.setQuery,
                  ),
                ),
              ),
              if (wide)
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: controller.refresh,
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (board.assignees.isNotEmpty)
                  _FilterMenu(
                    label: controller.assignee ?? 'All assignees',
                    all: 'All assignees',
                    options: board.assignees,
                    onSelected: controller.setAssignee,
                  ),
                if (board.tenants.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _FilterMenu(
                    label: controller.tenant ?? 'All tenants',
                    all: 'All tenants',
                    options: board.tenants,
                    onSelected: controller.setTenant,
                  ),
                ],
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Archived'),
                  selected: controller.includeArchived,
                  onSelected: controller.setIncludeArchived,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Says the board on screen may be out of date, without covering it.
class _RefreshFailedNotice extends StatelessWidget {
  const _RefreshFailedNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: scheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Could not refresh. Showing the last board.',
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.all,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final String all;
  final List<String> options;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        PopupMenuItem(value: null, child: Text(all)),
        for (final o in options) PopupMenuItem(value: o, child: Text(o)),
      ],
      child: Chip(
        label: Text(label),
        avatar: const Icon(Icons.filter_list, size: 16),
      ),
    );
  }
}

class _BoardMenu extends StatelessWidget {
  const _BoardMenu({required this.controller, required this.onManage});

  final KanbanBoardController controller;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Switch board',
      icon: const Icon(Icons.dashboard_customize_outlined),
      onSelected: (slug) =>
          slug.isEmpty ? onManage() : controller.selectBoard(slug),
      itemBuilder: (_) => [
        for (final b in controller.boards)
          CheckedPopupMenuItem(
            value: b.slug,
            checked: b.slug == controller.boardSlug,
            child: Text('${b.name} (${b.total})'),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(value: '', child: Text('Manage boards…')),
      ],
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.live});

  final bool live;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: live ? 'Live' : 'Reconnecting…',
    child: Icon(
      Icons.circle,
      size: 10,
      color: live ? Colors.green : Colors.grey,
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (detail != null) Text(detail!),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ],
    ),
  );
}
