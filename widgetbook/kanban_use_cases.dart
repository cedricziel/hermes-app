import 'package:flutter/material.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_board_menu.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_board_toolbar.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_bulk_bar.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_card.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_card_drag.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_drop_strip.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_status_chips.dart';
import 'package:widgetbook/widgetbook.dart';

import 'fixtures.dart';
import 'frame.dart';
import 'kanban_screen_use_cases.dart';
import 'kanban_task_use_cases.dart';

WidgetbookUseCase _card(String name, KanbanCard card) =>
    WidgetbookUseCase(name: name, builder: (_) => frame(card, maxWidth: 320));

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
