import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/kanban_board_controller.dart';
import 'package:hermes_app/src/kanban/kanban_boards_screen.dart';
import 'package:hermes_app/src/kanban/kanban_create_screen.dart';
import 'package:hermes_app/src/kanban/kanban_errors.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/kanban/kanban_workers_screen.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_board_menu.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_log_dialog.dart';
import 'package:hermes_app/src/kanban/widgets/kanban_task_panel.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
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

    testWidgets('the export result shows its size with a German comma', (
      tester,
    ) async {
      server.on('POST', '/api/plugins/kanban/boards/default/export', {
        'board': 'default',
        'archive': '/srv/hermes/exports/default.tar.gz',
        // Over a thousand kilobytes: a comma, and no thousands separator.
        'size': 1299968,
      });
      await pump(tester);
      await openMenu(tester, 'Exportieren…');
      await tester.tap(find.widgetWithText(FilledButton, 'Exportieren'));
      await tester.pumpAndSettle();

      expect(find.text('Board exportiert'), findsOneWidget);
      expect(find.text('1269,5 KB'), findsOneWidget);
      expect(find.text('1269.5 KB'), findsNothing);
      expect(find.text('1.269,5 KB'), findsNothing);
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
      expect(
        find.textContaining(RegExp(r'^gestartet (vor|am|gestern|gerade)')),
        findsOneWidget,
      );
      expect(find.textContaining('ago'), findsNothing);
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

    for (final (action, endpoint, one, many) in [
      (
        'Zerlegen',
        'decompose',
        'In 1 Aufgabe zerlegt',
        'In 2 Aufgaben zerlegt',
      ),
      (
        'Spezifizieren',
        'specify',
        'In 1 Aufgabe spezifiziert',
        'In 2 Aufgaben spezifiziert',
      ),
    ]) {
      for (final (children, expected, other) in [
        (['t2'], one, many),
        (['t2', 't3'], many, one),
      ]) {
        testWidgets('$action with ${children.length} child task(s) is German', (
          tester,
        ) async {
          server
            ..on(
              'GET',
              '/api/plugins/kanban/tasks/t1',
              kanbanTaskDetailBody(
                kanbanTaskRow(id: 't1', title: 'Rough idea', status: 'triage'),
              ),
            )
            ..on('POST', '/api/plugins/kanban/tasks/t1/$endpoint', {
              'ok': true,
              'child_ids': children,
            });
          await pump(tester);
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          expect(find.text(expected), findsOneWidget);
          expect(find.text(other), findsNothing);
        });
      }
    }

    testWidgets('the estimate row shows its result in German', (tester) async {
      server.on('POST', '/api/plugins/kanban/tasks/t1/estimate', {
        'ok': true,
        'est_tokens': 13400,
        'complexity': 'M',
      });
      await pump(tester);
      await tester.tap(find.text('Schätzen'));
      await tester.pumpAndSettle();

      expect(find.text('etwa 13k Token · mittel'), findsOneWidget);
      expect(find.text('about 13k tokens · medium'), findsNothing);
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

  group('create screen', () {
    setUp(() {
      server
        ..on('GET', '/api/plugins/kanban/assignees', {
          'assignees': ['coder'],
        })
        ..on('GET', '/api/plugins/kanban/model-options', {'providers': []});
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _german(
          KanbanCreateScreen(repository: KanbanRepository(server.client())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('its form, sections and options are German', (tester) async {
      await pump(tester);

      for (final text in [
        'Neue Aufgabe',
        'Erstellen',
        'Titel',
        'Beschreibung',
        'Aufwand schätzen',
        'Zuweisung',
        'Zuständig',
        'Modell',
        'Lass das Modell leer, um den Profilstandard zu verwenden.',
        'Priorität',
        'Normal',
        'P1',
        'Beginnen als',
        'Triage',
        'To-do',
      ]) {
        expect(find.textContaining(text), findsWidgets, reason: text);
      }
      for (final text in [
        'New task',
        'Create',
        'Estimate the work',
        'Assignment',
        'Assignee',
        'Leave the model empty',
        'Priority',
        'Start as',
        'Todo',
      ]) {
        expect(find.textContaining(text), findsNothing, reason: text);
      }
    });

    testWidgets('the assignee menu names the automatic choice in German', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Automatisch (Triage wählt)'), findsOneWidget);
      expect(find.text('Auto (triage picks)'), findsNothing);
    });

    for (final (body, expected) in [
      (
        <String, Object?>{'ok': true, 'est_tokens': 13400, 'complexity': 'M'},
        'etwa 13k Token · mittel',
      ),
      (
        <String, Object?>{'ok': true, 'est_tokens': 1, 'complexity': 'S'},
        'etwa 1 Token · klein',
      ),
      (<String, Object?>{'ok': true, 'est_tokens': 640}, 'etwa 640 Token'),
      (<String, Object?>{'ok': true, 'complexity': 'L'}, 'groß'),
      (<String, Object?>{'ok': true}, 'Keine Schätzung verfügbar.'),
      (<String, Object?>{'ok': false}, 'Keine Schätzung verfügbar.'),
      (<String, Object?>{'ok': false, 'reason': 'no model'}, 'no model'),
    ]) {
      testWidgets('the estimate ${body.values.join(' ')} reads "$expected"', (
        tester,
      ) async {
        server.on('POST', '/api/plugins/kanban/estimate', body);
        await pump(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'Titel'),
          'Add dark mode',
        );
        await tester.pump();
        await tester.tap(find.text('Aufwand schätzen'));
        await tester.pumpAndSettle();

        expect(find.text(expected), findsOneWidget);
      });
    }
  });

  group('board screen', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      server
        ..on(
          'GET',
          '/api/plugins/kanban/boards',
          kanbanBoardsBody([
            (slug: 'default', name: 'Default', total: 3, current: true),
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
              progress: {'done': 2, 'total': 5},
            ),
            kanbanTaskRow(
              id: 't_run2',
              title: 'Fix the build',
              status: 'running',
              progress: {'done': 1, 'total': 3},
            ),
            kanbanTaskRow(id: 't_todo', title: 'Write docs', status: 'todo'),
          ]),
        )
        ..on('GET', '/api/plugins/kanban/assignees', {
          'assignees': ['coder'],
        })
        ..on('GET', '/api/plugins/kanban/model-options', {'providers': []});
    });

    Future<void> pump(
      WidgetTester tester, {
      Size size = const Size(400, 800),
      TargetPlatform platform = TargetPlatform.android,
      Locale locale = const Locale('de'),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(),
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

    testWidgets('the app bar, menus, filters and chips are German', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Kanban'), findsOneWidget);
      expect(find.tooltip('Board wechseln'), findsOneWidget);
      expect(find.tooltip('Live'), findsOneWidget);
      expect(find.tooltip('Switch board'), findsNothing);
      expect(find.text('Läuft 2'), findsOneWidget);
      expect(find.text('To-do 1'), findsOneWidget);
      expect(find.text('Running 2'), findsNothing);
      expect(find.text('Aufgaben suchen'), findsOneWidget);
      expect(find.text('Alle Zuständigen'), findsOneWidget);
      expect(find.text('Archiviert'), findsOneWidget);
      expect(find.text('Search tasks'), findsNothing);
      expect(find.text('All assignees'), findsNothing);
      expect(find.text('Archived'), findsNothing);

      await tester.tap(find.tooltip('Board wechseln'));
      await tester.pumpAndSettle();
      expect(find.text('Boards verwalten…'), findsOneWidget);
      expect(find.text('Manage boards…'), findsNothing);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      for (final text in [
        'Aufgaben auswählen',
        'Dispatcher jetzt ausführen',
        'Aktive Worker…',
        'Orchestrierung…',
      ]) {
        expect(find.text(text), findsOneWidget, reason: text);
      }
      for (final text in [
        'Select tasks',
        'Run dispatcher now',
        'Active workers…',
        'Orchestration…',
      ]) {
        expect(find.text(text), findsNothing, reason: text);
      }
    });

    testWidgets('a running card says how far it is, in German', (tester) async {
      await pump(tester);

      Finder bar(String label) => find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == label,
      );
      expect(
        tester.widget<Semantics>(bar('In Arbeit').first).properties.value,
        '2 von 5 erledigt',
      );
      expect(bar('In progress'), findsNothing);
    });

    testWidgets('a status without tasks says so in German', (tester) async {
      await pump(tester);
      await tester.ensureVisible(find.text('Triage 0'));
      await tester.tap(find.text('Triage 0'));
      await tester.pumpAndSettle();

      expect(find.text('Hier sind keine Aufgaben'), findsOneWidget);
      expect(find.text('No tasks here'), findsNothing);
    });

    testWidgets('the selection bar counts in German', (tester) async {
      await pump(tester);
      await tester.longPress(find.text('Migrate webhooks'));
      await tester.pumpAndSettle();
      expect(find.text('1 ausgewählt'), findsOneWidget);
      expect(find.tooltip('Auswahl abbrechen'), findsOneWidget);

      await tester.tap(find.text('Fix the build'));
      await tester.pumpAndSettle();
      expect(find.text('2 ausgewählt'), findsOneWidget);
      expect(find.text('2 selected'), findsNothing);
      expect(find.tooltip('Cancel selection'), findsNothing);
    });

    testWidgets('the drag handle is named in German', (tester) async {
      await pump(tester);
      expect(find.tooltip('Zum Verschieben ziehen'), findsWidgets);
      expect(find.tooltip('Drag to move'), findsNothing);
    });

    testWidgets('nudging the dispatcher is answered in German', (tester) async {
      server.on('POST', '/api/plugins/kanban/dispatch', {'ok': true});
      await pump(tester);
      await tester.tap(find.byType(PopupMenuButton<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dispatcher jetzt ausführen'));
      await tester.pumpAndSettle();

      expect(find.text('Dispatcher angestoßen'), findsOneWidget);
      expect(find.text('Dispatcher nudged'), findsNothing);
    });

    testWidgets('a failed load is German and offers a retry', (tester) async {
      server.on('GET', '/api/plugins/kanban/board', {
        'detail': 'x',
      }, status: 500);
      await pump(tester);

      expect(
        find.text('Das Board konnte nicht geladen werden'),
        findsOneWidget,
      );
      expect(find.text('Erneut versuchen'), findsOneWidget);
      expect(find.text('Could not load the board'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a turned-off plugin is explained in German', (tester) async {
      server.on('GET', '/api/plugins/kanban/board', {
        'detail': 'x',
      }, status: 404);
      await pump(tester);

      expect(find.text('Kanban ist nicht verfügbar'), findsOneWidget);
      expect(
        find.text('Das Plugin wurde auf diesem Server abgeschaltet.'),
        findsOneWidget,
      );
      expect(find.text('Kanban isn’t available'), findsNothing);
    });

    testWidgets('the refresh notice is German', (tester) async {
      await pump(tester);
      server.on('GET', '/api/plugins/kanban/board', {
        'detail': 'x',
      }, status: 500);
      await tester.drag(find.text('Migrate webhooks'), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Aktualisieren fehlgeschlagen. Das zuletzt geladene Board wird '
          'angezeigt.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Could not refresh. Showing the last board.'),
        findsNothing,
      );
    });

    testWidgets('the wide columns and the Mac toolbar are German', (
      tester,
    ) async {
      await pump(
        tester,
        size: const Size(1400, 900),
        platform: TargetPlatform.macOS,
      );

      expect(find.text('Läuft  2'), findsOneWidget);
      expect(find.text('Default · alle Profile · 3 Aufgaben'), findsOneWidget);
      expect(find.tooltip('Neue Aufgabe ⌘N'), findsOneWidget);
      expect(find.tooltip('Informationen ausblenden ⌥⌘I'), findsOneWidget);
      expect(find.bySemanticsLabel('Nach Profil filtern'), findsOneWidget);
      expect(find.bySemanticsLabel('Board wechseln'), findsOneWidget);
      expect(find.bySemanticsLabel('Mehr'), findsOneWidget);
      expect(find.text('Keine Aufgabe ausgewählt'), findsOneWidget);
      expect(
        find.text('Klicke auf eine Karte, um hier ihre Details zu sehen.'),
        findsOneWidget,
      );
      expect(find.text('Default · all profiles · 3 tasks'), findsNothing);
      expect(find.text('No task selected'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Nach Profil filtern'));
      await tester.pumpAndSettle();
      expect(find.text('Alle Profile'), findsOneWidget);
      expect(find.text('All profiles'), findsNothing);
      await tester.tap(
        find.widgetWithText(CheckedPopupMenuItem<({String? profile})>, 'coder'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Default · coder · 1 Aufgabe'), findsOneWidget);
      expect(find.tooltip('Informationen ausblenden ⌥⌘I'), findsOneWidget);
      await tester.tap(find.byKey(const Key('kanban-inspector-toggle')));
      await tester.pumpAndSettle();
      expect(find.tooltip('Informationen einblenden ⌥⌘I'), findsOneWidget);
      expect(find.tooltip('Show Inspector ⌥⌘I'), findsNothing);
    });

    testWidgets('the tenant filter and the iOS search field are German', (
      tester,
    ) async {
      server.on(
        'GET',
        '/api/plugins/kanban/board',
        kanbanBoardBody(
          [kanbanTaskRow(id: 't_todo', title: 'Write docs', status: 'todo')],
          tenants: ['acme'],
        ),
      );
      await pump(tester, platform: TargetPlatform.iOS);

      expect(find.text('Alle Mandanten'), findsOneWidget);
      expect(find.text('All tenants'), findsNothing);
      expect(find.text('Aufgaben suchen'), findsOneWidget);
      expect(find.text('Search tasks'), findsNothing);

      await tester.tap(find.text('Alle Mandanten'));
      await tester.pumpAndSettle();
      expect(find.text('Alle Mandanten'), findsNWidgets(2));
    });

    testWidgets('a lost event stream is named in German', (tester) async {
      await tester.pumpWidget(
        _german(const Scaffold(body: KanbanLiveDot(live: false))),
      );
      expect(
        find.tooltip('Verbindung wird wiederhergestellt…'),
        findsOneWidget,
      );
      expect(find.tooltip('Reconnecting…'), findsNothing);
    });

    // The plugin refuses some of the three selected tasks; the snackbar names
    // how many and the first reason.
    for (final (name, locale, action, option, refused, expected) in [
      (
        'a partly failed bulk move says so in de',
        const Locale('de'),
        'Verschieben',
        'Prüfung',
        {'t2': 'task is running'},
        '1 von 3 konnte nicht geändert werden: task is running',
      ),
      (
        'a partly failed bulk move says so in en',
        const Locale('en'),
        'Move',
        'Review',
        {'t2': 'task is running'},
        '1 of 3 could not be changed: task is running',
      ),
      (
        'a bulk move that fails for several tasks counts them in de',
        const Locale('de'),
        'Verschieben',
        'Prüfung',
        {'t2': 'task is running', 't3': 'task is blocked'},
        '2 von 3 konnten nicht geändert werden: task is running',
      ),
      (
        'a bulk move that fails for several tasks counts them in en',
        const Locale('en'),
        'Move',
        'Review',
        {'t2': 'task is running', 't3': 'task is blocked'},
        '2 of 3 could not be changed: task is running',
      ),
    ]) {
      testWidgets(name, (tester) async {
        server
          ..on(
            'GET',
            '/api/plugins/kanban/board',
            kanbanBoardBody([
              for (final n in [1, 2, 3])
                kanbanTaskRow(
                  id: 't$n',
                  title: 'Task number $n',
                  status: 'running',
                  progress: {'done': 1, 'total': 2},
                ),
            ]),
          )
          ..on('POST', '/api/plugins/kanban/tasks/bulk', {
            'results': [
              for (final n in [1, 2, 3])
                if (refused['t$n'] case final error?)
                  {'id': 't$n', 'ok': false, 'error': error}
                else
                  {'id': 't$n', 'ok': true},
            ],
          });
        await pump(tester, locale: locale);
        await tester.longPress(find.text('Task number 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Task number 2'));
        await tester.tap(find.text('Task number 3'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        await tester.tap(find.text(option));
        await tester.pumpAndSettle();

        expect(find.text(expected), findsOneWidget);
      });
    }
  });

  group('the task log', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        _german(
          Scaffold(
            body: KanbanTaskLogDialog(
              repository: KanbanRepository(server.client()),
              taskId: 't1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('its title, close button and output notes are German', (
      tester,
    ) async {
      server.on('GET', '/api/plugins/kanban/tasks/t1/log', {
        'content': 'step one',
        'exists': true,
        'truncated': true,
      });
      await pump(tester);

      expect(find.text('Log · t1'), findsOneWidget);
      expect(find.text('Schließen'), findsOneWidget);
      expect(
        find.textContaining('… (frühere Ausgabe gekürzt)'),
        findsOneWidget,
      );
      expect(find.textContaining('earlier output cut'), findsNothing);
      expect(find.text('Close'), findsNothing);
    });

    for (final (body, status, expected) in [
      (<String, Object?>{'content': '', 'exists': true}, 200, '(leer)'),
      (
        <String, Object?>{'content': '', 'exists': false},
        200,
        'Noch kein Worker hat diese Aufgabe ausgeführt.',
      ),
      (
        <String, Object?>{'detail': 'x'},
        500,
        'Das Log konnte nicht geladen werden.',
      ),
    ]) {
      testWidgets('says "$expected"', (tester) async {
        server.on(
          'GET',
          '/api/plugins/kanban/tasks/t1/log',
          body,
          status: status,
        );
        await pump(tester);

        expect(find.text(expected), findsOneWidget);
      });
    }
  });

  group('a Kanban action that fails unexpectedly', () {
    testWidgets('tells the user in German', (tester) async {
      await tester.pumpWidget(
        _german(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => runKanbanAction(
                  context,
                  () async => throw StateError('boom'),
                ),
                child: const Text('Los'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Los'));
      await tester.pumpAndSettle();

      expect(
        find.text('Etwas ist schiefgelaufen. Versuche es noch einmal.'),
        findsOneWidget,
      );
      expect(find.text('Something went wrong. Try again.'), findsNothing);
      // A bug goes to the crash reporter, which the test binding rethrows.
      expect(tester.takeException(), isA<StateError>());
    });
  });

  group('the status and effort labels', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final de = lookupAppLocalizations(const Locale('de'));
    final statuses = [...kanbanStatuses, 'archived'];

    test('name every known status in both languages', () {
      expect(
        [for (final s in statuses) kanbanStatusLabel(en, s)],
        [
          'Triage',
          'Todo',
          'Scheduled',
          'Ready',
          'Running',
          'Blocked',
          'Review',
          'Done',
          'Archived',
        ],
      );
      expect(
        [for (final s in statuses) kanbanStatusLabel(de, s)],
        [
          'Triage',
          'To-do',
          'Geplant',
          'Bereit',
          'Läuft',
          'Blockiert',
          'Prüfung',
          'Erledigt',
          'Archiviert',
        ],
      );
    });

    test('pass an unknown or empty status through as the server sent it', () {
      for (final l10n in [en, de]) {
        expect(kanbanStatusLabel(l10n, 'waiting'), 'waiting');
        expect(kanbanStatusLabel(l10n, ''), '');
      }
    });

    test('name every known effort level in both languages', () {
      expect(
        [for (final e in kReasoningEfforts) effortLabel(en, e)],
        [
          'Off',
          'Minimal',
          'Low',
          'Medium',
          'High',
          'Extra High',
          'Max',
          'Ultra',
        ],
      );
      expect(
        [for (final e in kReasoningEfforts) effortLabel(de, e)],
        [
          'Aus',
          'Minimal',
          'Niedrig',
          'Mittel',
          'Hoch',
          'Sehr hoch',
          'Maximal',
          'Ultra',
        ],
      );
    });

    test('pass an unknown effort through as the server sent it', () {
      for (final l10n in [en, de]) {
        expect(effortLabel(l10n, 'turbo'), 'turbo');
        expect(effortLabel(l10n, ''), '');
      }
    });
  });

  group('the counts', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final de = lookupAppLocalizations(const Locale('de'));

    test('selected tasks', () {
      expect(en.kanbanSelectionCount(1), '1 selected');
      expect(en.kanbanSelectionCount(4), '4 selected');
      expect(de.kanbanSelectionCount(1), '1 ausgewählt');
      expect(de.kanbanSelectionCount(4), '4 ausgewählt');
    });

    test('tasks a bulk change could not reach', () {
      expect(
        en.kanbanBulkFailed(1, 3, 'nope'),
        '1 of 3 could not be changed: nope',
      );
      expect(
        en.kanbanBulkFailed(2, 3, 'nope'),
        '2 of 3 could not be changed: nope',
      );
      expect(
        de.kanbanBulkFailed(1, 3, 'nope'),
        '1 von 3 konnte nicht geändert werden: nope',
      );
      expect(
        de.kanbanBulkFailed(2, 3, 'nope'),
        '2 von 3 konnten nicht geändert werden: nope',
      );
    });

    test('the size of an estimate', () {
      expect(en.kanbanEstimateTokens(1), 'about 1 token');
      expect(en.kanbanEstimateTokens(640), 'about 640 tokens');
      expect(de.kanbanEstimateTokens(1), 'etwa 1 Token');
      expect(de.kanbanEstimateTokens(640), 'etwa 640 Token');
    });
  });
}
