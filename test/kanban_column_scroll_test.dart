import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stream_channel/stream_channel.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';

/// Running cards animate forever, so pumpAndSettle never returns.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  // A filter restarts the board; closing its event stream completes outside
  // the fake clock, so give it a real turn.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  late FakeHermesServer server;

  Map<String, dynamic> lastBoardQuery() => server
      .requestsTo('GET', '/api/plugins/kanban/board')
      .last
      .queryParameters;

  var shellGeneration = 0;

  setUp(() {
    shellGeneration = 0;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/plugins/kanban/boards',
        kanbanBoardsBody([
          (slug: 'default', name: 'Default', total: 24, current: true),
          (slug: 'ops', name: 'Ops', total: 24, current: false),
        ]),
      )
      ..on(
        'GET',
        '/api/plugins/kanban/board',
        kanbanBoardBody(
          [
            for (var i = 0; i < 12; i++) ...[
              kanbanTaskRow(
                id: 'r$i',
                title: 'Running job $i',
                status: 'running',
                assignee: 'coder',
              ),
              kanbanTaskRow(
                id: 't$i',
                title: 'Todo job $i',
                status: 'todo',
                assignee: 'coder',
              ),
            ],
          ],
          tenants: ['acme'],
        ),
      );
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(),
        child: MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.android),
          // A new key is a new owner: the shell and the board below it are
          // rebuilt, but the route's PageStorage stays.
          home: KeyedSubtree(
            key: ValueKey(shellGeneration),
            child: ShellMenu(
              onOpen: () {},
              child: KanbanScreen(
                repository: KanbanRepository(server.client()),
                connect: ({required since, board}) async =>
                    StreamChannelController<String>().foreign,
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> showChip(WidgetTester tester, String label) async {
    final chip = find.text(label);
    await tester.ensureVisible(chip);
    await settle(tester);
    await tester.tap(chip);
    await settle(tester);
  }

  ScrollableState list(WidgetTester tester, String firstCard) =>
      tester.state<ScrollableState>(
        find
            .ancestor(
              of: find.text(firstCard),
              matching: find.byType(Scrollable),
            )
            .first,
      );

  /// Opens Running on a phone and scrolls it to the bottom.
  Future<void> openRunningAtBottom(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpShell(tester);
    await showChip(tester, 'Running 12');
    final running = list(tester, 'Running job 0');
    running.position.jumpTo(running.position.maxScrollExtent);
    await settle(tester);
    expect(find.text('Running job 0'), findsNothing);
  }

  void expectAtTop(WidgetTester tester) {
    expect(list(tester, 'Running job 0').position.pixels, 0);
  }

  testWidgets('each status chip on a phone keeps its own scroll position', (
    tester,
  ) async {
    await openRunningAtBottom(tester);

    await showChip(tester, 'Todo 12');
    expect(list(tester, 'Todo job 0').position.pixels, 0);

    await showChip(tester, 'Running 12');
    expect(find.text('Running job 11'), findsOneWidget);
    expect(find.text('Running job 0'), findsNothing);
  });

  testWidgets('a search puts the column back at its top', (tester) async {
    await openRunningAtBottom(tester);

    await tester.enterText(find.byType(TextField), 'Running');
    await settle(tester);

    expectAtTop(tester);
  });

  testWidgets('switching board puts the column back at its top', (
    tester,
  ) async {
    await openRunningAtBottom(tester);

    await tester.tap(find.byTooltip('Switch board'));
    await settle(tester);
    await tester.tap(find.text('Ops (24)'));
    await settle(tester);
    expect(lastBoardQuery()['board'], 'ops');
    await showChip(tester, 'Running 12');

    expectAtTop(tester);
  });

  testWidgets('a rebuilt shell starts its columns at the top', (tester) async {
    await openRunningAtBottom(tester);

    shellGeneration++;
    await pumpShell(tester);
    await showChip(tester, 'Running 12');

    expectAtTop(tester);
  });

  Future<void> toggleArchived(WidgetTester tester) async {
    final chip = find.widgetWithText(FilterChip, 'Archived');
    await tester.ensureVisible(chip);
    await settle(tester);
    await tester.tap(chip);
    await settle(tester);
  }

  Future<void> pickFrom(WidgetTester tester, String menu, String option) async {
    await tester.tap(find.widgetWithText(Chip, menu));
    await settle(tester);
    await tester.tap(find.text(option).last);
    await settle(tester);
  }

  testWidgets('picking a tenant puts the column back at its top', (
    tester,
  ) async {
    await openRunningAtBottom(tester);

    await pickFrom(tester, 'All tenants', 'acme');
    expect(lastBoardQuery()['tenant'], 'acme');
    await showChip(tester, 'Running 12');

    expectAtTop(tester);
  });

  testWidgets('picking an assignee puts the column back at its top', (
    tester,
  ) async {
    await openRunningAtBottom(tester);

    await pickFrom(tester, 'All assignees', 'coder');
    await showChip(tester, 'Running 12');

    expectAtTop(tester);
  });

  testWidgets('the archived switch puts the column back at its top', (
    tester,
  ) async {
    await openRunningAtBottom(tester);

    await toggleArchived(tester);
    expect(lastBoardQuery()['include_archived'], true);
    await showChip(tester, 'Running 12');

    expectAtTop(tester);
  });

  testWidgets('undoing a search does not bring the old offset back', (
    tester,
  ) async {
    await openRunningAtBottom(tester);

    await tester.enterText(find.byType(TextField), 'Running');
    await settle(tester);
    await tester.enterText(find.byType(TextField), '');
    await settle(tester);

    expectAtTop(tester);
  });

  testWidgets('turning archived on and off does not bring the offset back', (
    tester,
  ) async {
    await openRunningAtBottom(tester);

    await toggleArchived(tester);
    await toggleArchived(tester);
    await showChip(tester, 'Running 12');

    expectAtTop(tester);
  });

  testWidgets('going back to a board before it has loaded does not restore '
      'the old offset', (tester) async {
    await openRunningAtBottom(tester);
    final held = Completer<FakeResponse>();
    server.onRequest(
      'GET',
      '/api/plugins/kanban/board',
      (_) => held.future,
      query: {'board': 'ops'},
    );

    await tester.tap(find.byTooltip('Switch board'));
    await settle(tester);
    await tester.tap(find.text('Ops (24)'));
    await settle(tester);
    expect(lastBoardQuery()['board'], 'ops');
    expect(find.text('Running job 0'), findsNothing);

    await tester.tap(find.byTooltip('Switch board'));
    await settle(tester);
    await tester.tap(find.text('Default (24)'));
    await settle(tester);
    await showChip(tester, 'Running 12');

    expectAtTop(tester);
    held.complete((status: 200, body: kanbanBoardBody([])));
    await settle(tester);
  });

  testWidgets('a board that vanished from the list reopens at the top', (
    tester,
  ) async {
    await openRunningAtBottom(tester);
    // The shown board is gone from the server's list once a board is made
    // under Manage boards; the controller falls back to the current one.
    server
      ..on(
        'GET',
        '/api/plugins/kanban/boards',
        kanbanBoardsBody([
          (slug: 'ops', name: 'Ops', total: 24, current: true),
        ]),
      )
      ..on('POST', '/api/plugins/kanban/boards', {'board': {}});

    await tester.tap(find.byTooltip('Switch board'));
    await settle(tester);
    await tester.tap(find.text('Manage boards…'));
    await settle(tester);
    await tester.tap(find.byTooltip('New board'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Extra');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await settle(tester);
    expect(lastBoardQuery()['board'], 'ops');
    await tester.pageBack();
    await settle(tester);
    await showChip(tester, 'Running 12');

    expectAtTop(tester);
  });
}
