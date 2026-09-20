import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late int changes;

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/plugins/kanban/tasks/t1',
        kanbanTaskDetailBody(
          kanbanTaskRow(
            id: 't1',
            title: 'Migrate webhooks',
            status: 'running',
            assignee: 'coder',
            priority: 2,
          )..['body'] = 'Move to v2 signing',
          comments: [
            {
              'author': 'coder',
              'body': 'Endpoint 1 done',
              'created_at': 1780000000,
            },
          ],
          parents: ['t0'],
        ),
      )
      ..on('GET', '/api/plugins/kanban/assignees', {
        'assignees': ['coder', 'writer'],
      })
      ..on('PATCH', '/api/plugins/kanban/tasks/t1', {'ok': true})
      ..on('POST', '/api/plugins/kanban/tasks/t1/comments', {'ok': true});
    changes = 0;
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: KanbanTaskPanel(
            repository: KanbanRepository(server.client().raw),
            taskId: 't1',
            board: 'ops',
            onChanged: () => changes++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the task, its description, links and comments', (
    tester,
  ) async {
    await pumpPanel(tester);

    expect(find.text('Migrate webhooks'), findsOneWidget);
    expect(find.text('Move to v2 signing'), findsOneWidget);
    expect(find.text('coder'), findsWidgets);
    expect(find.text('t0'), findsOneWidget);
    expect(find.textContaining('Endpoint 1 done'), findsOneWidget);
    expect(
      server
          .requestsTo('GET', '/api/plugins/kanban/tasks/t1')
          .single
          .queryParameters['board'],
      'ops',
    );
  });

  testWidgets('blocking asks why and tells the board', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Waiting on design');
    await tester.tap(find.widgetWithText(FilledButton, 'Block'));
    await tester.pumpAndSettle();

    final body = jsonBody(
      server.requestsTo('PATCH', '/api/plugins/kanban/tasks/t1').single,
    );
    expect(body, containsPair('status', 'blocked'));
    expect(body, containsPair('block_reason', 'Waiting on design'));
    expect(changes, 1);
  });

  testWidgets('says why when the plugin refuses a move', (tester) async {
    server.on('PATCH', '/api/plugins/kanban/tasks/t1', {
      'detail': 'Cannot move to ready: parent open',
    }, status: 409);
    await pumpPanel(tester);

    await tester.tap(find.text('Move to…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ready'));
    await tester.pumpAndSettle();

    expect(find.text('Cannot move to ready: parent open'), findsOneWidget);
    expect(changes, 0);
  });

  testWidgets('posts a comment and clears the box', (tester) async {
    await pumpPanel(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Add a comment…').first,
      'Ship it',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(
      jsonBody(
        server
            .requestsTo('POST', '/api/plugins/kanban/tasks/t1/comments')
            .single,
      ),
      containsPair('body', 'Ship it'),
    );
    expect(find.text('Ship it'), findsNothing);
  });

  testWidgets('reassigns from the picker', (tester) async {
    await pumpPanel(tester);

    await tester.tap(find.widgetWithText(ActionChip, 'coder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('writer'));
    await tester.pumpAndSettle();

    expect(
      jsonBody(
        server.requestsTo('PATCH', '/api/plugins/kanban/tasks/t1').single,
      ),
      containsPair('assignee', 'writer'),
    );
  });

  testWidgets('unlinks a dependency', (tester) async {
    server.on('DELETE', '/api/plugins/kanban/links', {'ok': true});
    await pumpPanel(tester);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(
      server
          .requestsTo('DELETE', '/api/plugins/kanban/links')
          .single
          .queryParameters,
      {'parent_id': 't0', 'child_id': 't1', 'board': 'ops'},
    );
  });

  void serveStatus(String status) => server.on(
    'GET',
    '/api/plugins/kanban/tasks/t1',
    kanbanTaskDetailBody(
      kanbanTaskRow(id: 't1', title: 'Rough idea', status: status),
    ),
  );

  testWidgets('triage tasks offer Decompose and say how many tasks came out', (
    tester,
  ) async {
    serveStatus('triage');
    server.on('POST', '/api/plugins/kanban/tasks/t1/decompose', {
      'ok': true,
      'child_ids': ['t2', 't3'],
    });
    await pumpPanel(tester);

    await tester.tap(find.text('Decompose'));
    await tester.pumpAndSettle();

    expect(find.text('Decomposed into 2 tasks'), findsOneWidget);
    expect(changes, 1);
  });

  testWidgets('shows why a triage helper declined and changes nothing', (
    tester,
  ) async {
    serveStatus('triage');
    server.on('POST', '/api/plugins/kanban/tasks/t1/specify', {
      'ok': false,
      'reason': 'No auxiliary model configured',
    });
    await pumpPanel(tester);

    await tester.tap(find.text('Specify'));
    await tester.pumpAndSettle();

    expect(find.text('No auxiliary model configured'), findsOneWidget);
    expect(changes, 0);
  });

  testWidgets('only triage tasks offer the triage helpers', (tester) async {
    await pumpPanel(tester);

    expect(find.text('Decompose'), findsNothing);
    expect(find.text('Specify'), findsNothing);
  });

  testWidgets('a running task can be reclaimed after confirming', (
    tester,
  ) async {
    server.on('POST', '/api/plugins/kanban/tasks/t1/reclaim', {'ok': true});
    await pumpPanel(tester);

    await tester.tap(find.text('Reclaim'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reclaim'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('POST', '/api/plugins/kanban/tasks/t1/reclaim'),
      hasLength(1),
    );
    expect(changes, 1);
  });

  void serveRich() => server
    ..on(
      'GET',
      '/api/plugins/kanban/tasks/t1',
      kanbanTaskDetailBody(
        kanbanTaskRow(id: 't1', title: 'Migrate webhooks', status: 'running')
          ..['diagnostics'] = [
            {
              'title': 'Worker stalled',
              'severity': 'error',
              'detail': 'No heartbeat for 10m',
            },
          ],
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
    ..on('POST', '/api/plugins/kanban/runs/7/terminate', {'ok': true})
    ..on('DELETE', '/api/plugins/kanban/attachments/3', {'ok': true})
    ..on('GET', '/api/plugins/kanban/tasks/t1/log', {
      'exists': true,
      'content': 'starting worker',
    });

  testWidgets('shows what needs attention and the attachments', (tester) async {
    serveRich();
    await pumpPanel(tester);

    expect(find.text('Worker stalled'), findsOneWidget);
    expect(find.text('No heartbeat for 10m'), findsOneWidget);
    expect(find.text('spec.pdf'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
  });

  testWidgets('terminates the active run after confirming', (tester) async {
    serveRich();
    await pumpPanel(tester);

    await tester.ensureVisible(find.textContaining('Runs ('));
    await tester.tap(find.textContaining('Runs ('));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Terminate'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Terminate'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('POST', '/api/plugins/kanban/runs/7/terminate'),
      hasLength(1),
    );
    expect(changes, 1);
  });

  testWidgets('opens the worker log', (tester) async {
    serveRich();
    await pumpPanel(tester);

    await tester.ensureVisible(find.textContaining('Runs ('));
    await tester.tap(find.textContaining('Runs ('));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Worker log'));
    await tester.pumpAndSettle();

    expect(find.text('starting worker'), findsOneWidget);
  });

  testWidgets('removes an attachment after confirming', (tester) async {
    serveRich();
    await pumpPanel(tester);

    await tester.ensureVisible(find.byTooltip('Remove attachment'));
    await tester.tap(find.byTooltip('Remove attachment'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('DELETE', '/api/plugins/kanban/attachments/3'),
      hasLength(1),
    );
  });

  testWidgets('deleting a task does not fetch it again', (tester) async {
    server.on('DELETE', '/api/plugins/kanban/tasks/t1', {'ok': true});
    await pumpPanel(tester);
    final loads = server
        .requestsTo('GET', '/api/plugins/kanban/tasks/t1')
        .length;

    await tester.ensureVisible(find.text('Delete'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('DELETE', '/api/plugins/kanban/tasks/t1'),
      hasLength(1),
    );
    expect(
      server.requestsTo('GET', '/api/plugins/kanban/tasks/t1'),
      hasLength(loads),
    );
  });

  testWidgets(
    'offers no Terminate for a run left open on a task that is not running',
    (tester) async {
      server.on(
        'GET',
        '/api/plugins/kanban/tasks/t1',
        kanbanTaskDetailBody(
          kanbanTaskRow(id: 't1', title: 'Stalled', status: 'blocked'),
          runs: [
            {
              'id': 7,
              'status': 'crashed',
              'profile': 'coder',
              'started_at': 1780000000,
            },
          ],
        ),
      );
      await pumpPanel(tester);

      await tester.ensureVisible(find.textContaining('Runs ('));
      await tester.tap(find.textContaining('Runs ('));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextButton, 'Terminate'), findsNothing);
    },
  );
}
