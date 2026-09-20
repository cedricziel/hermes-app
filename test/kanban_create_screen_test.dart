import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/kanban/kanban_create_screen.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/plugins/kanban/assignees', {
        'assignees': ['coder'],
      })
      ..on('POST', '/api/plugins/kanban/tasks', {
        'task': {'id': 't9'},
      });
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => KanbanCreateScreen(
                    repository: KanbanRepository(server.client().raw),
                    tenant: 'acme',
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('creates a triage task from the title and priority', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Add dark mode',
    );
    await tester.tap(find.text('P2'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    final body = jsonBody(
      server.requestsTo('POST', '/api/plugins/kanban/tasks').single,
    ) as Map;
    expect(body['title'], 'Add dark mode');
    expect(body['priority'], 2);
    expect(body['triage'], true);
    expect(body['tenant'], 'acme');
    expect(find.text('New task'), findsNothing);
  });

  testWidgets('will not create a task without a title', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(server.requestsTo('POST', '/api/plugins/kanban/tasks'), isEmpty);
    expect(find.text('New task'), findsOneWidget);
  });

  testWidgets('stays open and says why when the plugin refuses', (
    tester,
  ) async {
    server.on('POST', '/api/plugins/kanban/tasks', {
      'detail': 'title too long',
    }, status: 400);
    await pump(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'x');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('title too long'), findsOneWidget);
    expect(find.text('New task'), findsOneWidget);
  });
}
