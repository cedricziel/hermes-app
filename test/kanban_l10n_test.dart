import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/kanban/kanban_board_controller.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_workers_screen.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:stream_channel/stream_channel.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';
import 'support/test_localizations.dart';
import 'support/tooltip_finder.dart';

Widget _german(Widget home) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: buildHermesLightTheme(),
  home: home,
);

void main() {
  late FakeHermesServer server;

  setUp(() => server = FakeHermesServer());

  group('boards screen', () {
    late KanbanBoardController controller;

    setUp(() async {
      server
        ..on(
          'GET',
          '/api/plugins/kanban/boards',
          kanbanBoardsBody([
            (slug: 'default', name: 'Default', total: 3, current: true),
            (slug: 'ops', name: 'Ops', total: 1, current: false),
          ]),
        )
        ..on('GET', '/api/plugins/kanban/board', kanbanBoardBody([]));
      controller = KanbanBoardController(
        repository: KanbanRepository(server.client()),
        connect: ({required since, board}) async =>
            StreamChannelController<String>().foreign,
      );
      await controller.start();
    });

    tearDown(() => controller.dispose());

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _german(
          KanbanBoardsScreen(
            controller: controller,
            repository: KanbanRepository(server.client()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(pumpEventQueue);
      await tester.pumpAndSettle();
    }

    Future<void> openMenu(WidgetTester tester, String item) async {
      await tester.tap(find.byType(PopupMenuButton<RowAction>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    testWidgets('the page, its rows and the new-board prompt are German', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('2 Boards'), findsOneWidget);
      expect(find.text('default · 3 Aufgaben'), findsOneWidget);
      expect(find.text('ops · 1 Aufgabe'), findsOneWidget);
      expect(find.text('Aktuell'), findsOneWidget);
      expect(find.text('Current'), findsNothing);
      expect(find.text('3 tasks'), findsNothing);
      expect(find.tooltip('Board importieren'), findsOneWidget);
      expect(find.tooltip('Import a board'), findsNothing);

      await tester.tap(find.tooltip('Neues Board'));
      await tester.pumpAndSettle();
      expect(find.text('Neues Board'), findsOneWidget);
      expect(find.text('Erstellen'), findsOneWidget);
      expect(find.text('New board'), findsNothing);
      expect(find.text('Create'), findsNothing);
    });

    testWidgets('the row menu and the rename prompt are German', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byType(PopupMenuButton<RowAction>).first);
      await tester.pumpAndSettle();

      expect(find.text('Umbenennen'), findsOneWidget);
      expect(find.text('Exportieren…'), findsOneWidget);
      expect(find.text('Archivieren'), findsOneWidget);
      expect(find.text('Löschen'), findsOneWidget);
      expect(find.text('Rename'), findsNothing);
      expect(find.text('Export…'), findsNothing);

      await tester.tap(find.text('Umbenennen'));
      await tester.pumpAndSettle();
      expect(find.text('Board umbenennen'), findsOneWidget);
      expect(find.text('Rename board'), findsNothing);
    });

    testWidgets('the archive question is German', (tester) async {
      await pump(tester);
      await openMenu(tester, 'Archivieren');

      expect(find.text('„Default“ archivieren?'), findsOneWidget);
      expect(find.text('Archive “Default”?'), findsNothing);
    });
  });

  group('a worker row', () {
    testWidgets('its caption and menu are German', (tester) async {
      server.on('GET', '/api/plugins/kanban/workers/active', {
        'workers': [
          {
            'run_id': 7,
            'task_id': 't1',
            'task_title': 'Migrate webhooks',
            'profile': 'coder',
            'worker_pid': 4242,
            'started_at': 1780000000,
          },
        ],
      });
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _german(
          KanbanWorkersScreen(
            repository: KanbanRepository(server.client()),
            board: 'ops',
            onChanged: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('t1 · Lauf #7 · coder'), findsOneWidget);
      expect(find.textContaining('gestartet'), findsOneWidget);
      expect(find.textContaining('started'), findsNothing);

      await tester.tap(find.byType(PopupMenuButton<RowAction>));
      await tester.pumpAndSettle();
      expect(find.text('Prozess untersuchen'), findsOneWidget);
      expect(find.text('Beenden'), findsOneWidget);
      expect(find.text('Inspect process'), findsNothing);
      expect(find.text('Terminate'), findsNothing);
    });
  });

  group('task panel', () {
    setUp(() {
      server
        ..on(
          'GET',
          '/api/plugins/kanban/tasks/t1',
          kanbanTaskDetailBody(
            kanbanTaskRow(
              id: 't1',
              title: 'Migrate webhooks',
              status: 'running',
              priority: 2,
            )..['body'] = 'Move to v2 signing',
            comments: [
              {
                'author': 'coder',
                'body': 'Endpoint 1 done',
                'created_at': 1780000000,
              },
            ],
            parents: ['t0'],
            attachments: [
              {'id': 1, 'filename': 'notes.txt', 'size': 12},
            ],
            runs: [
              {'id': 3, 'status': 'running', 'started_at': 1780000000},
            ],
          ),
        )
        ..on('GET', '/api/plugins/kanban/assignees', {
          'assignees': ['coder'],
        });
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _german(
          Scaffold(
            body: KanbanTaskPanel(
              repository: KanbanRepository(server.client()),
              taskId: 't1',
              board: 'ops',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('its sections, rows and buttons are German', (tester) async {
      await pump(tester);

      for (final text in [
        'Aktionen',
        'Zurückholen',
        'Abschließen',
        'Blockieren',
        'Schätzen',
        'Zuständig',
        'Nicht zugewiesen',
        'Kommentare (1)',
        'Kommentar hinzufügen…',
        'Senden',
        'Anhänge',
        'Datei anhängen',
        'Hängt ab von',
        'Hinzufügen',
        'Modell',
        'Läufe (1)',
        'Archivieren',
        'Löschen',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      for (final text in [
        'Actions',
        'Reclaim',
        'Complete',
        'Block',
        'Estimate',
        'Unassigned',
        'Comments (1)',
        'Attachments',
        'Attach file',
        'Depends on',
        'Add',
        'Model',
        'Runs (1)',
        'Archive',
        'Delete',
      ]) {
        expect(find.text(text), findsNothing, reason: text);
      }
      expect(find.tooltip('Bearbeiten'), findsOneWidget);
      expect(find.tooltip('Anhang speichern'), findsOneWidget);
      expect(find.tooltip('Anhang entfernen'), findsOneWidget);
    });

    testWidgets('the prompts and questions are German', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Blockieren'));
      await tester.pumpAndSettle();
      expect(find.text('Warum ist sie blockiert?'), findsOneWidget);
      expect(find.text('Why is it blocked?'), findsNothing);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Zurückholen'));
      await tester.pumpAndSettle();
      expect(
        find.text('Den Anspruch des Workers auf diese Aufgabe aufheben?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();

      await tester.tap(find.tooltip('Anhang entfernen'));
      await tester.pumpAndSettle();
      expect(find.text('notes.txt entfernen?'), findsOneWidget);
    });
  });
}
