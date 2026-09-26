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
                    repository: KanbanRepository(server.client()),
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

  testWidgets('sizes up a draft before it is created', (tester) async {
    server.on('POST', '/api/plugins/kanban/estimate', {
      'ok': true,
      'est_tokens': 4000,
      'complexity': 'S',
    });
    await pump(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Fix typo');
    await tester.pump();
    await tester.tap(find.text('Estimate the work'));
    await tester.pumpAndSettle();

    expect(find.text('about 4k tokens · small'), findsOneWidget);
    expect(
      jsonBody(
        server.requestsTo('POST', '/api/plugins/kanban/estimate').single,
      ),
      containsPair('title', 'Fix typo'),
    );
  });

  testWidgets('will not estimate a draft without a title', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Estimate the work'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(server.requestsTo('POST', '/api/plugins/kanban/estimate'), isEmpty);
  });

  group('model', () {
    Map<dynamic, dynamic> sentBody() =>
        jsonBody(server.requestsTo('POST', '/api/plugins/kanban/tasks').single)
            as Map;

    setUp(() {
      server.on('GET', '/api/plugins/kanban/model-options', {
        'providers': [
          {
            'slug': 'anthropic',
            'label': 'Anthropic',
            'models': ['claude-opus-4', 'claude-haiku-4-5'],
          },
        ],
      });
    });

    Future<void> openPicker(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Profile default'));
      await tester.tap(find.text('Profile default'));
      await tester.pumpAndSettle();
    }

    Future<void> create(WidgetTester tester) async {
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Task');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
    }

    testWidgets('sends the picked model, provider and effort', (tester) async {
      await pump(tester);

      await openPicker(tester);
      await tester.tap(find.byKey(const Key('model-anthropic-claude-opus-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('effort-high')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await create(tester);

      expect(sentBody(), containsPair('model_override', 'claude-opus-4'));
      expect(sentBody(), containsPair('provider_override', 'anthropic'));
      expect(sentBody(), containsPair('reasoning_effort', 'high'));
    });

    testWidgets('sends no model after going back to the default', (
      tester,
    ) async {
      await pump(tester);

      await openPicker(tester);
      await tester.tap(find.byKey(const Key('model-anthropic-claude-opus-4')));
      await tester.pumpAndSettle();
      // The default entry closes the picker by itself.
      await tester.tap(find.byKey(const Key('model-default')));
      await tester.pumpAndSettle();
      await create(tester);

      for (final key in [
        'model_override',
        'provider_override',
        'reasoning_effort',
      ]) {
        expect(sentBody().containsKey(key), isFalse, reason: key);
      }
    });

    testWidgets('takes a typed model name when none are listed', (
      tester,
    ) async {
      server.on('GET', '/api/plugins/kanban/model-options', {'providers': []});
      await pump(tester);

      expect(find.text('Profile default'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Model'), 'gpt-5');
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Task');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(sentBody(), containsPair('model_override', 'gpt-5'));
      expect(sentBody().containsKey('provider_override'), isFalse);
    });
  });
}
