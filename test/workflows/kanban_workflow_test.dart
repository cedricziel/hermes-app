import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:stream_channel/stream_channel.dart';

import '../support/fake_hermes_server.dart';
import '../support/kanban_fixtures.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// Working the board: browsing columns, opening a task, selecting several,
/// creating one, and what the board says when the plugin is gone.
void main() {
  late FakeHermesServer server;

  final tasks = [
    kanbanTaskRow(
      id: 't_triage',
      title: 'Investigate flaky checkout test',
      status: 'triage',
      priority: 1,
    ),
    kanbanTaskRow(
      id: 't_todo',
      title:
          'Write docs for the webhook signing migration and its rollout '
          'plan across every environment we run',
      status: 'todo',
      assignee: 'writer',
      commentCount: 12,
    ),
    kanbanTaskRow(
      id: 't_run',
      title: 'Migrate webhooks',
      status: 'running',
      assignee: 'coder',
      priority: 2,
      commentCount: 4,
      progress: {'done': 2, 'total': 5},
    ),
    kanbanTaskRow(
      id: 't_run2',
      title: 'Rotate staging certificates',
      status: 'running',
      assignee: 'ops-assistant-with-a-long-name',
      tenant: 'acme',
      progress: {'done': 0, 'total': 3},
    ),
    kanbanTaskRow(
      id: 't_blocked',
      title: 'Upgrade the database',
      status: 'blocked',
      assignee: 'coder',
      warnings: {'count': 1, 'kinds': <String>[]},
    ),
    kanbanTaskRow(id: 't_done', title: 'Ship v0.14', status: 'done'),
  ];

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/plugins/kanban/boards',
        kanbanBoardsBody([
          (slug: 'default', name: 'Default', total: 6, current: true),
          (
            slug: 'ops',
            name: 'Operations and infrastructure',
            total: 2,
            current: false,
          ),
        ]),
      )
      ..on(
        'GET',
        '/api/plugins/kanban/board',
        kanbanBoardBody(tasks, tenants: ['acme']),
      )
      ..on('GET', '/api/plugins/kanban/assignees', {
        'assignees': ['coder', 'writer'],
      })
      ..on('POST', '/api/plugins/kanban/tasks', {
        'task': {'id': 't9'},
      })
      ..on(
        'GET',
        '/api/plugins/kanban/tasks/t_run',
        kanbanTaskDetailBody(
          kanbanTaskRow(
              id: 't_run',
              title: 'Migrate webhooks',
              status: 'running',
              assignee: 'coder',
              priority: 2,
            )
            ..['body'] =
                'Move every outgoing webhook to **v2 signing**.\n\n'
                '- endpoints\n- retries\n- docs',
          comments: [
            {
              'author': 'coder',
              'body': 'Endpoint 1 is done, moving on to the retry queue.',
              'created_at': 1780000000,
            },
            {
              'author': 'writer',
              'body': 'Docs are drafted: https://example.internal/docs/webhooks/v2/signing-migration',
              'created_at': 1780000200,
            },
          ],
          parents: ['t_triage'],
        ),
      );
  });

  Future<void> pumpBoard(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
  }) => pumpScreen(
    tester,
    shots,
    KanbanScreen(
      repository: KanbanRepository(server.client()),
      connect: ({required since, board}) async =>
          StreamChannelController<String>().foreign,
    ),
    size: size,
    brightness: brightness,
  );

  testWidgets('phone: browse, open, select, create', (tester) async {
    final shots = ScreenshotRecorder('kanban-phone');
    await pumpBoard(tester, shots, size: phoneSize);
    await shots.capture(tester, 'board');

    await tester.ensureVisible(find.text('Todo 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todo 1'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'todo-column');

    await tester.ensureVisible(find.textContaining('Running'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Running'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Migrate webhooks'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'task-detail');
    await popRoute(tester);

    await tester.longPress(find.text('Migrate webhooks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rotate staging certificates'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'selection');

    await tester.tap(find.byTooltip('Cancel selection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'create');
  });

  testWidgets('phone: menus', (tester) async {
    final shots = ScreenshotRecorder('kanban-phone-menus');
    await pumpBoard(tester, shots, size: phoneSize);
    await tester.tap(find.byTooltip('Switch board'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'switch-board');
    await tester.tap(find.text('Manage boards…'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'manage-boards');
  });

  testWidgets('desktop: columns and a task', (tester) async {
    final shots = ScreenshotRecorder('kanban-desktop');
    await pumpBoard(tester, shots, size: desktopSize);
    await shots.capture(tester, 'board');

    await tester.tap(find.text('Migrate webhooks'));
    await tester.pumpAndSettle();
    await shots.capture(tester, 'task-detail');
  });

  for (final (flow, size) in [
    ('kanban-phone-dark', phoneSize),
    ('kanban-desktop-dark', desktopSize),
  ]) {
    testWidgets('$flow: board', (tester) async {
      final shots = ScreenshotRecorder(flow);
      await pumpBoard(tester, shots, size: size, brightness: Brightness.dark);
      await shots.capture(tester, 'board');
    });
  }

  testWidgets('what the board says when it cannot load', (tester) async {
    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 500);
    final failed = ScreenshotRecorder('kanban-phone-errors');
    await pumpBoard(tester, failed, size: phoneSize);
    await failed.capture(tester, 'load-failed');

    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 404);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await failed.capture(tester, 'plugin-off');
  });
}
