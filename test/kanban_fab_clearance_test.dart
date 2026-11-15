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

void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/plugins/kanban/boards', kanbanBoardsBody([]))
      ..on(
        'GET',
        '/api/plugins/kanban/board',
        kanbanBoardBody([
          for (var i = 0; i < 12; i++)
            kanbanTaskRow(id: 't$i', title: 'Chore number $i', status: 'done'),
        ]),
      );
  });

  Future<void> pump(
    WidgetTester tester, {
    required Size size,
    required TargetPlatform platform,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(),
        child: MaterialApp(
          theme: buildHermesLightTheme(platform: platform),
          home: ShellMenu(
            onOpen: () {},
            child: KanbanScreen(
              repository: KanbanRepository(server.client()),
              connect: ({required since, board}) async =>
                  StreamChannelController<String>().foreign,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Scrolls the board sideways until its last column is on screen.
  Future<void> showLastColumn(WidgetTester tester) async {
    final board = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .where((s) => s.widget.axis == Axis.horizontal)
        .reduce(
          (a, b) =>
              a.position.maxScrollExtent >= b.position.maxScrollExtent ? a : b,
        );
    board.position.jumpTo(board.position.maxScrollExtent);
    await tester.pumpAndSettle();
  }

  /// Scrolls the vertical list that holds the first card to its end.
  Future<void> scrollToEnd(WidgetTester tester) async {
    final scrollable = find.ancestor(
      of: find.text('Chore number 0'),
      matching: find.byType(Scrollable),
    );
    final state = tester.state<ScrollableState>(scrollable.first);
    state.position.jumpTo(state.position.maxScrollExtent);
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('a phone list ends clear of the New task button on $platform', (
      tester,
    ) async {
      await pump(tester, size: const Size(400, 800), platform: platform);
      await tester.ensureVisible(find.text('Done 12'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done 12'));
      await tester.pumpAndSettle();
      await scrollToEnd(tester);

      final fab = tester.getRect(find.byType(FloatingActionButton));
      final last = tester.getRect(find.text('Chore number 11'));
      expect(last.overlaps(fab), isFalse);
      final card = find.ancestor(
        of: find.text('Chore number 11'),
        matching: find.byType(Card),
      );
      if (card.evaluate().isNotEmpty) {
        expect(tester.getRect(card.first).overlaps(fab), isFalse);
      }
    });
  }

  testWidgets('a wide column ends clear of the New task button on Windows', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(720, 700),
      platform: TargetPlatform.windows,
    );
    await showLastColumn(tester);
    await scrollToEnd(tester);

    final fab = tester.getRect(find.byType(FloatingActionButton));
    final last = tester.getRect(find.text('Chore number 11'));
    expect(last.overlaps(fab), isFalse);
  });

  testWidgets('the Mac has no button and keeps its columns flush', (
    tester,
  ) async {
    await pump(
      tester,
      size: const Size(400, 800),
      platform: TargetPlatform.macOS,
    );
    expect(find.byType(FloatingActionButton), findsNothing);
    await showLastColumn(tester);
    final list = tester.widget<ListView>(
      find
          .ancestor(
            of: find.text('Chore number 0'),
            matching: find.byType(ListView),
          )
          .first,
    );
    expect(list.padding, isNull);
  });
}
