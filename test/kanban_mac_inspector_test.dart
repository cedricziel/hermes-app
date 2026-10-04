import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/kanban_create_screen.dart';
import 'package:hermes_app/src/kanban/kanban_inspector.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_card.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_inspector_layout.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_mac_toolbar.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      ..on(
        'GET',
        '/api/plugins/kanban/boards',
        kanbanBoardsBody([
          (slug: 'default', name: 'Default', total: 2, current: true),
        ]),
      )
      ..on(
        'GET',
        '/api/plugins/kanban/board',
        kanbanBoardBody([
          kanbanTaskRow(
            id: 't_run',
            title: 'Migrate webhooks',
            status: 'running',
            assignee: 'coder',
            progress: {'done': 1, 'total': 2},
          ),
          kanbanTaskRow(id: 't_todo', title: 'Write docs', status: 'todo'),
        ]),
      )
      ..on(
        'GET',
        '/api/plugins/kanban/tasks/t_todo',
        kanbanTaskDetailBody(
          kanbanTaskRow(id: 't_todo', title: 'Write docs', status: 'todo')
            ..['body'] = 'Details here',
        ),
      )
      ..on('GET', '/api/plugins/kanban/assignees', {
        'assignees': ['coder'],
      })
      ..on('GET', '/api/plugins/kanban/model-options', {'providers': []});
  });

  Future<void> pumpBoard(
    WidgetTester tester, {
    Size size = const Size(1400, 900),
    TargetPlatform platform = TargetPlatform.macOS,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>(
        create: (_) => AuthController(),
        child: MaterialApp(
          theme: buildHermesLightTheme(platform: platform),
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

  final inspector = find.byKey(const Key('kanban-inspector'));
  final toggle = find.byKey(const Key('kanban-inspector-toggle'));

  bool cardSelected(WidgetTester tester, String title) => tester
      .widget<KanbanCard>(
        find.ancestor(of: find.text(title), matching: find.byType(KanbanCard)),
      )
      .selected;

  Future<void> chord(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool alt = false,
  }) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(key);
    if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
  }

  testWidgets('the Mac toolbar names the board, the filter and the count', (
    tester,
  ) async {
    await pumpBoard(tester);

    expect(find.text('Kanban'), findsOneWidget);
    expect(find.text('Default · all profiles · 2 tasks'), findsOneWidget);
    expect(find.byTooltip('New Task ⌘N'), findsOneWidget);
    expect(find.byTooltip('Hide Inspector ⌥⌘I'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(
      tester.getSize(find.byType(KanbanMacToolbar)).height,
      kMacToolbarHeight,
    );
  });

  testWidgets('the profile filter in the toolbar narrows the board', (
    tester,
  ) async {
    await pumpBoard(tester);
    expect(find.text('All assignees'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Filter by profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('coder').last);
    await tester.pumpAndSettle();

    expect(find.text('Default · coder · 1 task'), findsOneWidget);
    expect(find.text('Write docs'), findsNothing);
  });

  testWidgets('a card opens in the docked inspector and shows as selected', (
    tester,
  ) async {
    await pumpBoard(tester);
    expect(find.text('No task selected'), findsOneWidget);

    await tester.tap(find.text('Write docs'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Details here'), findsOneWidget);
    final panel = tester.getRect(inspector);
    expect(panel.width, kKanbanInspectorWidth);
    expect(panel.right, 1400);
    expect(
      find.descendant(of: inspector, matching: find.byType(KanbanTaskPanel)),
      findsOneWidget,
    );
    expect(cardSelected(tester, 'Write docs'), isTrue);
    expect(cardSelected(tester, 'Migrate webhooks'), isFalse);
  });

  testWidgets('the columns are 232 points wide, 12 apart, 16 from the edge', (
    tester,
  ) async {
    await pumpBoard(tester);

    final running = tester.getRect(
      find.ancestor(
        of: find.text('Migrate webhooks'),
        matching: find.byType(KanbanCard),
      ),
    );
    final todo = tester.getRect(
      find.ancestor(
        of: find.text('Write docs'),
        matching: find.byType(KanbanCard),
      ),
    );
    expect(todo.width, 232);
    expect((running.left - todo.left) % (232 + 12), 0);
  });

  testWidgets('the toggle hides and shows the inspector and is remembered', (
    tester,
  ) async {
    await pumpBoard(tester);
    await tester.tap(find.text('Write docs'));
    await tester.pumpAndSettle();

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(inspector, findsNothing);
    expect(cardSelected(tester, 'Write docs'), isFalse);
    expect(
      await SharedPreferencesAsync().getBool(kanbanInspectorShownKey),
      isFalse,
    );

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.text('Details here'), findsOneWidget);
  });

  testWidgets('a hidden inspector starts hidden and a card click shows it', (
    tester,
  ) async {
    await SharedPreferencesAsync().setBool(kanbanInspectorShownKey, false);
    await pumpBoard(tester);
    expect(inspector, findsNothing);

    await tester.tap(find.text('Write docs'));
    await tester.pumpAndSettle();

    expect(find.text('Details here'), findsOneWidget);
  });

  testWidgets('option-command-I shows and hides the inspector', (tester) async {
    await pumpBoard(tester);
    expect(inspector, findsOneWidget);

    await chord(tester, LogicalKeyboardKey.keyI, alt: true);
    expect(inspector, findsNothing);

    await chord(tester, LogicalKeyboardKey.keyI, alt: true);
    expect(inspector, findsOneWidget);
  });

  testWidgets('command-N opens the new task form', (tester) async {
    await pumpBoard(tester);

    await chord(tester, LogicalKeyboardKey.keyN);

    expect(find.byType(KanbanCreateScreen), findsOneWidget);
  });

  testWidgets('a compact window lays the inspector over the board', (
    tester,
  ) async {
    await pumpBoard(tester, size: const Size(700, 800));
    expect(inspector, findsNothing);
    final boardWidth = tester.getSize(find.byType(KanbanInspectorLayout)).width;

    await tester.tap(find.text('Write docs'));
    await tester.pumpAndSettle();

    final panel = tester.getRect(inspector);
    expect(panel.width, kKanbanInspectorWidth);
    expect(panel.right, 700);
    expect(panel.top, kMacToolbarHeight);
    final shadow =
        (tester.widget<Container>(inspector).decoration! as BoxDecoration)
            .boxShadow;
    expect(shadow, isNotEmpty);
    expect(
      tester.getSize(find.byType(KanbanInspectorLayout)).width,
      boardWidth,
    );
  });

  testWidgets('iOS keeps the form sheet', (tester) async {
    await pumpBoard(tester, platform: TargetPlatform.iOS);

    await tester.tap(find.text('Write docs'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(KanbanInspectorLayout), findsNothing);
  });
}
