import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stream_channel/stream_channel.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';

const _board = '/api/plugins/kanban/board';

void main() {
  late FakeHermesServer server;
  late List<StreamChannelController<String>> sockets;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    sockets = [];
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/plugins/kanban/boards',
        kanbanBoardsBody([
          (slug: 'default', name: 'Default', total: 2, current: true),
          (slug: 'ops', name: 'Ops', total: 1, current: false),
        ]),
      )
      ..on(
        'GET',
        _board,
        kanbanBoardBody(
          [
            kanbanTaskRow(id: 't1', title: 'Fix login', assignee: 'coder'),
            kanbanTaskRow(id: 't2', title: 'Write docs', assignee: 'writer'),
          ],
          tenants: ['acme', 'globex'],
        ),
      );
  });

  Future<void> pumpBoard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(),
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: KanbanScreen(
            repository: KanbanRepository(server.client()),
            connect: ({required since, board}) async {
              final socket = StreamChannelController<String>();
              sockets.add(socket);
              return socket.foreign;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A filter restarts the board, and closing its event stream completes
  /// outside the test's fake clock, so give it a real turn first.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<void> pick(WidgetTester tester, String menu, String option) async {
    await tester.tap(find.text(menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await settle(tester);
  }

  Map<String, dynamic> lastBoardQuery() =>
      server.requestsTo('GET', _board).last.queryParameters;

  testWidgets('picking a tenant refetches the board for that tenant', (
    tester,
  ) async {
    await pumpBoard(tester);

    await pick(tester, 'All tenants', 'acme');

    expect(lastBoardQuery()['tenant'], 'acme');
    expect(find.widgetWithText(Chip, 'acme'), findsOneWidget);
  });

  testWidgets(
    'All tenants drops the tenant filter',
    skip: true, // https://github.com/cedricziel/hermes-app/issues/357
    (tester) async {
      await pumpBoard(tester);
      await pick(tester, 'All tenants', 'acme');

      await pick(tester, 'acme', 'All tenants');

      expect(lastBoardQuery().containsKey('tenant'), isFalse);
      expect(find.widgetWithText(Chip, 'All tenants'), findsOneWidget);
    },
  );

  testWidgets('a board without tenants has no tenant menu', (tester) async {
    server.on(
      'GET',
      _board,
      kanbanBoardBody([kanbanTaskRow(id: 't1', assignee: 'coder')]),
    );

    await pumpBoard(tester);

    expect(find.text('All tenants'), findsNothing);
    expect(find.text('All assignees'), findsOneWidget);
  });

  testWidgets('picking an assignee shows only their cards', (tester) async {
    await pumpBoard(tester);
    final fetches = server.requestsTo('GET', _board).length;

    await pick(tester, 'All assignees', 'writer');

    expect(find.text('Write docs'), findsOneWidget);
    expect(find.text('Fix login'), findsNothing);
    expect(server.requestsTo('GET', _board), hasLength(fetches));
  });

  testWidgets('the Archived chip refetches with archived tasks', (
    tester,
  ) async {
    await pumpBoard(tester);
    expect(lastBoardQuery()['include_archived'], isNot(true));

    await tester.tap(find.widgetWithText(FilterChip, 'Archived'));
    await settle(tester);

    expect(lastBoardQuery()['include_archived'], true);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Archived'))
          .selected,
      isTrue,
    );
  });

  testWidgets('the board menu marks the open board and switches to another', (
    tester,
  ) async {
    await pumpBoard(tester);

    await tester.tap(find.byTooltip('Switch board'));
    await tester.pumpAndSettle();
    final current = tester.widget<CheckedPopupMenuItem<String>>(
      find.widgetWithText(CheckedPopupMenuItem<String>, 'Default (2)'),
    );
    expect(current.checked, isTrue);

    await tester.tap(find.text('Ops (1)'));
    await settle(tester);

    expect(lastBoardQuery()['board'], 'ops');
  });

  testWidgets('Manage boards opens the boards screen', (tester) async {
    await pumpBoard(tester);

    await tester.tap(find.byTooltip('Switch board'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage boards…'));
    await tester.pumpAndSettle();

    expect(find.byType(KanbanBoardsScreen), findsOneWidget);
  });

  testWidgets('the live dot says whether the event stream is connected', (
    tester,
  ) async {
    await pumpBoard(tester);
    expect(find.byTooltip('Live'), findsOneWidget);

    await sockets.single.local.sink.close();
    await tester.pump();

    expect(find.byTooltip('Reconnecting…'), findsOneWidget);
  });

  testWidgets('the board reconnects a second after the stream drops', (
    tester,
  ) async {
    await pumpBoard(tester);
    await sockets.single.local.sink.close();
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 900));
    expect(sockets, hasLength(1));

    await tester.pump(const Duration(milliseconds: 100));
    expect(sockets, hasLength(2));
    expect(find.byTooltip('Live'), findsOneWidget);
  });
}
