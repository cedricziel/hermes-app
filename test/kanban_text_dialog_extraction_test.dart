import 'package:material_ui/material_ui.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/kanban/kanban_board_controller.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/adaptive_dialog.dart';
import 'package:hermes_app/src/widgets/grouped_dialog.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';
import 'package:stream_channel/stream_channel.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';
import 'support/test_localizations.dart';
import 'support/tooltip_finder.dart';

/// What a user sees and can do in the Kanban text prompt (new board, rename
/// board, the task panel's Block and Complete prompts) and the task edit
/// dialog, both built from their own widgets. Each case drives the real
/// screen and asserts the app's own output: texts, the actions' semantics,
/// whether confirm is enabled, what the dialog answers, the macOS barrier and
/// the field's line limits. Nothing reads a framework widget's private state.

Widget _app(
  Widget home, {
  Locale locale = const Locale('en'),
  TargetPlatform platform = TargetPlatform.android,
}) => MaterialApp(
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: locale,
  builder: (_, child) => AppThemeScopes(child: child!),
  theme: buildHermesLightTheme(platform: platform),
  home: home,
);

List<String> _texts(WidgetTester tester, Finder within) => [
  for (final w in tester.widgetList<Text>(
    find.descendant(of: within, matching: find.byType(Text)),
  ))
    w.data ?? w.textSpan?.toPlainText() ?? '',
];

/// Label, button flag, tap action, enabled flag and default flag of the action
/// whose text is [label] inside [within].
String _action(WidgetTester tester, Finder within, String label) {
  final finder = find.descendant(
    of: within,
    matching: find.widgetWithText(AppDialogAction, label),
  );
  final node = tester.getSemantics(finder);
  final data = node.getSemanticsData();
  final action = tester.widget<AppDialogAction>(finder);
  return '${node.label}|button=${data.flagsCollection.isButton}'
      '|tap=${data.hasAction(SemanticsAction.tap)}'
      '|enabled=${action.onPressed != null}|default=${action.isDefault}';
}

