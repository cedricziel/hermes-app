import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/kanban_board_controller.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_create_screen.dart';
import 'package:hermes_app/src/kanban/kanban_files.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/kanban/kanban_workers_screen.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_orchestration_dialog.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_log_dialog.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:provider/provider.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:widgetbook/widgetbook.dart';

import '../test/support/fake_hermes_server.dart';
import '../test/support/kanban_fixtures.dart';
import 'host.dart';

const _root = '/api/plugins/kanban';

final _tasks = [
  kanbanTaskRow(
    id: 't_run',
    title: 'Migrate webhooks to v2 signing',
    status: 'running',
    assignee: 'coder',
    priority: 2,
    commentCount: 4,
    progress: {'done': 2, 'total': 5},
  ),
  kanbanTaskRow(id: 't_todo', title: 'Write the release notes', status: 'todo'),
  kanbanTaskRow(
    id: 't_review',
    title: 'Review the settings layout',
    status: 'review',
    assignee: 'reviewer',
  ),
  kanbanTaskRow(id: 't_done', title: 'Bump dependencies', status: 'done'),
];

/// A Kanban plugin with a few boards, tasks and one running worker.
FakeHermesServer kanbanServer({bool empty = false}) => FakeHermesServer()
  ..on(
    'GET',
    '$_root/boards',
    kanbanBoardsBody([
      (slug: 'default', name: 'Default', total: 4, current: true),
      (slug: 'ops', name: 'Ops', total: 1, current: false),
    ]),
  )
  ..on('GET', '$_root/board', kanbanBoardBody(empty ? [] : _tasks))
  ..on('GET', '$_root/assignees', {
    'assignees': ['coder', 'writer', 'reviewer'],
  })
  ..on('GET', '$_root/workers/active', {
    'workers': [
      {
        'run_id': 7,
        'task_id': 't_run',
        'task_title': 'Migrate webhooks to v2 signing',
        'profile': 'coder',
        'worker_pid': 4242,
        'started_at': 1780000000,
      },
    ],
  })
  ..on(
    'GET',
    '$_root/tasks/t_run',
    kanbanTaskDetailBody(
      kanbanTaskRow(
        id: 't_run',
        title: 'Migrate webhooks to v2 signing',
        status: 'running',
        assignee: 'coder',
        priority: 2,
      )..['body'] = 'Move every endpoint to the v2 signature scheme.',
      comments: [
        {
          'author': 'coder',
          'body': 'Endpoint 1 done, starting on the second.',
          'created_at': 1780000000,
        },
      ],
      parents: ['t_todo'],
      runs: [
        {
          'id': 7,
          'status': 'running',
          'profile': 'coder',
          'started_at': 1780000000,
        },
      ],
      attachments: [
        {'id': 3, 'filename': 'spec.pdf', 'size': 2048},
      ],
    ),
  )
  ..on('GET', '$_root/tasks/t_run/log', {
    'exists': true,
    'content': 'starting worker\nread lib/webhooks.dart\nwriting the patch',
  })
  ..on('GET', '$_root/orchestration', {
    'orchestrator_profile': 'lead',
    'default_assignee': '',
    'auto_decompose': false,
    'auto_promote_children': true,
    'active_profile': 'default',
  })
  ..on('PUT', '$_root/orchestration', {
    'orchestrator_profile': 'lead',
    'auto_decompose': true,
    'auto_promote_children': true,
    'active_profile': 'default',
  })
  ..on('POST', '$_root/tasks', {
    'task': {'id': 't_new'},
  })
  ..on('POST', '$_root/boards', {'board': {}});

/// Serves the board and stays quiet: there is no event stream in the catalog.
Future<StreamChannel<String>> _noEvents({
  required int since,
  String? board,
}) async => StreamChannelController<String>().foreign;

class _NoFiles implements KanbanFiles {
  @override
  Future<KanbanPickedFile?> pick() async => null;

  @override
  Future<bool> save(String name, Uint8List bytes) async => true;
}

WidgetbookUseCase _screen(
  String name,
  FakeHermesServer Function() server,
  Widget Function(KanbanRepository repository) build,
) => WidgetbookUseCase(
  name: name,
  builder: (_) => Hosted<KanbanRepository>(
    create: () => KanbanRepository(server().client()),
    builder: (_, repository) => build(repository),
  ),
);

WidgetbookUseCase _boardScreen(String name, {bool empty = false}) =>
    WidgetbookUseCase(
      name: name,
      builder: (_) => Hosted<AuthController>(
        create: AuthController.new,
        dispose: (auth) => auth.dispose(),
        builder: (_, auth) => ChangeNotifierProvider.value(
          value: auth,
          child: KanbanScreen(
            repository: KanbanRepository(kanbanServer(empty: empty).client()),
            connect: _noEvents,
            files: _NoFiles(),
          ),
        ),
      ),
    );

List<WidgetbookNode> kanbanScreenComponents() => [
  WidgetbookComponent(
    name: 'KanbanScreen',
    useCases: [_boardScreen('Board'), _boardScreen('Empty board', empty: true)],
  ),
  WidgetbookComponent(
    name: 'KanbanBoardsScreen',
    useCases: [
      WidgetbookUseCase(
        name: 'Boards',
        builder: (_) => Hosted<KanbanBoardController>(
          create: () async {
            final controller = KanbanBoardController(
              repository: KanbanRepository(kanbanServer().client()),
              connect: _noEvents,
            );
            await controller.start();
            return controller;
          },
          dispose: (controller) => controller.dispose(),
          builder: (_, controller) => KanbanBoardsScreen(
            controller: controller,
            repository: KanbanRepository(kanbanServer().client()),
          ),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'KanbanCreateScreen',
    useCases: [
      _screen(
        'Form',
        kanbanServer,
        (repository) =>
            KanbanCreateScreen(repository: repository, tenant: 'mobile'),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'KanbanWorkersScreen',
    useCases: [
      _screen(
        'Running worker',
        kanbanServer,
        (repository) => KanbanWorkersScreen(repository: repository),
      ),
      _screen(
        'No workers',
        () =>
            kanbanServer()..on('GET', '$_root/workers/active', {'workers': []}),
        (repository) => KanbanWorkersScreen(repository: repository),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'KanbanTaskPanel',
    useCases: [
      _screen(
        'Running task',
        kanbanServer,
        (repository) => Scaffold(
          body: KanbanTaskPanel(
            repository: repository,
            taskId: 't_run',
            files: _NoFiles(),
          ),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'KanbanTaskLogDialog',
    useCases: [
      _screen(
        'Log',
        kanbanServer,
        (repository) => Center(
          child: KanbanTaskLogDialog(repository: repository, taskId: 't_run'),
        ),
      ),
      _screen(
        'Log unavailable',
        () => kanbanServer()
          ..on('GET', '$_root/tasks/t_run/log', {
            'detail': 'gone',
          }, status: 500),
        (repository) => Center(
          child: KanbanTaskLogDialog(repository: repository, taskId: 't_run'),
        ),
      ),
    ],
  ),
  WidgetbookComponent(
    name: 'KanbanOrchestrationDialog',
    useCases: [
      _screen(
        'Settings',
        kanbanServer,
        (repository) =>
            Center(child: KanbanOrchestrationDialog(repository: repository)),
      ),
    ],
  ),
];
