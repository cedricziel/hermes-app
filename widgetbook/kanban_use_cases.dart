import 'package:flutter/material.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_board_menu.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_board_toolbar.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_bulk_bar.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_card.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_card_drag.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_drop_strip.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_inspector_layout.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_list_rows.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_mac_toolbar.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_status_chips.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';
import 'kanban_screen_use_cases.dart';
import 'kanban_task_use_cases.dart';

WidgetbookUseCase _card(String name, Widget card) =>
    WidgetbookUseCase(name: name, builder: (_) => frame(card, maxWidth: 320));

Widget _material(Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.android),
    child: child,
  ),
);

Widget _mac(Widget child) => Builder(
  builder: (context) => Theme(
    data: Theme.of(context).copyWith(platform: TargetPlatform.macOS),
    child: child,
  ),
);

KanbanMacToolbar _macToolbar({
  String? profile,
  bool inspectorShown = true,
  bool live = true,
}) => KanbanMacToolbar(
  taskCount: 12,
  boards: _boards,
  board: 'default',
  profiles: const ['coder', 'writer'],
  profile: profile,
  live: live,
  inspectorShown: inspectorShown,
  onNewTask: () {},
  onSelectBoard: (_) {},
  onManageBoards: () {},
  onProfileChanged: (_) {},
  onToggleInspector: () {},
);

Widget _boardColumns() => SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  padding: const EdgeInsets.all(16),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final task in [plainTask, busyTask, plainTask])
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
            width: 232,
            child: KanbanCard(task: task, selected: task == busyTask),
          ),
        ),
    ],
  ),
);

Widget _inspectorContent() => ListView(
  padding: const EdgeInsets.all(16),
  children: [
    Text(busyTask.id),
    Text(busyTask.title, style: const TextStyle(fontSize: 20)),
    const SizedBox(height: 12),
    const Text('The task panel goes here, as in the sheet.'),
  ],
);

WidgetbookUseCase _layout(
  String name, {
  required double width,
  bool shown = true,
  bool withTask = true,
}) => WidgetbookUseCase(
  name: name,
  builder: (_) => _mac(
    Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: Scaffold(
          appBar: _macToolbar(inspectorShown: shown),
          body: KanbanInspectorLayout(
            board: _boardColumns(),
            shown: shown,
            inspector: withTask ? _inspectorContent() : null,
          ),
        ),
      ),
    ),
  ),
);

WidgetbookUseCase _use(String name, Widget widget, {double maxWidth = 480}) =>
    WidgetbookUseCase(
      name: name,
      builder: (_) => frame(widget, maxWidth: maxWidth),
    );

const _columns = [
  KanbanColumn(name: 'triage', tasks: []),
  KanbanColumn(name: 'todo', tasks: [plainTask]),
  KanbanColumn(name: 'running', tasks: [busyTask]),
  KanbanColumn(name: 'review', tasks: []),
  KanbanColumn(name: 'blocked', tasks: []),
  KanbanColumn(name: 'done', tasks: [plainTask, plainTask]),
];

const _boards = [
  KanbanBoardInfo(slug: 'default', name: 'Default', total: 12),
  KanbanBoardInfo(slug: 'ops', name: 'Ops', total: 3),
];

KanbanBoardToolbar _toolbar({
  List<String> assignees = const [],
  List<String> tenants = const [],
  String? assignee,
  String? tenant,
  bool includeArchived = false,
  bool wide = false,
}) => KanbanBoardToolbar(
  assignees: assignees,
  tenants: tenants,
  assignee: assignee,
  tenant: tenant,
  includeArchived: includeArchived,
  wide: wide,
  onQueryChanged: (_) {},
  onAssigneeChanged: (_) {},
  onTenantChanged: (_) {},
  onIncludeArchivedChanged: (_) {},
  onRefresh: () {},
);

KanbanBulkBar _bulkBar(int count) => KanbanBulkBar(
  selectedCount: count,
  assignees: const ['coder', 'writer'],
  onMove: (_) {},
  onAssign: (_) {},
  onPriority: (_) {},
  onEffort: (_) {},
  onArchive: () {},
);

