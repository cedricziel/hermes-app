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
}