void main() {
  late FakeHermesServer server;
  late KanbanBoardController controller;

  setUp(() async {
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/plugins/kanban/boards',
        kanbanBoardsBody([
          (slug: 'default', name: 'Default', total: 3, current: true),
          (slug: 'ops', name: 'Ops', total: 1, current: false),
        ]),
      )
      ..on('GET', '/api/plugins/kanban/board', kanbanBoardBody([]))
      ..on('POST', '/api/plugins/kanban/boards', {'board': {}})
      ..on('PATCH', '/api/plugins/kanban/boards/ops', {'board': {}})
      ..on(
        'GET',
        '/api/plugins/kanban/tasks/t1',
        kanbanTaskDetailBody(
          kanbanTaskRow(id: 't1', title: 'Migrate webhooks', status: 'running')
            ..['body'] = 'Move to v2 signing',
        ),
      )
      ..on('PATCH', '/api/plugins/kanban/tasks/t1', {'ok': true});
    controller = KanbanBoardController(
      repository: KanbanRepository(server.client()),
      connect: ({required since, board}) async =>
          StreamChannelController<String>().foreign,
    );
    await controller.start();
  });

  tearDown(() => controller.dispose());

  Future<void> openBoards(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    await tester.pumpWidget(
      _app(
        locale: locale,
        platform: platform,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => KanbanBoardsScreen(
                    controller: controller,
                    repository: KanbanRepository(server.client()),
                  ),
                ),
              ),
              child: const Text('open boards'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open boards'));
    await tester.pumpAndSettle();
  }

  Future<void> openPanel(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(
        locale: locale,
        platform: platform,
        Scaffold(
          body: KanbanTaskPanel(
            repository: KanbanRepository(server.client()),
            taskId: 't1',
            board: 'ops',
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openNewBoard(WidgetTester tester) async {
    await tester.tap(find.tooltip('New board'));
    await tester.pumpAndSettle();
  }

  Future<void> openRename(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<RowAction>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
  }

  /// The dialog's own field; the task panel has a comment field of its own.
  Finder dialogField() => find.descendant(
    of: find.byType(AppAlertDialog),
    matching: find.byType(TextField),
  );

  int patches(String path) => server.requestsTo('PATCH', path).length;

  group('askKanbanText', () {
    testWidgets('new board shows its title, hint and actions', (tester) async {
      final handle = tester.ensureSemantics();
      await openBoards(tester);
      await openNewBoard(tester);

      final dialog = find.byType(AppAlertDialog);
      expect(_texts(tester, dialog), ['New board', 'Name', 'Cancel', 'Create']);
      expect(find.widgetWithText(TextField, 'Name'), findsOneWidget);
      expect(
        _action(tester, dialog, 'Cancel'),
        'Cancel|button=true|tap=true|enabled=true|default=false',
      );
      expect(
        _action(tester, dialog, 'Create'),
        'Create|button=true|tap=true|enabled=true|default=true',
      );
      handle.dispose();
    });

    testWidgets('the same dialog speaks German', (tester) async {
      await openBoards(tester, locale: const Locale('de'));
      await tester.tap(find.tooltip('New board'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppDialogAction, 'Abbrechen'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('rename starts from the current name and trims the answer', (
      tester,
    ) async {
      await openBoards(tester);
      await openRename(tester);

      expect(_texts(tester, find.byType(AppAlertDialog)), [
        'Rename board',
        'Cancel',
        'Rename',
      ]);
      expect(find.widgetWithText(TextField, 'Ops'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Ops team  ');
      await tester.tap(find.widgetWithText(AppDialogAction, 'Rename'));
      await tester.pumpAndSettle();

      final body = jsonBody(
        server.requestsTo('PATCH', '/api/plugins/kanban/boards/ops').single,
      ) as Map;
      expect(body['name'], 'Ops team');
      expect(find.byType(AppAlertDialog), findsNothing);
    });

    testWidgets('Create stays enabled on an empty field and sends nothing', (
      tester,
    ) async {
      await openBoards(tester);
      await openNewBoard(tester);
      expect(
        tester
            .widget<AppDialogAction>(
              find.widgetWithText(AppDialogAction, 'Create'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.widgetWithText(AppDialogAction, 'Create'));
      await tester.pumpAndSettle();

      expect(find.byType(AppAlertDialog), findsNothing);
      expect(server.requestsTo('POST', '/api/plugins/kanban/boards'), isEmpty);
    });

    testWidgets('Cancel answers null: Block sends nothing', (tester) async {
      await openPanel(tester);
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(_texts(tester, find.byType(AppAlertDialog)), [
        'Why is it blocked?',
        'Optional',
        'Cancel',
        'Block',
      ]);
      await tester.tap(find.widgetWithText(AppDialogAction, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(AppAlertDialog), findsNothing);
      expect(patches('/api/plugins/kanban/tasks/t1'), 0);
    });

    testWidgets('Complete asks in a multiline field and trims the result', (
      tester,
    ) async {
      await openPanel(tester);
      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(dialogField());
      expect(field.minLines, 3);
      expect(field.maxLines, 6);

      await tester.enterText(dialogField(), '  shipped\nall of it  ');
      await tester.tap(find.widgetWithText(AppDialogAction, 'Complete'));
      await tester.pumpAndSettle();

      final body = jsonBody(
        server.requestsTo('PATCH', '/api/plugins/kanban/tasks/t1').single,
      ) as Map;
      expect(body['status'], 'done');
      expect(body['result'], 'shipped\nall of it');
    });

    testWidgets('a single-line prompt allows one line', (tester) async {
      await openBoards(tester);
      await openNewBoard(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 1);
      expect(field.maxLines, 1);
    });
  });

  group('KanbanTaskEditDialog', () {
    Future<void> openEdit(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await openPanel(tester, locale: locale);
      await tester.tap(find.tooltip('Edit'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the task and its actions', (tester) async {
      await openEdit(tester);

      expect(find.byType(GroupedDialog), findsOneWidget);
      expect(find.text('Edit task'), findsOneWidget);
      final fields = find.descendant(
        of: find.byType(GroupedDialog),
        matching: find.byType(TextField),
      );
      expect(
        [
          for (final f in tester.widgetList<TextField>(fields))
            f.controller?.text,
        ],
        ['Migrate webhooks', 'Move to v2 signing'],
      );
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('speaks German', (tester) async {
      await openEdit(tester, locale: const Locale('de'));

      expect(find.text('Aufgabe bearbeiten'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Abbrechen'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Speichern'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('Cancel sends nothing', (tester) async {
      await openEdit(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Other');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(GroupedDialog), findsNothing);
      expect(patches('/api/plugins/kanban/tasks/t1'), 0);
    });
  });
}
