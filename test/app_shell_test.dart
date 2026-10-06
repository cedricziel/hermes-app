import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_create_screen.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/macos/mac_commands.dart';
import 'package:hermes_app/src/schedules/blueprint_screens.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/share/shared_item.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stream_channel/stream_channel.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';
import 'support/fake_share_inbox.dart';
import 'support/kanban_fixtures.dart';
import 'support/mac_commands_builder.dart';

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
    WidgetBuilder? kanbanBuilder,
    TargetPlatform? platform,
    MacCommandRegistry? commands,
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
          theme: buildHermesLightTheme().copyWith(platform: platform),
          builder: macCommandsBuilder(commands),
          home: AppShell(
            plugins: HermesPluginsRepository(server.client().raw),
            cron: HermesCronRepository(server.client().raw),
            kanbanBuilder: kanbanBuilder ?? (_) => _Board(boardLog),
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

  /// Opens the drawer of a narrow layout: Chat's own, or the shell's on
  /// another page.
  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(
      find.byTooltip('Open navigation menu').hitTestable().first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> closeMenu(WidgetTester tester) async {
    tester
        .state<ScaffoldState>(
          find
              .ancestor(
                of: find.byType(Drawer),
                matching: find.byType(Scaffold),
              )
              .first,
        )
        .closeDrawer();
    await tester.pumpAndSettle();
  }

  /// The destinations in the drawer of a narrow layout, or null without any.
  Future<List<String>?> navigationLabels(WidgetTester tester) async {
    await openMenu(tester);
    final found = find.byType(ShellNavigation);
    final labels = found.evaluate().isEmpty
        ? null
        : [
            for (final d in tester.widget<ShellNavigation>(found).destinations)
              d.label,
          ];
    await closeMenu(tester);
    return labels;
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await openMenu(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(ShellNavigation),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows no navigation while the plugin is off', (tester) async {
    kanbanPlugin(on: false);

    await pumpShell(tester, size: const Size(400, 800));

    expect(find.byType(NavigationBar), findsNothing);
    expect(await navigationLabels(tester), isNull);
  });

  testWidgets('offers Kanban in the drawer on a phone, with no bottom bar', (
    tester,
  ) async {
    kanbanPlugin(on: true);

    await pumpShell(tester, size: const Size(400, 800));

    expect(find.byType(NavigationBar), findsNothing);
    await openTab(tester, 'Kanban');

    expect(find.text('the board'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('a page other than Chat opens the destinations from its menu', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    await openTab(tester, 'Kanban');
    expect(find.byKey(const Key('shell-menu')), findsOneWidget);

    await openTab(tester, 'Chat');

    expect(find.text('the board'), findsNothing);
    expect(find.byKey(const Key('shell-menu')), findsNothing);
  });

  testWidgets('lists the destinations in the sidebar on a wide screen', (
    tester,
  ) async {
    kanbanPlugin(on: true);

    await pumpShell(tester, size: const Size(1400, 900));

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ThreadSidebar),
        matching: find.byType(ShellNavigation),
      ),
      findsOneWidget,
    );
  });

  group('on an iPad', () {
    for (final size in const [Size(834, 1194), Size(744, 1133)]) {
      testWidgets('shows the sidebar in portrait at ${size.width.toInt()}', (
        tester,
      ) async {
        kanbanPlugin(on: true);

        await pumpShell(tester, size: size, platform: TargetPlatform.iOS);

        expect(
          find.descendant(
            of: find.byType(ThreadSidebar),
            matching: find.byType(ShellNavigation),
          ),
          findsOneWidget,
        );
        expect(find.byTooltip('Open navigation menu'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('keeps the drawer on an iPhone', (tester) async {
      kanbanPlugin(on: true);

      await pumpShell(
        tester,
        size: const Size(390, 844),
        platform: TargetPlatform.iOS,
      );

      expect(find.byTooltip('Open navigation menu'), findsWidgets);
    });

    testWidgets('keeps the drawer on Android at 834', (tester) async {
      kanbanPlugin(on: true);

      await pumpShell(
        tester,
        size: const Size(834, 1194),
        platform: TargetPlatform.android,
      );

      expect(find.byTooltip('Open navigation menu'), findsWidgets);
    });
  });

  testWidgets('keeps the destinations in place on the board of a wide screen', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(1400, 900));
    final inChat = tester.getTopLeft(find.text('Kanban'));

    await tester.tap(find.text('Kanban'));
    await tester.pumpAndSettle();

    expect(find.text('the board'), findsOneWidget);
    expect(find.byType(ShellSidebar), findsOneWidget);
    expect(tester.getTopLeft(find.text('Kanban')), inChat);
  });

  testWidgets('drops the tab when the plugin is turned off', (tester) async {
    kanbanPlugin(on: true);
    await pumpShell(tester, size: const Size(400, 800));
    expect(await navigationLabels(tester), ['Chat', 'Kanban']);

    kanbanPlugin(on: false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(await navigationLabels(tester), isNull);
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

    expect(await navigationLabels(tester), isNull);
  });

  Future<void> openKanban(WidgetTester tester) => openTab(tester, 'Kanban');

  /// The page in front: its index among the destinations. The shell's stack
  /// is the outermost one, and is offstage while a page is pushed over it.
  int selectedTab(WidgetTester tester) => tester
      .widget<IndexedStack>(
        find.byType(IndexedStack, skipOffstage: false).first,
      )
      .index!;

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

    await openTab(tester, 'Chat');
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

  group("the board's event stream", () {
    /// The `since` of each stream the board opened, and whether each is open.
    late List<int> opened;
    late List<bool> open;

    Future<void> pumpWithBoard(WidgetTester tester) async {
      kanbanPlugin(on: true);
      server
        ..on('GET', '/api/plugins/kanban/boards', kanbanBoardsBody([]))
        ..on(
          'GET',
          '/api/plugins/kanban/board',
          kanbanBoardBody([kanbanTaskRow(id: 't1')], latestEventId: 7),
        );
      opened = [];
      open = [];
      await pumpShell(
        tester,
        size: const Size(400, 800),
        kanbanBuilder: (_) => KanbanScreen(
          repository: KanbanRepository(server.client()),
          connect: ({required since, board}) async {
            final socket = StreamChannelController<String>();
            final i = opened.length;
            opened.add(since);
            open.add(true);
            socket.local.stream.listen(null, onDone: () => open[i] = false);
            return socket.foreign;
          },
        ),
      );
      await openKanban(tester);
    }

    Future<void> background(WidgetTester tester) async {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pumpAndSettle();
    }

    Future<void> foreground(WidgetTester tester) async {
      tester.binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
    }

    testWidgets('closes while Chat is in front and reopens with the board', (
      tester,
    ) async {
      await pumpWithBoard(tester);
      expect(open, [true]);

      await openTab(tester, 'Chat');
      expect(open, [false]);

      await openKanban(tester);
      expect(opened, [7, 7]);
      expect(open, [false, true]);
    });

    testWidgets('closes while the app is in the background', (tester) async {
      await pumpWithBoard(tester);

      await background(tester);
      expect(open, [false]);

      await foreground(tester);
      expect(open, [false, true]);
    });

    testWidgets('stays closed when the app comes back on Chat', (tester) async {
      await pumpWithBoard(tester);
      await openTab(tester, 'Chat');

      await background(tester);
      await foreground(tester);

      expect(open, [false]);
    });
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

  /// Opens [page] from the sidebar of a wide layout.
  Future<void> openInSidebar(WidgetTester tester, String page) async {
    await tester.tap(
      find.descendant(
        of: find.byType(ShellNavigation),
        matching: find.text(page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a route pushed over the shell after Kanban and Schedules '
      'were both opened animates without a hero clash', (tester) async {
    kanbanPlugin(on: true);
    cronRoutes(on: true);
    jobRoutes();
    server
      ..on('GET', '/api/plugins/kanban/boards', kanbanBoardsBody([]))
      ..on('GET', '/api/plugins/kanban/board', kanbanBoardBody([]))
      ..on('GET', '/api/profiles', {'profiles': <Object>[]});
    await pumpShell(
      tester,
      size: const Size(1400, 900),
      platform: TargetPlatform.android,
      kanbanBuilder: (_) => KanbanScreen(
        repository: KanbanRepository(server.client()),
        connect: ({required since, board}) async =>
            StreamChannelController<String>().foreign,
      ),
    );

    await openInSidebar(tester, 'Kanban');
    await openInSidebar(tester, 'Schedules');
    expect(find.byType(FloatingActionButton), findsWidgets);

    await tester.tap(find.byType(FloatingActionButton).hitTestable());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BlueprintGalleryScreen), findsOneWidget);
  });

  testWidgets('File > New (Command-N) adds what the page in front holds', (
    tester,
  ) async {
    kanbanPlugin(on: true);
    cronRoutes(on: true);
    jobRoutes();
    server
      ..on('GET', '/api/plugins/kanban/boards', kanbanBoardsBody([]))
      ..on('GET', '/api/plugins/kanban/board', kanbanBoardBody([]))
      ..on('GET', '/api/plugins/kanban/assignees', {'assignees': <String>[]})
      ..on('GET', '/api/plugins/kanban/model-options', {'providers': []})
      ..on('GET', '/api/profiles', {'profiles': <Object>[]});
    final commands = MacCommandRegistry();
    addTearDown(commands.dispose);
    await pumpShell(
      tester,
      size: const Size(1400, 900),
      commands: commands,
      kanbanBuilder: (_) => KanbanScreen(
        repository: KanbanRepository(server.client()),
        connect: ({required since, board}) async =>
            StreamChannelController<String>().foreign,
      ),
    );
    String? newTitle() => commands.handlerFor(MacCommand.newChat)?.title;

    expect(newTitle(), isNull, reason: 'Chat keeps the New Chat label');

    await openInSidebar(tester, 'Kanban');
    expect(newTitle(), 'New Task');
    expect(commands.invoke(MacCommand.newChat), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(KanbanCreateScreen), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await openInSidebar(tester, 'Schedules');
    expect(newTitle(), 'New Schedule');
    expect(commands.invoke(MacCommand.newChat), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(BlueprintGalleryScreen), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await openInSidebar(tester, 'Chat');
    expect(newTitle(), isNull);
  });

  group('Schedules', () {
    testWidgets('is offered without Kanban when the server has cron routes', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);

      await pumpShell(tester, size: const Size(400, 800));

      expect(await navigationLabels(tester), ['Chat', 'Schedules']);
    });

    testWidgets('sits next to Kanban when both are on', (tester) async {
      kanbanPlugin(on: true);
      cronRoutes(on: true);

      await pumpShell(tester, size: const Size(400, 800));

      expect(await navigationLabels(tester), ['Chat', 'Kanban', 'Schedules']);
    });

    testWidgets('is offered in the sidebar on a wide screen', (tester) async {
      kanbanPlugin(on: false);
      cronRoutes(on: true);

      await pumpShell(tester, size: const Size(1400, 900));

      expect(find.byType(ShellNavigation), findsOneWidget);
      expect(find.text('Schedules'), findsOneWidget);
    });

    testWidgets('is not offered by a server without the cron routes', (
      tester,
    ) async {
      kanbanPlugin(on: false);
      cronRoutes(on: false);

      await pumpShell(tester, size: const Size(400, 800));

      expect(await navigationLabels(tester), isNull);
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

      expect(find.text('Morning brief'), findsNothing);
      expect(await navigationLabels(tester), isNull);
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
      // A page the shell shows puts the shell's menu in its app bar.
      ?ShellMenu.button(context),
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