WidgetbookNode kanbanNode() => WidgetbookFolder(
  name: 'Kanban',
  children: [
    WidgetbookComponent(
      name: 'KanbanCard',
      useCases: [
        _card('Plain', const KanbanCard(task: plainTask)),
        _card('Busy', const KanbanCard(task: busyTask)),
        _card('Selected', const KanbanCard(task: busyTask, selected: true)),
        _card(
          'With drag handle',
          const KanbanCard(
            task: plainTask,
            handle: KanbanDragHandle(task: plainTask),
          ),
        ),
        _card(
          'With drag handle (Material)',
          _material(
            const KanbanCard(
              task: plainTask,
              handle: KanbanDragHandle(task: plainTask),
            ),
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'KanbanDragFeedback',
      useCases: [_use('Dragged', const KanbanDragFeedback(task: busyTask))],
    ),
    WidgetbookComponent(
      name: 'KanbanBoardToolbar',
      useCases: [
        _use('No filters', _toolbar()),
        _use('Material (Android)', _material(_toolbar())),
        _use(
          'Filters',
          _toolbar(
            assignees: const ['coder', 'writer'],
            tenants: const ['mobile', 'web'],
          ),
        ),
        _use(
          'Filtered',
          _toolbar(
            assignees: const ['coder', 'writer'],
            tenants: const ['mobile', 'web'],
            assignee: 'coder',
            tenant: 'mobile',
            includeArchived: true,
          ),
        ),
        _use(
          'Wide',
          _toolbar(assignees: const ['coder'], wide: true),
          maxWidth: 900,
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'KanbanMacToolbar',
      useCases: [
        _use('All profiles, inspector on', _mac(_macToolbar()), maxWidth: 1000),
        _use(
          'Filtered, inspector off, reconnecting',
          _mac(
            _macToolbar(profile: 'coder', inspectorShown: false, live: false),
          ),
          maxWidth: 1000,
        ),
        _use('Compact window', _mac(_macToolbar()), maxWidth: 680),
      ],
    ),
    WidgetbookComponent(
      name: 'KanbanInspectorLayout',
      useCases: [
        _layout('Docked, a task open', width: 1000),
        _layout('Docked, no task yet', width: 1000, withTask: false),
        _layout('Hidden', width: 1000, shown: false),
        _layout('Overlay in a compact window', width: 680),
      ],
    ),
    WidgetbookComponent(
      name: 'KanbanRefreshFailedNotice',
      useCases: [_use('Failed', KanbanRefreshFailedNotice(onRetry: () {}))],
    ),
    WidgetbookComponent(
      name: 'KanbanStatusChips',
      useCases: [
        _use(
          'First selected',
          KanbanStatusChips(
            columns: _columns,
            selected: 'triage',
            onSelected: (_) {},
          ),
        ),
        _use(
          'Material (Android)',
          _material(
            KanbanStatusChips(
              columns: _columns,
              selected: 'todo',
              onSelected: (_) {},
            ),
          ),
        ),
        _use(
          'Last selected',
          KanbanStatusChips(
            columns: _columns,
            selected: 'done',
            onSelected: (_) {},
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'KanbanDropStrip',
      useCases: [_use('Dragging', KanbanDropStrip(onDrop: (_, _) {}))],
    ),
    WidgetbookComponent(
      name: 'KanbanBulkBar',
      useCases: [
        _use('None selected', _bulkBar(0)),
        _use('Some selected', _bulkBar(3)),
        _use('Material (Android)', _material(_bulkBar(3))),
      ],
    ),
    WidgetbookComponent(
      name: 'KanbanBoardMenu',
      useCases: [
        _use(
          'Boards',
          KanbanBoardMenu(
            boards: _boards,
            selected: 'default',
            onSelected: (_) {},
            onManage: () {},
          ),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'KanbanBoardRow',
      useCases: [
        ...onEachPlatform('Boards', (_) => frame(_boardRows(removable: true))),
        ...onEachPlatform(
          'Only board',
          (_) => frame(_boardRows(removable: false)),
        ),
      ],
    ),
    WidgetbookComponent(
      name: 'KanbanWorkerRow',
      useCases: [...onEachPlatform('Workers', (_) => frame(_workerRows()))],
    ),
    WidgetbookComponent(
      name: 'KanbanLiveDot',
      useCases: [
        _use('Live', const KanbanLiveDot(live: true)),
        _use('Reconnecting', const KanbanLiveDot(live: false)),
      ],
    ),
    ...kanbanTaskComponents(),
    ...kanbanScreenComponents(),
  ],
);

Widget _boardRows({required bool removable}) => GroupedSection(
  children: [
    for (final board in removable ? _boards : _boards.take(1))
      KanbanBoardRow(
        board: board,
        current: board.slug == 'default',
        onOpen: () {},
        onRename: () {},
        onExport: () {},
        onArchive: removable ? () {} : null,
        onDelete: removable ? () {} : null,
      ),
  ],
);

Widget _workerRows() => GroupedSection(
  children: [
    for (final worker in [
      KanbanWorker(
        runId: 7,
        taskId: 't_run',
        taskTitle: 'Migrate webhooks to v2 signing',
        profile: 'coder',
        startedAt: DateTime.now().subtract(const Duration(minutes: 12)),
        lastHeartbeatAt: DateTime.now().subtract(const Duration(seconds: 20)),
      ),
      const KanbanWorker(
        runId: 8,
        taskId: 't_review',
        taskTitle: 'Review the settings layout',
      ),
    ])
      KanbanWorkerRow(
        worker: worker,
        onOpen: () {},
        onInspect: () {},
        onTerminate: () {},
      ),
  ],
);
