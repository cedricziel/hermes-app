import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';

void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/plugins/kanban/boards', kanbanBoardsBody([]));
  });

  Future<void> pumpBoard(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(),
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: KanbanScreen(
            repository: KanbanRepository(server.client().raw),
            connect: ({required since, board}) async =>
                StreamChannelController<String>().foreign,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void serveTasks() => server.on(
    'GET',
    '/api/plugins/kanban/board',
    kanbanBoardBody([
      kanbanTaskRow(
        id: 't_run',
        title: 'Migrate webhooks',
        status: 'running',
        assignee: 'coder',
        priority: 2,
        commentCount: 4,
        progress: {'done': 2, 'total': 5},
      ),
      kanbanTaskRow(id: 't_todo', title: 'Write docs', status: 'todo'),
    ]),
  );

  testWidgets('a phone shows one status at a time behind chips', (
    tester,
  ) async {
    serveTasks();
    await pumpBoard(tester, size: const Size(400, 800));

    expect(find.text('Migrate webhooks'), findsOneWidget);
    expect(find.text('coder'), findsOneWidget);
    expect(find.text('P2'), findsOneWidget);
    expect(find.text('2/5'), findsOneWidget);
    expect(find.text('Write docs'), findsNothing);

    await tester.tap(find.text('Todo 1'));
    await tester.pumpAndSettle();

    expect(find.text('Write docs'), findsOneWidget);
    expect(find.text('Migrate webhooks'), findsNothing);
  });

  testWidgets('a wide screen shows the columns side by side', (tester) async {
    serveTasks();
    await pumpBoard(tester, size: const Size(1400, 900));

    expect(find.text('Migrate webhooks'), findsOneWidget);
    expect(find.text('Write docs'), findsOneWidget);
    expect(find.text('Running  1'), findsOneWidget);
  });

  testWidgets('search narrows the cards', (tester) async {
    serveTasks();
    await pumpBoard(tester, size: const Size(1400, 900));

    await tester.enterText(find.byType(TextField), 'docs');
    await tester.pumpAndSettle();

    expect(find.text('Write docs'), findsOneWidget);
    expect(find.text('Migrate webhooks'), findsNothing);
  });

  testWidgets('says so when the plugin has been turned off', (tester) async {
    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 404);
    await pumpBoard(tester, size: const Size(400, 800));

    expect(find.text('Kanban isn’t available'), findsOneWidget);
  });

  testWidgets('offers a retry when the board fails to load', (tester) async {
    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 500);
    await pumpBoard(tester, size: const Size(400, 800));

    serveTasks();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load the board'), findsNothing);
  });

  testWidgets('tapping a card opens its detail', (tester) async {
    serveTasks();
    server.on(
      'GET',
      '/api/plugins/kanban/tasks/t_run',
      kanbanTaskDetailBody(
        kanbanTaskRow(id: 't_run', title: 'Migrate webhooks', status: 'running')
          ..['body'] = 'Details here',
      ),
    );
    await pumpBoard(tester, size: const Size(400, 800));

    await tester.tap(find.text('Migrate webhooks'));
    await tester.pumpAndSettle();

    expect(find.text('Details here'), findsOneWidget);
  });

  testWidgets('dragging a card to another column moves it', (tester) async {
    serveTasks();
    server.on('PATCH', '/api/plugins/kanban/tasks/t_todo', {'ok': true});
    await pumpBoard(tester, size: const Size(1600, 900));

    final from = tester.getCenter(find.text('Write docs'));
    final to = tester.getCenter(find.text('Blocked  0'));
    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      jsonBody(
        server.requestsTo('PATCH', '/api/plugins/kanban/tasks/t_todo').single,
      ),
      containsPair('status', 'blocked'),
    );
  });

  testWidgets('New task opens the create form', (tester) async {
    serveTasks();
    server.on('GET', '/api/plugins/kanban/assignees', {'assignees': []});
    await pumpBoard(tester, size: const Size(400, 800));

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
  });
}
