import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/widgets/row_actions.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_workers_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/accessibility.dart';
import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';
import 'support/test_localizations.dart';
import 'support/tooltip_finder.dart';

void main() {
  late FakeHermesServer server;
  late int changes;

  setUp(() {
    server = FakeHermesServer();
    changes = 0;
  });

  Map<String, Object?> worker({int run = 7, String task = 't1'}) => {
    'run_id': run,
    'task_id': task,
    'task_title': 'Migrate webhooks',
    'profile': 'coder',
    'worker_pid': 4242,
    'started_at': 1780000000,
  };

  Future<void> pump(WidgetTester tester, {Locale? locale}) async {
    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildHermesLightTheme(),
        home: KanbanWorkersScreen(
          repository: KanbanRepository(server.client()),
          board: 'ops',
          onChanged: () => changes++,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester, String item) async {
    await tester.tap(find.byType(PopupMenuButton<RowAction>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the running workers', (tester) async {
    server.on('GET', '/api/plugins/kanban/workers/active', {
      'workers': [worker()],
    });
    await pump(tester);

    expect(find.text('Migrate webhooks'), findsOneWidget);
    expect(find.textContaining('run #7'), findsOneWidget);
    expect(find.textContaining('coder'), findsOneWidget);
  });

  testWidgets('says so when nothing is running', (tester) async {
    server.on('GET', '/api/plugins/kanban/workers/active', {'workers': []});
    await pump(tester);

    expect(find.text('No workers are running'), findsOneWidget);
  });

  testWidgets('offers a retry when the list fails to load', (tester) async {
    server.on(
      'GET',
      '/api/plugins/kanban/workers/active',
      <String, Object?>{},
      status: 500,
    );
    await pump(tester);
    expect(find.text('Could not load the workers'), findsOneWidget);

    server.on('GET', '/api/plugins/kanban/workers/active', {
      'workers': [worker()],
    });
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Migrate webhooks'), findsOneWidget);
  });

  testWidgets('the page and its states are in German', (tester) async {
    server.on('GET', '/api/plugins/kanban/workers/active', {
      'workers': [worker()],
    });
    await pump(tester, locale: const Locale('de'));

    expect(find.text('Aktive Worker'), findsOneWidget);
    expect(find.text('1 läuft'), findsOneWidget);

    server.on('GET', '/api/plugins/kanban/workers/active', {'workers': []});
    await tester.drag(find.byType(ListView).first, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.text('Es laufen keine Worker'), findsOneWidget);
  });

  testWidgets('a failed load and its Retry are in German', (tester) async {
    server.on(
      'GET',
      '/api/plugins/kanban/workers/active',
      <String, Object?>{},
      status: 500,
    );
    await pump(tester, locale: const Locale('de'));

    expect(
      find.text('Die Worker konnten nicht geladen werden'),
      findsOneWidget,
    );
    expect(find.text('Erneut versuchen'), findsOneWidget);
  });

  testWidgets('the Terminate question is in German', (tester) async {
    server.on('GET', '/api/plugins/kanban/workers/active', {
      'workers': [worker()],
    });
    await pump(tester, locale: const Locale('de'));

    await tester.tap(find.byType(PopupMenuButton<RowAction>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beenden'));
    await tester.pumpAndSettle();

    expect(find.text('Lauf #7 beenden?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Beenden'), findsOneWidget);
  });

  testWidgets('shows a worker process\'s figures', (tester) async {
    server
      ..on('GET', '/api/plugins/kanban/workers/active', {
        'workers': [worker()],
      })
      ..on('GET', '/api/plugins/kanban/runs/7/inspect', {
        'alive': true,
        'pid': 4242,
        'cpu_percent': 12.5,
        'memory_rss_bytes': 104857600,
        'num_threads': 9,
      });
    await pump(tester);

    await openMenu(tester, 'Inspect process');

    // The plugin's first CPU reading is always 0, so it is not shown.
    expect(find.textContaining('CPU'), findsNothing);
    expect(find.textContaining('Threads: 9'), findsOneWidget);
    expect(find.textContaining('Memory: 100 MB'), findsOneWidget);
  });

  testWidgets('says when the process is gone', (tester) async {
    server
      ..on('GET', '/api/plugins/kanban/workers/active', {
        'workers': [worker()],
      })
      ..on('GET', '/api/plugins/kanban/runs/7/inspect', {
        'alive': false,
        'reason': 'process not found',
      });
    await pump(tester);

    await openMenu(tester, 'Inspect process');

    expect(find.textContaining('process not found'), findsOneWidget);
  });

  testWidgets('the Inspect dialog is in German', (tester) async {
    server
      ..on('GET', '/api/plugins/kanban/workers/active', {
        'workers': [worker()],
      })
      ..on('GET', '/api/plugins/kanban/runs/7/inspect', {
        'alive': true,
        'pid': 4242,
        'memory_rss_bytes': 104857600,
        'num_threads': 9,
      });
    await pump(tester, locale: const Locale('de'));

    await openMenu(tester, 'Prozess untersuchen');

    expect(find.text('Lauf #7'), findsOneWidget);
    expect(
      find.text('Prozess 4242\nArbeitsspeicher: 100 MB\nThreads: 9'),
      findsOneWidget,
    );
    expect(find.text('Schließen'), findsOneWidget);
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    server.on('GET', '/api/plugins/kanban/runs/7/inspect', {'alive': false});
    await openMenu(tester, 'Prozess untersuchen');
    expect(find.text('Der Prozess läuft nicht mehr.'), findsOneWidget);
  });

  testWidgets('terminates a run after confirming and refreshes', (
    tester,
  ) async {
    server
      ..on('GET', '/api/plugins/kanban/workers/active', {
        'workers': [worker()],
      })
      ..on('POST', '/api/plugins/kanban/runs/7/terminate', {'ok': true});
    await pump(tester);

    await openMenu(tester, 'Terminate');
    await tester.tap(find.widgetWithText(FilledButton, 'Terminate'));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('POST', '/api/plugins/kanban/runs/7/terminate'),
      hasLength(1),
    );
    expect(changes, 1);
    expect(
      server.requestsTo('GET', '/api/plugins/kanban/workers/active'),
      hasLength(2),
    );
  });

  testWidgets('says why a run could not be terminated', (tester) async {
    server
      ..on('GET', '/api/plugins/kanban/workers/active', {
        'workers': [worker()],
      })
      ..on('POST', '/api/plugins/kanban/runs/7/terminate', {
        'detail': 'run 7 already ended',
      }, status: 409);
    await pump(tester);

    await openMenu(tester, 'Terminate');
    await tester.tap(find.widgetWithText(FilledButton, 'Terminate'));
    await tester.pumpAndSettle();

    expect(find.text('run 7 already ended'), findsOneWidget);
    expect(changes, 0);
  });

  testWidgets('tapping a worker opens its task', (tester) async {
    server
      ..on('GET', '/api/plugins/kanban/workers/active', {
        'workers': [worker()],
      })
      ..on(
        'GET',
        '/api/plugins/kanban/tasks/t1',
        kanbanTaskDetailBody(
          kanbanTaskRow(id: 't1', title: 'Migrate webhooks', status: 'running')
            ..['body'] = 'Details here',
        ),
      );
    await pump(tester);

    await tester.tap(find.text('Migrate webhooks'));
    await tester.pumpAndSettle();

    expect(find.text('Details here'), findsOneWidget);
  });

  testWidgets('shows the plugin\'s reason when the first load is refused', (
    tester,
  ) async {
    server.on('GET', '/api/plugins/kanban/workers/active', {
      'detail': 'board \'nope\' does not exist',
    }, status: 404);
    await pump(tester);

    expect(find.textContaining('does not exist'), findsOneWidget);
  });

  testWidgets('a refresh that fails keeps the list and says so', (
    tester,
  ) async {
    server.on('GET', '/api/plugins/kanban/workers/active', {
      'workers': [worker()],
    });
    await pump(tester);

    server.on('GET', '/api/plugins/kanban/workers/active', {
      'detail': 'gateway timeout',
    }, status: 504);
    await tester.tap(find.tooltip('Refresh'));
    await tester.pumpAndSettle();

    expect(find.text('Migrate webhooks'), findsOneWidget);
    expect(find.textContaining('Could not refresh'), findsOneWidget);
  });

  testWidgets('a failed refresh says so in German and keeps the reason', (
    tester,
  ) async {
    server.on('GET', '/api/plugins/kanban/workers/active', {
      'workers': [worker()],
    });
    await pump(tester, locale: const Locale('de'));

    server.on('GET', '/api/plugins/kanban/workers/active', {
      'detail': 'gateway timeout',
    }, status: 504);
    await tester.tap(find.tooltip('Aktualisieren'));
    await tester.pumpAndSettle();

    expect(find.text('Migrate webhooks'), findsOneWidget);
    expect(
      find.text('Aktualisieren fehlgeschlagen: gateway timeout'),
      findsOneWidget,
    );
  });

  testWidgets('an older load that finishes late does not replace a newer one', (
    tester,
  ) async {
    final slow = Completer<void>();
    var calls = 0;
    server.onRequest('GET', '/api/plugins/kanban/workers/active', (_) async {
      calls++;
      if (calls == 2) {
        await slow.future;
        return (
          status: 200,
          body: {
            'workers': [worker(run: 1, task: 'old')],
          },
        );
      }
      return (
        status: 200,
        body: {
          'workers': calls == 1 ? [worker(run: 1, task: 'old')] : <Object?>[],
        },
      );
    });
    await pump(tester);
    expect(find.text('Migrate webhooks'), findsOneWidget);

    await tester.tap(find.tooltip('Refresh'));
    await tester.pump();
    await tester.tap(find.tooltip('Refresh'));
    await tester.pumpAndSettle();
    slow.complete();
    await tester.pumpAndSettle();

    expect(find.text('No workers are running'), findsOneWidget);
  });

  testWidgets('reads the list again after a task opened from it is closed', (
    tester,
  ) async {
    server
      ..on('GET', '/api/plugins/kanban/workers/active', {
        'workers': [worker()],
      })
      ..on(
        'GET',
        '/api/plugins/kanban/tasks/t1',
        kanbanTaskDetailBody(
          kanbanTaskRow(id: 't1', title: 'Migrate webhooks', status: 'running'),
        ),
      );
    await pump(tester);
    final before = server
        .requestsTo('GET', '/api/plugins/kanban/workers/active')
        .length;

    await tester.tap(find.text('Migrate webhooks'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(
      server.requestsTo('GET', '/api/plugins/kanban/workers/active').length,
      before + 1,
    );
  });

  testWidgets('screen readers get Refresh by name', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    expect(
      tester.getSemantics(find.byIcon(Icons.refresh)),
      namedButton('Refresh'),
    );
    handle.dispose();
  });
}
