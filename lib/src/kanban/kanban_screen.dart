import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';
import '../chat/gateway/gateway_connection.dart';
import 'kanban_board_controller.dart';
import 'kanban_models.dart';
import 'kanban_repository.dart';
import 'widgets/kanban_card.dart';

/// The Kanban board: status chips over a card list on a phone, real columns
/// on a wide screen. Kept current by the plugin's event stream.
class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key, this.repository, this.connect});

  /// Override the repository / event stream built from the signed-in client.
  final KanbanRepository? repository;
  final KanbanEventsConnect? connect;

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> {
  static const double _columnsBreakpoint = 720;

  late final KanbanBoardController _controller;
  String _status = 'running';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    final api = auth.api;
    final repository = widget.repository ?? KanbanRepository(api!.raw);
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
      repository: repository,
      connect: connect,
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
        appBar: AppBar(
          title: const Text('Kanban'),
          actions: [
            if (_controller.boards.length > 1)
              _BoardMenu(controller: _controller),
            _LiveDot(live: _controller.live),
            const SizedBox(width: 12),
          ],
        ),
        body: _body(context),
      ),
    );
  }

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
    return Column(
      children: [
        _Toolbar(controller: _controller, board: board),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= _columnsBreakpoint
                ? _columns(context)
                : _list(context),
          ),
        ),
      ],
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
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final c in columns)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      '${kanbanStatusLabel(c.name)} ${c.tasks.length}',
                    ),
                    selected: c.name == shown,
                    onSelected: (_) => setState(() => _status = c.name),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
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
                    itemBuilder: (_, i) => KanbanCard(task: tasks[i]),
                  ),
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
        return SizedBox(
          width: 260,
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
                  itemBuilder: (_, j) => KanbanCard(task: column.tasks[j]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.controller, required this.board});

  final KanbanBoardController controller;
  final KanbanBoard board;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Search tasks',
                border: OutlineInputBorder(),
              ),
              onChanged: controller.setQuery,
            ),
          ),
          if (board.assignees.isNotEmpty)
            _FilterMenu(
              label: controller.assignee ?? 'All assignees',
              all: 'All assignees',
              options: board.assignees,
              onSelected: controller.setAssignee,
            ),
          if (board.tenants.isNotEmpty)
            _FilterMenu(
              label: controller.tenant ?? 'All tenants',
              all: 'All tenants',
              options: board.tenants,
              onSelected: controller.setTenant,
            ),
          FilterChip(
            label: const Text('Archived'),
            selected: controller.includeArchived,
            onSelected: controller.setIncludeArchived,
          ),
        ],
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
  const _BoardMenu({required this.controller});

  final KanbanBoardController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Switch board',
      icon: const Icon(Icons.dashboard_customize_outlined),
      onSelected: controller.selectBoard,
      itemBuilder: (_) => [
        for (final b in controller.boards)
          CheckedPopupMenuItem(
            value: b.slug,
            checked: b.slug == controller.boardSlug,
            child: Text('${b.name} (${b.total})'),
          ),
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
