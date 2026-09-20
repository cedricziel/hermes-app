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
            repository: KanbanRepository(server.client()),
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

    await tester.ensureVisible(find.text('Todo 1'));
    await tester.pumpAndSettle();
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

  const notice = 'Could not refresh. Showing the last board.';

  testWidgets('says so when the plugin has been turned off', (tester) async {
    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 404);
    await pumpBoard(tester, size: const Size(400, 800));

    expect(find.text('Kanban isn’t available'), findsOneWidget);
  });

  testWidgets('says so when the plugin is turned off during a refresh', (
    tester,
  ) async {
    serveTasks();
    await pumpBoard(tester, size: const Size(1400, 900));

    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 404);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(find.text('Kanban isn’t available'), findsOneWidget);
    expect(find.text(notice), findsNothing);
    expect(find.text('Migrate webhooks'), findsNothing);
  });

  testWidgets('offers a retry when the board fails to load', (tester) async {
    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 500);
    await pumpBoard(tester, size: const Size(400, 800));

    serveTasks();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load the board'), findsNothing);
  });

  testWidgets('a failed refresh keeps the board and offers a retry', (
    tester,
  ) async {
    serveTasks();
    await pumpBoard(tester, size: const Size(1400, 900));
    expect(find.text(notice), findsNothing);

    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 500);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(find.text(notice), findsOneWidget);
    expect(find.text('Migrate webhooks'), findsOneWidget);

    serveTasks();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text(notice), findsNothing);
    expect(find.text('Migrate webhooks'), findsOneWidget);
  });

  testWidgets('a failed pull-to-refresh on a phone shows the notice', (
    tester,
  ) async {
    serveTasks();
    await pumpBoard(tester, size: const Size(400, 800));

    server.on('GET', '/api/plugins/kanban/board', {'detail': 'x'}, status: 500);
    await tester.fling(
      find.text('Migrate webhooks'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text(notice), findsOneWidget);
    expect(find.text('Migrate webhooks'), findsOneWidget);
  });

  testWidgets('a wide screen has a refresh button that refetches', (
    tester,
  ) async {
    serveTasks();
    await pumpBoard(tester, size: const Size(1400, 900));
    final before = server.requestsTo('GET', '/api/plugins/kanban/board').length;

    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('GET', '/api/plugins/kanban/board').length,
      before + 1,
    );
  });

  testWidgets('a phone has no refresh button, only pull-to-refresh', (
    tester,
  ) async {
    serveTasks();
    await pumpBoard(tester, size: const Size(400, 800));

    expect(find.byTooltip('Refresh'), findsNothing);
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

  testWidgets('long-pressing a card selects it and archives the selection', (
    tester,
  ) async {
    serveTasks();
    server.on('POST', '/api/plugins/kanban/tasks/bulk', {
      'results': [
        {'id': 't_run', 'ok': true},
      ],
    });
    await pumpBoard(tester, size: const Size(400, 800));

    await tester.longPress(find.text('Migrate webhooks'));
    await tester.pumpAndSettle();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    final body = jsonBody(
      server.requestsTo('POST', '/api/plugins/kanban/tasks/bulk').single,
    ) as Map;
    expect(body['ids'], ['t_run']);
    expect(body['archive'], true);
    expect(find.text('1 selected'), findsNothing);
  });

  testWidgets('tapping cards in selection mode picks them instead of opening', (
    tester,
  ) async {
    serveTasks();
    await pumpBoard(tester, size: const Size(1400, 900));

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Migrate webhooks'));
    await tester.tap(find.text('Write docs'));
    await tester.pumpAndSettle();

    expect(find.text('2 selected'), findsOneWidget);
    expect(
      server.requestsTo('GET', '/api/plugins/kanban/tasks/t_run'),
      isEmpty,
    );
  });

  testWidgets('tells which tasks a bulk change could not apply to', (
    tester,
  ) async {
    serveTasks();
    server.on('POST', '/api/plugins/kanban/tasks/bulk', {
      'results': [
        {'id': 't_run', 'ok': false, 'error': 'archive refused'},
      ],
    });
    await pumpBoard(tester, size: const Size(400, 800));

    await tester.longPress(find.text('Migrate webhooks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(find.textContaining('archive refused'), findsOneWidget);
  });

  testWidgets('runs the dispatcher from the menu', (tester) async {
    serveTasks();
    server.on('POST', '/api/plugins/kanban/dispatch', {'spawned': []});
    await pumpBoard(tester, size: const Size(400, 800));

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Run dispatcher now'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('POST', '/api/plugins/kanban/dispatch'),
      hasLength(1),
    );
    expect(find.text('Dispatcher nudged'), findsOneWidget);
  });

  testWidgets('edits the orchestration settings from the menu', (tester) async {
    serveTasks();
    server
      ..on('GET', '/api/plugins/kanban/orchestration', {
        'orchestrator_profile': '',
        'default_assignee': '',
        'auto_decompose': true,
        'auto_promote_children': true,
        'active_profile': 'default',
      })
      ..on('GET', '/api/plugins/kanban/assignees', {
        'assignees': ['coder'],
      })
      ..on('PUT', '/api/plugins/kanban/orchestration', {
        'auto_decompose': false,
        'active_profile': 'default',
      });
    await pumpBoard(tester, size: const Size(400, 800));

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orchestration…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auto-decompose triage tasks'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final body = jsonBody(
      server.requestsTo('PUT', '/api/plugins/kanban/orchestration').single,
    ) as Map;
    expect(body['auto_decompose'], false);
    expect(body.keys, isNot(contains('auto_promote_children')));
    expect(body.keys, isNot(contains('orchestrator_profile')));
  });

  testWidgets('keeps the tasks a bulk change refused selected for a retry', (
    tester,
  ) async {
    server.on(
      'GET',
      '/api/plugins/kanban/board',
      kanbanBoardBody([
        kanbanTaskRow(id: 't_a', title: 'Alpha', status: 'running'),
        kanbanTaskRow(id: 't_b', title: 'Beta', status: 'running'),
      ]),
    );
    server.on('POST', '/api/plugins/kanban/tasks/bulk', {
      'results': [
        {'id': 't_a', 'ok': true},
        {'id': 't_b', 'ok': false, 'error': 'archive refused'},
      ],
    });
    await pumpBoard(tester, size: const Size(400, 800));

    await tester.longPress(find.text('Alpha'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('a phone scrolls the selected status chip into view', (
    tester,
  ) async {
    serveTasks();
    await pumpBoard(tester, size: const Size(400, 800));

    final chip = tester.getRect(find.text('Running 1'));

    expect(chip.left, greaterThanOrEqualTo(0));
    expect(chip.right, lessThanOrEqualTo(400));
  });

  testWidgets('a refusal that names no task keeps the whole selection', (
    tester,
  ) async {
    serveTasks();
    server.on('POST', '/api/plugins/kanban/tasks/bulk', {
      'results': [
        {'ok': false, 'error': 'archive refused'},
      ],
    });
    await pumpBoard(tester, size: const Size(400, 800));

    await tester.longPress(find.text('Migrate webhooks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
  });

  testWidgets('opens the active workers from the menu', (tester) async {
    serveTasks();
    server.on('GET', '/api/plugins/kanban/workers/active', {'workers': []});
    await pumpBoard(tester, size: const Size(400, 800));

    await tester.tap(find.byType(PopupMenuButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active workers…'));
    await tester.pumpAndSettle();

    expect(find.text('No workers are running'), findsOneWidget);
  });
}
