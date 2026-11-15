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
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('each status chip on a phone keeps its own scroll position', (
    tester,
  ) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/plugins/kanban/boards', kanbanBoardsBody([]))
      ..on(
        'GET',
        '/api/plugins/kanban/board',
        kanbanBoardBody([
          for (var i = 0; i < 12; i++) ...[
            kanbanTaskRow(
              id: 'r$i',
              title: 'Running job $i',
              status: 'running',
            ),
            kanbanTaskRow(id: 't$i', title: 'Todo job $i', status: 'todo'),
          ],
        ]),
      );
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(),
        child: MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.android),
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
    await settle(tester);

    Future<void> showChip(String label) async {
      final chip = find.text(label);
      await tester.ensureVisible(chip);
      await settle(tester);
      await tester.tap(chip);
      await settle(tester);
    }

    ScrollableState list(String firstCard) => tester.state<ScrollableState>(
      find
          .ancestor(of: find.text(firstCard), matching: find.byType(Scrollable))
          .first,
    );

    await showChip('Running 12');
    final running = list('Running job 0');
    running.position.jumpTo(running.position.maxScrollExtent);
    await settle(tester);
    expect(find.text('Running job 11'), findsOneWidget);
    expect(find.text('Running job 0'), findsNothing);

    await showChip('Todo 12');
    expect(find.text('Todo job 0'), findsOneWidget);
    expect(list('Todo job 0').position.pixels, 0);

    await showChip('Running 12');
    expect(find.text('Running job 11'), findsOneWidget);
    expect(find.text('Running job 0'), findsNothing);
  });
}
