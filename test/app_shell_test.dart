import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';
import 'support/fake_share_inbox.dart';

/// The Kanban tab exists only while the server has the plugin on.
void main() {
  late FakeHermesServer server;
  late FakeShareInbox inbox;
  late FakeNotificationService notifications;

  /// Boards built and torn down, in the order they happened.
  late List<String> boardLog;

  setUp(() {
    boardLog = [];
    inbox = FakeShareInbox();
    notifications = FakeNotificationService();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
  });

  Future<void> pumpShell(
    WidgetTester tester, {
    required Size size,
    NotificationSettings? settings,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(inbox)..start(),
          ),
          Provider<NotificationService>.value(value: notifications),
          if (settings != null)
            ChangeNotifierProvider<NotificationSettings>.value(value: settings),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: AppShell(
            plugins: HermesPluginsRepository(server.client().raw),
            cron: HermesCronRepository(server.client().raw),
            kanbanBuilder: (_) => _Board(boardLog),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  void kanbanPlugin({required bool on}) => server.on(
    'GET',
    '/api/dashboard/plugins',
    on
        ? [
            {'name': 'kanban'},
          ]
        : <Object?>[],
  );

  testWidgets('shows no navigation while the plugin is off', (tester) async {
    kanbanPlugin(on: false);

    await pumpShell(tester, size: const Size(400, 800));

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('offers a Kanban tab in a bottom bar on a phone', (tester) async {
    kanbanPlugin(on: true);

    await pumpShell(tester, size: const Size(400, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Kanban'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('the board'), findsOneWidget);
  });

  testWidgets('offers a Kanban tab in a rail on a wide screen', (tester) async {
    kanbanPlugin(on: true);

    await pumpShell(tester, size: const Size(1400, 900));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('drops the tab when the plugin is turned off', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    expect(find.byType(NavigationBar), findsOneWidget);

    kanbanPlugin(on: false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('ignores a slower answer that a newer check has superseded', (
    tester,
  ) async {
    final first = Completer<FakeResponse>();
    var calls = 0;
    server.onRequest('GET', '/api/dashboard/plugins', (_) {
      calls++;
      return calls == 1 ? first.future : (status: 200, body: <Object?>[]);
    });
    await pumpShell(tester, size: const Size(400, 800));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    first.complete((
      status: 200,
      body: [
        {'name': 'kanban'},
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
  });

  Future<void> openKanban(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Kanban'),
      ),
    );
    await tester.pumpAndSettle();
  }

  int selectedTab(WidgetTester tester) => tester
      .widget<NavigationBar>(find.byType(NavigationBar, skipOffstage: false))
      .selectedIndex;

  Future<void> flipPlugin(WidgetTester tester, {required bool on}) async {
    kanbanPlugin(on: on);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  testWidgets('a notification tap switches from Kanban to Chat', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);
    expect(selectedTab(tester), 1);

    notifications.tap('t2');
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
  });

  testWidgets('shared content switches from Kanban to Chat', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);

    inbox.emit([const SharedText('https://example.com')]);
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
    expect(find.text('https://example.com'), findsOneWidget);
  });

  testWidgets('shared files switch from Kanban to Chat', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);

    inbox.emit([const SharedFile(path: '/tmp/report.pdf', name: 'report.pdf')]);
    await tester.pumpAndSettle();

    expect(selectedTab(tester), 0);
  });

  Future<void> pushOverBoard(WidgetTester tester) async {
    await tester.tap(find.text('open a task'));
    await tester.pumpAndSettle();
    expect(find.text('the task'), findsOneWidget);
  }

  testWidgets('a notification tap dismisses a screen pushed over the board', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);
    await pushOverBoard(tester);

    notifications.tap('t2');
    await tester.pumpAndSettle();

    expect(find.text('the task'), findsNothing);
    expect(selectedTab(tester), 0);
  });

  testWidgets('shared content dismisses a screen pushed over the board', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);
    await pushOverBoard(tester);

    inbox.emit([const SharedText('https://example.com')]);
    await tester.pumpAndSettle();

    expect(find.text('the task'), findsNothing);
    expect(selectedTab(tester), 0);
    expect(find.text('https://example.com'), findsOneWidget);
  });

  testWidgets('the board is not built until its tab is opened', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));

    expect(boardLog, isEmpty);
    await openKanban(tester);
    expect(boardLog, ['open']);
  });

  testWidgets('the board and its local state survive a visit to Chat', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);
    await tester.enterText(find.byType(TextField), 'deploy');

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Chat'),
      ),
    );
    await tester.pumpAndSettle();
    await openKanban(tester);

    expect(find.text('deploy'), findsOneWidget);
    expect(boardLog, ['open']);
  });

  testWidgets('a plugin that goes off and on does not reopen the board', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openKanban(tester);

    await flipPlugin(tester, on: false);
    await flipPlugin(tester, on: true);

    expect(selectedTab(tester), 0);
    expect(boardLog, ['open', 'close']);
  });

  void cronRoutes({required bool on}) => server.on(
    'GET',
    '/api/cron/delivery-targets',
    cronDeliveryTargets,
    status: on ? 200 : 404,
  );

  void jobRoutes() => server
    ..on('GET', '/api/cron/jobs', [cronJobRow()])
    ..on('GET', '/api/cron/jobs/job1', cronJobRow())
    ..on('GET', '/api/cron/jobs/job1/runs', {
      'runs': [
        cronRunRow(
          id: 'cron_job1_1',
          startedAt: 1789800000,
          endedAt: 1789800042,
        ),
      ],
    });

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> navigationLabels(WidgetTester tester) => [
    for (final d
        in tester
            .widget<NavigationBar>(
              find.byType(NavigationBar, skipOffstage: false),
            )
            .destinations)
      (d as NavigationDestination).label,
  ];

  group('Schedules', () {
    testWidgets('is offered without Kanban when the server has cron routes', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);

      await pumpShell(tester, size: const Size(400, 800));

      expect(navigationLabels(tester), ['Chat', 'Schedules']);
    });

    testWidgets('sits next to Kanban when both are on', (tester) async {
      kanbanPlugin(on: true);
      cronRoutes(on: true);

      await pumpShell(tester, size: const Size(400, 800));

      expect(navigationLabels(tester), ['Chat', 'Kanban', 'Schedules']);
    });

    testWidgets('is offered in a rail on a wide screen', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);

      await pumpShell(tester, size: const Size(1400, 900));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.text('Schedules'), findsOneWidget);
    });

    testWidgets('is not offered by a server without the cron routes', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: false);

      await pumpShell(tester, size: const Size(400, 800));

      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('does not load jobs until its tab is opened', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      await pumpShell(tester, size: const Size(400, 800));

      expect(server.requests.where((r) => r.path == '/api/cron/jobs'), isEmpty);
      await openTab(tester, 'Schedules');

      expect(find.text('Morning brief'), findsOneWidget);
    });

    testWidgets('keeps its filter across a visit to Chat', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      await pumpShell(tester, size: const Size(400, 800));
      await openTab(tester, 'Schedules');
      await tester.ensureVisible(find.text('Paused'));
      await tester.tap(find.text('Paused'));
      await tester.pumpAndSettle();

      await openTab(tester, 'Chat');
      await openTab(tester, 'Schedules');

      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Paused'))
            .selected,
        isTrue,
      );
    });

    testWidgets('goes back to Chat when cron goes away while selected', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      await pumpShell(tester, size: const Size(400, 800));
      await openTab(tester, 'Schedules');

      cronRoutes(on: false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Morning brief'), findsNothing);
    });

    testWidgets('opening a run brings Chat to the front', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      await pumpShell(tester, size: const Size(400, 800));
      await openTab(tester, 'Schedules');
      await tester.tap(find.text('Morning brief'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('42 s'));
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 0);
      expect(find.text('Delete task'), findsNothing);
    });

    testWidgets('a notification tap leaves Schedules for Chat', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      jobRoutes();
      await pumpShell(tester, size: const Size(400, 800));
      await openTab(tester, 'Schedules');

      notifications.tap('t2');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 0);
    });
  });

  group('scheduled task notifications', () {
    void twoJobs() => server
      ..on('GET', '/api/cron/jobs', [cronJobRow()])
      ..on('GET', '/api/cron/jobs/job1', cronJobRow())
      ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});

    testWidgets('a tap opens the job in Schedules from Chat', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      twoJobs();
      await pumpShell(tester, size: const Size(400, 800));

      notifications.tapJob('job1', profile: 'work');
      await tester.pumpAndSettle();

      expect(navigationLabels(tester), ['Chat', 'Schedules']);
      expect(selectedTab(tester), 1);
      expect(find.text('Say good morning'), findsOneWidget);
    });

    testWidgets('a tap for a job that is gone shows the list and says so', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      server
        ..on('GET', '/api/cron/jobs', [])
        ..on('GET', '/api/cron/jobs/gone', {}, status: 404);
      await pumpShell(tester, size: const Size(400, 800));

      notifications.tapJob('gone', profile: 'work');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 1);
      expect(find.text('This task no longer exists'), findsOneWidget);
      expect(find.text('No scheduled tasks'), findsOneWidget);
    });

    testWidgets('a summary tap shows the list', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      twoJobs();
      await pumpShell(tester, size: const Size(400, 800));

      notifications.tapJob('');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 1);
      expect(find.text('Morning brief'), findsOneWidget);
    });

    testWidgets('a tap that comes before cron is detected waits for it', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      twoJobs();
      await pumpShell(tester, size: const Size(400, 800), settle: false);

      notifications.tapJob('job1', profile: 'work');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 1);
      expect(find.text('Say good morning'), findsOneWidget);
    });

    testWidgets('a chat tap still opens Chat', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      twoJobs();
      await pumpShell(tester, size: const Size(400, 800));
      await openTab(tester, 'Schedules');

      notifications.tap('t2');
      await tester.pumpAndSettle();

      expect(selectedTab(tester), 0);
    });

    testWidgets('a job that runs while the user is in Chat is announced', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);
      server.on('GET', '/api/profiles/active', {
        'active': 'work',
        'current': 'work',
      });
      server.on('GET', '/api/cron/jobs', [
        cronJobRow(lastRunAt: '2026-09-20T08:00:00+00:00', lastStatus: 'ok'),
      ]);
      final settings = NotificationSettings();
      await tester.runAsync(settings.load);
      await pumpShell(tester, size: const Size(400, 800), settings: settings);
      expect(notifications.shown, isEmpty);

      server.on('GET', '/api/cron/jobs', [
        cronJobRow(lastRunAt: '2026-09-21T08:00:00+00:00', lastStatus: 'ok'),
      ]);
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      expect(notifications.shown.map((n) => n.body), ['Finished']);
      expect(notifications.shown.single.jobId, 'job1');
      expect(
        server.requests
            .where((r) => r.path == '/api/cron/jobs')
            .every((r) => r.queryParameters['profile'] == 'all'),
        isTrue,
      );
    });

    testWidgets(
      'a job that runs while Schedules is in front is not announced',
      (tester) async {
        kanbanPlugin(on: false);
        cronRoutes(on: true);
        server.on('GET', '/api/cron/jobs', [
          cronJobRow(lastRunAt: '2026-09-20T08:00:00+00:00', lastStatus: 'ok'),
        ]);
        final settings = NotificationSettings();
        await tester.runAsync(settings.load);
        await pumpShell(tester, size: const Size(400, 800), settings: settings);
        await openTab(tester, 'Schedules');

        server.on('GET', '/api/cron/jobs', [
          cronJobRow(lastRunAt: '2026-09-21T08:00:00+00:00', lastStatus: 'ok'),
        ]);
        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();

        expect(notifications.shown, isEmpty);
      },
    );
  });
}

/// A stand-in for the Kanban page that records when it starts and stops.
class _Board extends StatefulWidget {
  const _Board(this.log);

  final List<String> log;

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  @override
  void initState() {
    super.initState();
    widget.log.add('open');
  }

  @override
  void dispose() {
    widget.log.add('close');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Text('the board'),
      const TextField(),
      TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('the task')),
          ),
        ),
        child: const Text('open a task'),
      ),
    ],
  );
}
