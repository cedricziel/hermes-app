import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedule_detail.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/schedules/schedules_list.dart';
import 'package:hermes_app/src/schedules/schedules_screen.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart' show GroupedSwitchRow;
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stream_channel/stream_channel.dart';

import '../support/cron_fixtures.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_notification_service.dart';
import '../support/fake_share_inbox.dart';
import '../support/kanban_fixtures.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// Scheduled tasks: the navigation that offers them, the list, one task in
/// full (pause, run now, delete), and creating and editing a task.
void main() {
  late FakeHermesServer server;
  late _Cron cron;

  final fixedNow = DateTime.utc(2026, 9, 20, 12);

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'work'), profileRow(name: 'home')]),
      )
      ..on('GET', '/api/cron/blueprints', _blueprints)
      ..on('GET', '/api/cron/delivery-targets', _targets)
      ..on('GET', '/api/model/options', {
        'providers': [
          {
            'slug': 'nous',
            'name': 'Nous Portal',
            'models': ['hermes-4-405b', 'hermes-4-70b'],
          },
          {
            'slug': 'openrouter',
            'name': 'OpenRouter',
            'models': ['anthropic/claude-opus-4', 'openai/gpt-5.1'],
          },
        ],
      })
      ..on('GET', '/api/dashboard/plugins', <Object?>[])
      ..on('GET', '/api/plugins/kanban/boards', kanbanBoardsBody(_boards))
      ..on('GET', '/api/plugins/kanban/board', kanbanBoardBody(_tasks))
      ..on('GET', '/api/plugins/kanban/assignees', {
        'assignees': ['coder', 'writer'],
      });
    cron = _Cron(server, now: fixedNow)
      ..rows.addAll(_demoJobs(fixedNow))
      ..runs.addAll(_demoRuns(fixedNow))
      ..serve();
  });

  // The schedules screen on its own, on the clock the fixtures were made for.
  Future<void> pumpSchedules(
    WidgetTester tester,
    ScreenshotRecorder shots, {
    required Size size,
    Brightness brightness = Brightness.light,
  }) async {
    final controller = SchedulesController(
      repository: HermesCronRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
      now: () => fixedNow,
    );
    addTearDown(controller.dispose);
    await _mount(
      tester,
      shots,
      SchedulesScreen(controller: controller, onOpenRun: (_, _) {}),
      size: size,
      brightness: brightness,
      providers: [
        Provider<HermesRepositories?>.value(
          value: HermesRepositories(server.client()),
        ),
      ],
    );
  }

  group('app shell', () {
    // The shell reads the real clock, so the jobs are made for it.
    setUp(() {
      _Cron(server, now: DateTime.now())
        ..rows.addAll(_demoJobs(DateTime.now()))
        ..runs.addAll(_demoRuns(DateTime.now()))
        ..serve();
    });

    void setKanban(bool on) => server.on(
      'GET',
      '/api/dashboard/plugins',
      on
          ? [
              {'name': 'kanban'},
            ]
          : <Object?>[],
    );

    void setCron(bool on) => server.on(
      'GET',
      '/api/cron/delivery-targets',
      _targets,
      status: on ? 200 : 404,
    );

    Future<void> pumpShell(
      WidgetTester tester,
      ScreenshotRecorder shots, {
      required Size size,
      Brightness brightness = Brightness.light,
      TargetPlatform? platform,
    }) => _mount(
      tester,
      shots,
      AppShell(
        plugins: HermesPluginsRepository(server.client().raw),
        cron: HermesCronRepository(server.client().raw),
        kanbanBuilder: (_) => KanbanScreen(
          repository: KanbanRepository(server.client()),
          connect: ({required since, board}) async =>
              StreamChannelController<String>().foreign,
        ),
      ),
      size: size,
      brightness: brightness,
      platform: platform,
      providers: [
        Provider<NotificationService>.value(value: FakeNotificationService()),
      ],
    );

    // A phone keeps the destinations in a drawer: Chat's own, or the shell's
    // on another page. A compact Mac window opens its sidebar over the page.
    Future<void> openMenu(WidgetTester tester) async {
      final drawer = find.byTooltip('Open navigation menu').hitTestable();
      await tester.tap(
        drawer.evaluate().isNotEmpty
            ? drawer.first
            : find.byKey(const Key('mac-sidebar-toggle')).hitTestable().first,
      );
      await _settle(tester);
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
      await _settle(tester);
    }

    Future<void> openTab(WidgetTester tester, String label) async {
      final rows = find.descendant(
        of: find.byType(ShellNavigation),
        matching: find.text(label),
      );
      if (rows.hitTestable().evaluate().isEmpty) await openMenu(tester);
      await tester.tap(rows.hitTestable().first);
      await _settle(tester);
    }

    // Comes back to the foreground, which is when the shell asks the server
    // again what it offers.
    Future<void> resume(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);
    }

    // The destinations the navigation offers. A phone keeps them in a
    // drawer, so it is opened to look and closed again.
    Future<void> expectDestinations(
      WidgetTester tester, {
      required bool kanban,
      required bool schedules,
    }) async {
      if (!kanban && !schedules) {
        // Chat alone has nowhere to navigate to.
        expect(find.byType(ShellNavigation), findsNothing);
        expect(find.text('Kanban'), findsNothing);
        expect(find.text('Schedules'), findsNothing);
        return;
      }
      final closed = find.byType(ShellNavigation).evaluate().isEmpty;
      if (closed) await openMenu(tester);
      Finder row(String label) => find.descendant(
        of: find.byType(ShellNavigation),
        matching: find.text(label),
      );
      expect(row('Chat'), findsOneWidget, reason: 'Chat is always offered');
      expect(
        row('Kanban'),
        kanban ? findsOneWidget : findsNothing,
        reason: 'Kanban follows the server',
      );
      expect(
        row('Schedules'),
        schedules ? findsOneWidget : findsNothing,
        reason: 'Schedules follows the server',
      );
      if (closed) await closeMenu(tester);
    }

    // The chat's own page: its thread list on a phone.
    void expectOnChat() {
      expect(find.text("Summarize last night's run logs"), findsOneWidget);
      expect(_row('Morning brief'), findsNothing);
      expect(find.text('Search tasks'), findsNothing);
    }

    void expectOnSchedules() {
      expect(_row('Morning brief'), findsOneWidget);
      expect(_row('Price watch'), findsOneWidget);
      expect(find.text('Search tasks'), findsNothing);
    }

    // A phone shows the Running column's task, a desktop the Todo one's.
    void expectOnKanban(String task) {
      expect(find.text(task), findsOneWidget);
      expect(find.text('Search tasks'), findsOneWidget);
      expect(_row('Morning brief'), findsNothing);
    }

    testWidgets('phone: Chat, Kanban and Schedules', (tester) async {
      setKanban(true);
      final shots = ScreenshotRecorder('schedules-shell-phone');
      await pumpShell(tester, shots, size: phoneSize);
      await shots.capture(tester, 'chat-without-a-bottom-bar');
      expectOnChat();
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(ShellNavigation), findsNothing);

      await openMenu(tester);
      await shots.capture(tester, 'chat-drawer-with-destinations');
      await expectDestinations(tester, kanban: true, schedules: true);

      await openTab(tester, 'Schedules');
      await shots.capture(tester, 'schedules-tab');
      expectOnSchedules();
      expect(_row('Weekly digest'), findsOneWidget);
      await openMenu(tester);
      await shots.capture(tester, 'schedules-drawer');
      await expectDestinations(tester, kanban: true, schedules: true);
      await closeMenu(tester);

      await _openTile(tester, 'Price watch');
      await shots.capture(tester, 'task-opened-over-the-tabs');
      expect(find.text('Price watch'), findsOneWidget);
      expect(find.text('Provider timeout'), findsOneWidget);
      expect(find.text('Run now'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      await popRoute(tester);

      await openTab(tester, 'Chat');
      await shots.capture(tester, 'back-on-chat');
      expectOnChat();

      // Only now: with both pages built, pushing a route trips the
      // duplicate FloatingActionButton hero assertion.
      await openTab(tester, 'Kanban');
      await shots.capture(tester, 'kanban-tab');
      expectOnKanban('Migrate webhooks');
      await openMenu(tester);
      await shots.capture(tester, 'kanban-drawer');
      await expectDestinations(tester, kanban: true, schedules: true);
    });

    // A tablet held upright is below the wide breakpoint, so it gets the
    // phone's drawer; turned sideways it gets the desktop's sidebar.
    for (final (flow, size) in [
      ('tablet-portrait', const Size(820, 1180)),
      ('tablet-landscape', const Size(1180, 820)),
    ]) {
      testWidgets('$flow: Chat, Kanban and Schedules', (tester) async {
        setKanban(true);
        final shots = ScreenshotRecorder('schedules-shell-$flow');
        await pumpShell(tester, shots, size: size);
        await shots.capture(tester, 'chat');
        final wide = size.width >= kWideLayoutBreakpoint;
        // Wide: the sidebar is always there. Narrow: only the drawer has it.
        expect(
          find.byType(ShellNavigation),
          wide ? findsOneWidget : findsNothing,
        );
        if (!wide) {
          expectOnChat();
          await openMenu(tester);
          await shots.capture(tester, 'chat-drawer');
        }
        await expectDestinations(tester, kanban: true, schedules: true);
        await openTab(tester, 'Schedules');
        await shots.capture(tester, 'schedules');
        expectOnSchedules();
        if (!wide) {
          await openMenu(tester);
          await shots.capture(tester, 'schedules-drawer');
          await expectDestinations(tester, kanban: true, schedules: true);
        }
      });
    }

    testWidgets('phone: the tab follows what the server has', (tester) async {
      setCron(false);
      setKanban(false);
      final shots = ScreenshotRecorder('schedules-shell-phone-detection');
      await pumpShell(tester, shots, size: phoneSize);
      await shots.capture(tester, 'server-has-neither');
      await expectDestinations(tester, kanban: false, schedules: false);

      setCron(true);
      await resume(tester);
      await shots.capture(tester, 'cron-appears');
      await expectDestinations(tester, kanban: false, schedules: true);

      await openTab(tester, 'Schedules');
      await shots.capture(tester, 'schedules-open');
      expectOnSchedules();

      setKanban(true);
      await resume(tester);
      await shots.capture(tester, 'kanban-appears-too');
      expectOnSchedules();
      await expectDestinations(tester, kanban: true, schedules: true);

      setCron(false);
      await resume(tester);
      await shots.capture(tester, 'cron-gone-back-to-chat');
      expectOnChat();
      await expectDestinations(tester, kanban: true, schedules: false);
    });

    testWidgets('desktop: sidebar with three destinations', (tester) async {
      setKanban(true);
      final shots = ScreenshotRecorder('schedules-shell-desktop');
      await pumpShell(tester, shots, size: desktopSize);
      await shots.capture(tester, 'chat-with-sidebar-navigation');
      expect(find.text('Message Hermes…'), findsOneWidget);
      await expectDestinations(tester, kanban: true, schedules: true);

      await openTab(tester, 'Schedules');
      await shots.capture(tester, 'schedules-tab');
      expectOnSchedules();
      expect(find.text('Message Hermes…'), findsNothing);
      // The first task is open beside the list.
      expect(_inDetail('Run now'), findsOneWidget);
      expect(_inDetail('Failed 5 min ago'), findsOneWidget);

      await openTab(tester, 'Kanban');
      await shots.capture(tester, 'kanban-tab');
      expectOnKanban('Investigate flaky test');
      await expectDestinations(tester, kanban: true, schedules: true);
    });

    testWidgets('desktop: the tab follows what the server has', (tester) async {
      setCron(false);
      setKanban(false);
      final shots = ScreenshotRecorder('schedules-shell-desktop-detection');
      await pumpShell(tester, shots, size: desktopSize);
      await shots.capture(tester, 'server-has-neither');
      await expectDestinations(tester, kanban: false, schedules: false);

      setCron(true);
      await resume(tester);
      await shots.capture(tester, 'cron-appears');
      await expectDestinations(tester, kanban: false, schedules: true);

      await openTab(tester, 'Schedules');
      expectOnSchedules();
      setCron(false);
      await resume(tester);
      await shots.capture(tester, 'cron-gone-back-to-chat');
      expect(find.text('Message Hermes…'), findsOneWidget);
      expect(_row('Morning brief'), findsNothing);
      await expectDestinations(tester, kanban: false, schedules: false);
    });

    // The Mac window at the sizes the Mac design covers.
    for (final (flow, size, brightness) in [
      ('large', const Size(1160, 760), Brightness.light),
      ('medium', const Size(900, 700), Brightness.light),
      ('compact', const Size(680, 640), Brightness.light),
      ('large-dark', const Size(1160, 760), Brightness.dark),
    ]) {
      testWidgets('macOS $flow: Schedules', (tester) async {
        final shots = ScreenshotRecorder('schedules-shell-mac-$flow');
        await pumpShell(
          tester,
          shots,
          size: size,
          brightness: brightness,
          platform: TargetPlatform.macOS,
        );
        await openTab(tester, 'Schedules');
        await shots.capture(tester, 'schedules');
        // The toolbar names the scope and counts the jobs.
        expect(find.text('7 jobs'), findsOneWidget);
        expect(find.text('This profile'), findsOneWidget);
        expect(find.text('All profiles'), findsOneWidget);
        expect(_row('Price watch'), findsOneWidget);
        // The first task, a failing one, is open beside the list.
        expect(_inDetail('Failed 5 min ago'), findsOneWidget);
        expect(_inDetail('Edit'), findsOneWidget);
        expect(_inDetail('Run now'), findsOneWidget);

        await _openTile(tester, 'Morning brief');
        await shots.capture(tester, 'healthy-job-with-runs');
        expect(_inDetail('Last run succeeded 2 h ago'), findsOneWidget);
        // The compact window's runs are below the fold.
        if (flow != 'compact') {
          expect(_inDetail('Recent runs'), findsOneWidget);
          expect(_inDetail('Running'), findsOneWidget);
          expect(_inDetail('42 s'), findsOneWidget);
          expect(_inDetail('1 min 40 s'), findsOneWidget);
        }
        expect(_inDetail('web-search'), findsOneWidget);

        await _openTile(tester, 'Weekly digest');
        await shots.capture(tester, 'paused-job');
        expect(_inRow('Weekly digest', 'Paused'), findsOneWidget);
        expect(_inDetail('Paused'), findsOneWidget);
        expect(_inDetail('No runs yet'), findsOneWidget);
        expect(_inDetail('home'), findsOneWidget);
        expect(_inDetail('Last run succeeded 2 h ago'), findsNothing);

        await tester.tap(find.text('All profiles'));
        await _settle(tester);
        await shots.capture(tester, 'all-profiles');
        // Every profile's jobs, each naming its profile.
        expect(
          _inRow('Morning brief', 'Weekdays at 08:00 · Local · work'),
          findsOneWidget,
        );
        expect(
          _inRow('Weekly digest', 'Mondays at 09:00 · Local · home'),
          findsOneWidget,
        );
      });
    }

    for (final (flow, size) in [
      ('schedules-shell-phone-dark', phoneSize),
      ('schedules-shell-desktop-dark', desktopSize),
    ]) {
      testWidgets('$flow: Schedules', (tester) async {
        setKanban(true);
        final shots = ScreenshotRecorder(flow);
        await pumpShell(tester, shots, size: size, brightness: Brightness.dark);
        await shots.capture(tester, 'chat');
        final wide = size.width >= kWideLayoutBreakpoint;
        if (!wide) {
          expectOnChat();
          await openMenu(tester);
          await shots.capture(tester, 'chat-drawer');
        }
        await expectDestinations(tester, kanban: true, schedules: true);
        await openTab(tester, 'Schedules');
        await shots.capture(tester, 'schedules');
        expectOnSchedules();
        expect(_inRow('Weekly digest', 'Paused'), findsOneWidget);
        expect(
          _inRow('Price watch', 'Failed 40 min ago · Provider timeout'),
          findsOneWidget,
        );
      });
    }
  });

  group('list', () {
    testWidgets('phone: every state a task can be in', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-list');
      await pumpSchedules(tester, shots, size: phoneSize);
      await shots.capture(tester, 'list-top');
      _expectEveryTask(tester);
      expect(find.text('work'), findsOneWidget, reason: 'the profile shown');
      expect(find.text(_longName).hitTestable(), findsOneWidget);
      expect(find.text('Weekly digest').hitTestable(), findsOneWidget);

      final list = find.byType(ListView);
      await tester.drag(list, const Offset(0, -500));
      await _settle(tester);
      await shots.capture(tester, 'list-middle');
      _expectEveryTask(tester);

      await tester.drag(list, const Offset(0, -3000));
      await _settle(tester);
      await shots.capture(tester, 'list-bottom');
      _expectEveryTask(tester);
      expect(find.text('Weekly digest').hitTestable(), findsOneWidget);

      await _filter(tester, 'Failing (2)', shots: shots);
      await shots.capture(tester, 'filter-failing');
      _expectOnlyTasks(['Price watch', _longName]);
      expect(_rowSwitch(tester, 'Price watch').value, isTrue);

      await _filter(tester, 'Paused', from: 'Failing (2)');
      await shots.capture(tester, 'filter-paused');
      _expectOnlyTasks(['Weekly digest']);
      expect(_rowSwitch(tester, 'Weekly digest').value, isFalse);

      await _filter(tester, 'All tasks', from: 'Paused');
      _expectEveryTask(tester);
      await _tap(tester, find.byKey(const Key('settings-subtitle-menu')));
      await shots.capture(tester, 'scope-menu');
      expect(_menuItem('work (active)'), findsOneWidget);
      expect(_menuItem('All profiles'), findsOneWidget);
      await _tap(tester, _menuItem('All profiles'));
      await shots.capture(tester, 'all-profiles');
      expect(find.text('All profiles'), findsOneWidget);
      expect(find.text('work'), findsNothing);
      // Every profile's tasks, each naming its profile.
      expect(
        _inRow('Weekly digest', 'Mondays at 09:00 · Local · home'),
        findsOneWidget,
      );
      expect(
        _inRow('Morning brief', 'Weekdays at 08:00 · Local · work'),
        findsOneWidget,
      );
      expect(
        server.requestsTo('GET', '/api/cron/jobs').last.queryParameters,
        containsPair('profile', 'all'),
      );
    });

    testWidgets('phone: pausing from the list, and a refusal', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-list-pause');
      await pumpSchedules(tester, shots, size: phoneSize);
      final morning = find.descendant(
        of: find.widgetWithText(JobTile, 'Morning brief'),
        matching: find.byType(Switch),
      );

      expect(_rowSwitch(tester, 'Morning brief').value, isTrue);

      await _reveal(tester, morning, _jobList);
      await tester.tap(morning);
      await _settle(tester);
      await shots.capture(tester, 'paused');
      expect(_rowSwitch(tester, 'Morning brief').value, isFalse);
      expect(_inRow('Morning brief', 'Paused'), findsOneWidget);
      expect(find.textContaining('Next run in'), findsNWidgets(4));
      // A paused task sinks below the ones that run.
      expect(_listedAbove(tester, 'Standup notes', 'Morning brief'), isTrue);
      expect(
        server.requestsTo('POST', '/api/cron/jobs/job1/pause'),
        hasLength(1),
      );

      await _reveal(tester, morning, _jobList);
      await tester.tap(morning);
      await _settle(tester);
      await shots.capture(tester, 'resumed');
      expect(_rowSwitch(tester, 'Morning brief').value, isTrue);
      expect(
        _inRow('Morning brief', 'Last run succeeded 2 h ago · Next run in 1 h'),
        findsOneWidget,
      );
      expect(_listedAbove(tester, 'Morning brief', 'Standup notes'), isTrue);
      expect(
        server.requestsTo('POST', '/api/cron/jobs/job1/resume'),
        hasLength(1),
      );

      server.on('POST', '/api/cron/jobs/job1/pause', {}, status: 500);
      await _reveal(tester, morning, _jobList);
      await tester.tap(morning);
      await _frames(tester, 600);
      await shots.capture(tester, 'refused');
      // The refusal is told and the switch stays on.
      expect(find.text('Could not pause “Morning brief”'), findsOneWidget);
      expect(_rowSwitch(tester, 'Morning brief').value, isTrue);
      expect(_inRow('Morning brief', 'Paused'), findsNothing);
    });

    testWidgets('phone: refresh fails with a list already on screen', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('schedules-phone-list-refresh-failed');
      await pumpSchedules(tester, shots, size: phoneSize);
      server.on('GET', '/api/cron/jobs', {}, status: 500);
      await tester.tap(find.byTooltip('Refresh'));
      await _settle(tester);
      await shots.capture(tester, 'error-note');
      // The failure is told above the tasks, which stay.
      expect(find.text('The server answered 500'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      _expectEveryTask(tester);
    });

    testWidgets('phone: loading, empty, failed, nothing matches', (
      tester,
    ) async {
      final held = Completer<FakeResponse>();
      server.onRequest('GET', '/api/cron/jobs', (_) => held.future);
      final shots = ScreenshotRecorder('schedules-phone-list-states');
      await pumpSchedules(tester, shots, size: phoneSize);
      await shots.capture(tester, 'loading');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(JobTile), findsNothing);
      expect(find.text('No scheduled tasks'), findsNothing);

      held.complete((status: 200, body: <Object?>[]));
      await _settle(tester);
      await shots.capture(tester, 'empty');
      expect(find.text('No scheduled tasks'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(JobTile), findsNothing);

      server.on('GET', '/api/cron/jobs', {}, status: 500);
      await tester.tap(find.byTooltip('Refresh'));
      await _settle(tester);
      await shots.capture(tester, 'still-empty-after-failed-refresh');
      expect(find.text('The server answered 500'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No scheduled tasks'), findsOneWidget);

      cron
        ..rows.removeWhere((r) => r['state'] != 'scheduled')
        ..serve();
      await tester.tap(find.byTooltip('Refresh'));
      await _settle(tester);
      await _filter(tester, 'Paused');
      await shots.capture(tester, 'no-match-for-filter');
      // Only scheduled tasks are left, and none of them is paused.
      expect(find.text('No tasks match this filter'), findsOneWidget);
      expect(find.text('No scheduled tasks'), findsNothing);
      expect(find.byType(JobTile), findsNothing);
    });

    testWidgets('phone: the first load fails, then works', (tester) async {
      server.on('GET', '/api/cron/jobs', {}, status: 500);
      final shots = ScreenshotRecorder('schedules-phone-list-load-failed');
      await pumpSchedules(tester, shots, size: phoneSize);
      await shots.capture(tester, 'load-failed');
      expect(find.text('The server answered 500'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
      expect(find.byType(JobTile), findsNothing);

      server.on('GET', '/api/cron/jobs', {}, status: 502);
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      await shots.capture(tester, 'load-failed-again');
      expect(find.text('The server answered 502'), findsOneWidget);
      expect(find.text('The server answered 500'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);

      server.on('GET', '/api/cron/jobs', [
        for (final r in cron.rows) {...r},
      ]);
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      await shots.capture(tester, 'loaded');
      expect(find.text('Try again'), findsNothing);
      expect(find.textContaining('The server answered'), findsNothing);
      _expectEveryTask(tester);
    });

    testWidgets('desktop: list and detail side by side', (tester) async {
      final shots = ScreenshotRecorder('schedules-desktop-list');
      final semantics = tester.ensureSemantics();
      await pumpSchedules(tester, shots, size: desktopSize);
      await shots.capture(tester, 'first-task-selected');
      _expectEveryTask(tester);
      // The first task is open beside the list, and marked there.
      expect(_selected(tester, _longName), isTrue);
      expect(_selected(tester, 'Price watch'), isFalse);
      expect(_inDetail(_longName), findsOneWidget);
      expect(_inDetail('Failed 5 min ago'), findsOneWidget);
      expect(_inDetail('Run now'), findsOneWidget);
      expect(find.text('Select a task'), findsNothing);

      await _openTile(tester, 'Price watch');
      await shots.capture(tester, 'failed-task');
      expect(_selected(tester, 'Price watch'), isTrue);
      expect(_selected(tester, _longName), isFalse);
      expect(_inDetail('Price watch'), findsOneWidget);
      expect(_inDetail('Failed 40 min ago'), findsOneWidget);
      expect(_inDetail('Provider timeout'), findsOneWidget);
      expect(_inDetail('Every 30 minutes'), findsOneWidget);
      expect(_inDetail('Pause'), findsOneWidget);

      await _openTile(tester, 'Weekly digest');
      await shots.capture(tester, 'paused-task');
      expect(_selected(tester, 'Weekly digest'), isTrue);
      expect(_inDetail('Weekly digest'), findsOneWidget);
      expect(_inDetail('Paused'), findsOneWidget);
      expect(_inDetail('Resume'), findsOneWidget);
      expect(_inDetail('Pause'), findsNothing);
      expect(_inDetail('Mondays at 09:00'), findsOneWidget);

      await _openTile(tester, _longName);
      await shots.capture(tester, 'long-task');
      expect(_selected(tester, _longName), isTrue);
      expect(_inDetail(_longName), findsOneWidget);
      expect(_inDetail('*/7 9-17 * * 1-5'), findsOneWidget);
      expect(_inDetail('Failed 5 min ago'), findsOneWidget);

      await _filter(tester, 'Failing (2)');
      await shots.capture(tester, 'filter-failing');
      _expectOnlyTasks(['Price watch', _longName]);
      // The open task stays open when it still matches.
      expect(_inDetail(_longName), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('desktop: empty, failed and nothing selected', (tester) async {
      server.on('GET', '/api/cron/jobs', <Object?>[]);
      final shots = ScreenshotRecorder('schedules-desktop-list-states');
      await pumpSchedules(tester, shots, size: desktopSize);
      await shots.capture(tester, 'empty');
      expect(find.text('No scheduled tasks'), findsOneWidget);
      expect(find.text('Select a task'), findsOneWidget);
      expect(find.byType(JobTile), findsNothing);

      server.on('GET', '/api/cron/jobs', {}, status: 500);
      await tester.tap(find.byTooltip('Refresh'));
      await _settle(tester);
      await shots.capture(tester, 'refresh-failed');
      expect(find.text('The server answered 500'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No scheduled tasks'), findsOneWidget);
      expect(find.text('Select a task'), findsOneWidget);
    });

    testWidgets('desktop: the first load fails', (tester) async {
      server.on('GET', '/api/cron/jobs', {}, status: 500);
      final shots = ScreenshotRecorder('schedules-desktop-list-load-failed');
      await pumpSchedules(tester, shots, size: desktopSize);
      await shots.capture(tester, 'load-failed');
      expect(find.text('The server answered 500'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
      expect(find.text('Select a task'), findsOneWidget);
      expect(find.byType(JobTile), findsNothing);
    });

    for (final (flow, size) in [
      ('schedules-phone-dark', phoneSize),
      ('schedules-desktop-dark', desktopSize),
    ]) {
      testWidgets('$flow: list and detail', (tester) async {
        final shots = ScreenshotRecorder(flow);
        await pumpSchedules(
          tester,
          shots,
          size: size,
          brightness: Brightness.dark,
        );
        await shots.capture(tester, 'list');
        _expectEveryTask(tester);

        await _openTile(tester, 'Price watch');
        await shots.capture(tester, 'failed-task');
        expect(_inDetail('Failed 40 min ago'), findsOneWidget);
        expect(_inDetail('Provider timeout'), findsOneWidget);
        expect(_inDetail('Run now'), findsOneWidget);
        expect(_inDetail('Every 30 minutes'), findsOneWidget);

        if (size == phoneSize) {
          await tester.drag(find.byType(ScheduleDetail), const Offset(0, -700));
          await _settle(tester);
          await shots.capture(tester, 'failed-task-lower');
          expect(_inDetail('Delete task'), findsOneWidget);
          expect(_inDetail('Run history'), findsOneWidget);
          expect(_inDetail('Failed · 20 s'), findsOneWidget);
          expect(_inDetail('Unfinished'), findsOneWidget);
        }
      });
    }
  });

  group('detail', () {
    Finder detailList() => find.descendant(
      of: find.byType(ScheduleDetail),
      matching: find.byType(ListView),
    );

    testWidgets('phone: run now, pause, resume, delete', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-detail');
      await pumpSchedules(tester, shots, size: phoneSize);
      await _openTile(tester, 'Morning brief');
      await shots.capture(tester, 'running-task');
      expect(find.text('Morning brief'), findsOneWidget);
      expect(find.text('Last run succeeded 2 h ago'), findsOneWidget);
      expect(find.text('Next run in 3 h'), findsOneWidget);
      expect(find.text('Run now'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Resume'), findsNothing);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Weekdays at 08:00'), findsOneWidget);
      expect(find.text('web-search'), findsOneWidget);
      expect(find.text('hermes-4'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('work'), findsOneWidget);
      expect(_muted(tester), isFalse);

      await tester.tap(find.text('Pause'));
      await _settle(tester);
      await shots.capture(tester, 'paused');
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
      expect(find.textContaining('Next run in'), findsNothing);
      expect(
        server.requestsTo('POST', '/api/cron/jobs/job1/pause'),
        hasLength(1),
      );

      await tester.tap(find.text('Resume'));
      await _settle(tester);
      await shots.capture(tester, 'resumed');
      expect(find.text('Paused'), findsNothing);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Resume'), findsNothing);
      expect(find.text('Next run in 1 h'), findsOneWidget);
      expect(
        server.requestsTo('POST', '/api/cron/jobs/job1/resume'),
        hasLength(1),
      );

      await tester.tap(find.text('Run now'));
      await _frames(tester, 400);
      await shots.capture(tester, 'run-requested');
      expect(find.text('Run requested'), findsOneWidget);
      expect(
        server.requestsTo('POST', '/api/cron/jobs/job1/trigger'),
        hasLength(1),
      );
      await _frames(tester, 6000);

      await tester.drag(detailList(), const Offset(0, -3000));
      await _settle(tester);
      await shots.capture(tester, 'run-history-and-delete');
      expect(find.text('Run history'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('42 s'), findsOneWidget);
      expect(find.text('1 min 40 s'), findsOneWidget);
      expect(find.text('Delete task'), findsOneWidget);

      await tester.tap(find.text('Delete task'));
      await _settle(tester);
      await shots.capture(tester, 'delete-confirm');
      expect(find.text('Delete this task?'), findsOneWidget);
      expect(
        find.text(
          '“Morning brief” will no longer run. Its past runs stay as chats.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      await shots.capture(tester, 'delete-cancelled');
      expect(find.text('Delete this task?'), findsNothing);
      expect(find.text('Delete task'), findsOneWidget);
      expect(find.text('Run history'), findsOneWidget);
      expect(server.requestsTo('DELETE', '/api/cron/jobs/job1'), isEmpty);

      await tester.tap(find.text('Delete task'));
      await _settle(tester);
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      await shots.capture(tester, 'deleted-back-on-list');
      // Back on the list, without the deleted task.
      expect(server.requestsTo('DELETE', '/api/cron/jobs/job1'), hasLength(1));
      expect(find.text('Delete this task?'), findsNothing);
      expect(find.text('Run history'), findsNothing);
      expect(_row('Morning brief'), findsNothing);
      expect(find.byType(JobTile), findsNWidgets(6));
      expect(_row('Price watch'), findsOneWidget);
    });

    testWidgets('phone: refused pause, run now and delete', (tester) async {
      server
        ..on('POST', '/api/cron/jobs/price/pause', {}, status: 500)
        ..on('POST', '/api/cron/jobs/price/trigger', {}, status: 500)
        ..on('DELETE', '/api/cron/jobs/price', {}, status: 500);
      final shots = ScreenshotRecorder('schedules-phone-detail-refused');
      await pumpSchedules(tester, shots, size: phoneSize);
      await _openTile(tester, 'Price watch');

      await tester.tap(find.text('Pause'));
      await _frames(tester, 400);
      await shots.capture(tester, 'pause-refused');
      // Told, and the task is still the same: not paused.
      expect(find.text('Could not pause “Price watch”'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Resume'), findsNothing);
      expect(find.text('Paused'), findsNothing);
      await _frames(tester, 5000);

      await tester.tap(find.text('Run now'));
      await _frames(tester, 400);
      await shots.capture(tester, 'run-refused');
      expect(find.text('Could not start “Price watch”'), findsOneWidget);
      expect(find.text('Run requested'), findsNothing);
      await _frames(tester, 5000);

      await tester.drag(detailList(), const Offset(0, -3000));
      await _settle(tester);
      await tester.tap(find.text('Delete task'));
      await _settle(tester);
      await tester.tap(find.text('Delete'));
      await _frames(tester, 400);
      await shots.capture(tester, 'delete-refused');
      // Told, and the task is still there to open.
      expect(find.text('Could not delete “Price watch”'), findsOneWidget);
      expect(find.text('Delete this task?'), findsNothing);
      expect(find.text('Delete task'), findsOneWidget);
      expect(find.text('Run history'), findsOneWidget);
    });

    testWidgets('phone: a failed task, a delivery failure, a long one', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('schedules-phone-detail-variants');
      await pumpSchedules(tester, shots, size: phoneSize);

      // [top] is checked where the task opens, [lower] after scrolling to
      // the end of it.
      Future<void> open(
        String title,
        String step, {
        required void Function() top,
        required void Function() lower,
      }) async {
        await _openTile(tester, title);
        await shots.capture(tester, step);
        expect(find.text(title), findsOneWidget);
        top();
        await tester.drag(detailList(), const Offset(0, -3000));
        await _settle(tester);
        await shots.capture(tester, '$step-lower');
        expect(find.text('Delete task'), findsOneWidget);
        lower();
        await popRoute(tester);
        expect(_row(title), findsOneWidget);
      }

      await open(
        'Price watch',
        'failed',
        top: () {
          expect(find.text('Failed 40 min ago'), findsOneWidget);
          expect(find.text('Provider timeout'), findsOneWidget);
          expect(find.text('Next run in 20 min'), findsOneWidget);
          expect(find.text('Every 30 minutes'), findsOneWidget);
        },
        lower: () {
          expect(find.text('Run history'), findsOneWidget);
          expect(find.text('Failed · 20 s'), findsOneWidget);
          expect(find.text('Unfinished'), findsOneWidget);
        },
      );
      await open(
        'Standup notes',
        'delivery-failed',
        top: () {
          expect(find.text('Ran, but delivery failed 5 h ago'), findsOneWidget);
          expect(find.text('Telegram: chat not found'), findsOneWidget);
          expect(find.text('Telegram'), findsOneWidget);
          expect(find.text('Failed 5 h ago'), findsNothing);
        },
        lower: () {
          expect(find.text('Run history'), findsOneWidget);
          expect(find.text('11 min 40 s'), findsOneWidget);
        },
      );
      await open(
        _longName,
        'long',
        top: () {
          expect(find.text('Failed 5 min ago'), findsOneWidget);
          expect(find.text('*/7 9-17 * * 1-5'), findsOneWidget);
          expect(
            find.text('github, pr-review, summarise, discord-post'),
            findsOneWidget,
          );
          expect(find.text('hermes-4-long-context-preview'), findsOneWidget);
          expect(find.text('Discord'), findsOneWidget);
        },
        lower: () {
          expect(find.text('No runs yet'), findsOneWidget);
        },
      );
      await open(
        'Weekly digest',
        'paused',
        top: () {
          expect(find.text('Paused'), findsOneWidget);
          expect(find.text('Resume'), findsOneWidget);
          expect(find.text('Pause'), findsNothing);
          expect(find.text('Mondays at 09:00'), findsOneWidget);
          expect(find.text('home'), findsOneWidget);
          expect(find.textContaining('Next run'), findsNothing);
        },
        lower: () {
          expect(find.text('No runs yet'), findsOneWidget);
        },
      );
      await open(
        'Renew the TLS certificate',
        'completed',
        top: () {
          expect(find.text('Completed'), findsOneWidget);
          expect(find.text('once on 2026-09-18 09:00'), findsOneWidget);
          // Nothing left to pause or resume, but it can run again.
          expect(find.text('Pause'), findsNothing);
          expect(find.text('Resume'), findsNothing);
          expect(find.text('Run now'), findsOneWidget);
          expect(find.text('Edit'), findsOneWidget);
        },
        lower: () {
          expect(find.text('No runs yet'), findsOneWidget);
        },
      );
      // A task without a name is titled by what it does.
      await open(
        'Check the build and tell me',
        'no-name',
        top: () {
          expect(find.text('Not run yet'), findsOneWidget);
          expect(find.text('Next run in 6 h'), findsOneWidget);
          expect(find.text('Every 6 hours'), findsOneWidget);
        },
        lower: () {
          expect(find.text('No runs yet'), findsOneWidget);
        },
      );
    });

    testWidgets('phone: a task Hermes blocked before it ran', (tester) async {
      cron
        ..rows.add(
          cronJobRow(
            id: 'inbox',
            name: 'Inbox digest',
            prompt: 'Summarise the unread mail from today.',
            lastRunAt: _iso(fixedNow.subtract(const Duration(hours: 3))),
            lastStatus: 'blocked_config',
            lastError:
                "[blocked_config:silent] attached skill 'mail-tools' is not "
                'ready: missing credential file mail_token.json',
            nextRunAt: _iso(fixedNow.add(const Duration(hours: 18))),
            skills: ['mail-tools'],
          ),
        )
        ..serve();
      final shots = ScreenshotRecorder('schedules-phone-detail-blocked');
      await pumpSchedules(tester, shots, size: phoneSize);

      await _openTile(tester, 'Inbox digest');
      await shots.capture(tester, 'blocked');
      expect(find.text('Failed 3 h ago'), findsOneWidget);
      expect(
        find.text(
          "attached skill 'mail-tools' is not ready: missing credential file "
          'mail_token.json',
        ),
        findsOneWidget,
      );
      expect(find.text('mail-tools'), findsOneWidget);
      expect(find.text('Next run in 18 h'), findsOneWidget);
      await tester.drag(detailList(), const Offset(0, -3000));
      await _settle(tester);
      await shots.capture(tester, 'blocked-run-history');
      expect(find.text('Run history'), findsOneWidget);
      expect(
        find.text(
          'Hermes blocked this task before it could start, so no run was '
          'recorded. It tries again at the next scheduled time.',
        ),
        findsOneWidget,
      );

      expect(find.text('No runs yet'), findsNothing);
      expect(find.textContaining('blocked this task'), findsOneWidget);
    });

    testWidgets('phone: runs that cannot load, and a task that vanished', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('schedules-phone-detail-errors');
      await pumpSchedules(tester, shots, size: phoneSize);

      server.on('GET', '/api/cron/jobs/price/runs', {}, status: 500);
      await _openTile(tester, 'Price watch');
      await tester.drag(detailList(), const Offset(0, -3000));
      await _settle(tester);
      await shots.capture(tester, 'runs-failed');
      expect(find.text('Run history'), findsOneWidget);
      expect(find.text('Could not load the runs'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No runs yet'), findsNothing);
      await popRoute(tester);

      server.on('GET', '/api/cron/jobs/job1', {}, status: 404);
      await _reveal(
        tester,
        find.widgetWithText(JobTile, 'Morning brief'),
        _jobList,
      );
      await tester.tap(find.widgetWithText(JobTile, 'Morning brief'));
      await _frames(tester, 600);
      await shots.capture(tester, 'vanished');
      // Told, and the task is gone from the list it was opened from.
      expect(find.text('This task no longer exists'), findsOneWidget);
      expect(_row('Morning brief'), findsNothing);
      expect(find.byType(JobTile), findsNWidgets(6));
      expect(find.text('Run history'), findsNothing);
    });

    testWidgets('desktop: run now, pause, delete', (tester) async {
      final shots = ScreenshotRecorder('schedules-desktop-detail');
      await pumpSchedules(tester, shots, size: desktopSize);
      await _openTile(tester, 'Morning brief');
      await shots.capture(tester, 'running-task');
      expect(_inDetail('Morning brief'), findsOneWidget);
      expect(_inDetail('Last run succeeded 2 h ago'), findsOneWidget);
      expect(_inDetail('Next run in 3 h'), findsOneWidget);
      expect(_inDetail('Run now'), findsOneWidget);
      expect(_inDetail('Pause'), findsOneWidget);
      expect(_inDetail('Edit'), findsOneWidget);
      expect(_inDetail('web-search'), findsOneWidget);
      expect(_inDetail('hermes-4'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await _settle(tester);
      await shots.capture(tester, 'paused');
      // The detail and the list row agree.
      expect(_inDetail('Paused'), findsOneWidget);
      expect(_inDetail('Resume'), findsOneWidget);
      expect(_inDetail('Pause'), findsNothing);
      expect(_inRow('Morning brief', 'Paused'), findsOneWidget);
      expect(_rowSwitch(tester, 'Morning brief').value, isFalse);

      await tester.tap(find.text('Resume'));
      await _settle(tester);
      expect(_inDetail('Pause'), findsOneWidget);
      expect(_inDetail('Next run in 1 h'), findsOneWidget);
      expect(_rowSwitch(tester, 'Morning brief').value, isTrue);

      await tester.tap(find.text('Run now'));
      await _frames(tester, 400);
      await shots.capture(tester, 'run-requested');
      expect(find.text('Run requested'), findsOneWidget);
      expect(
        server.requestsTo('POST', '/api/cron/jobs/job1/trigger'),
        hasLength(1),
      );
      await _frames(tester, 6000);

      await tester.drag(detailList(), const Offset(0, -3000));
      await _settle(tester);
      await shots.capture(tester, 'run-history-and-delete');
      expect(_inDetail('Run history'), findsOneWidget);
      expect(_inDetail('Running'), findsOneWidget);
      expect(_inDetail('42 s'), findsOneWidget);
      expect(_inDetail('1 min 40 s'), findsOneWidget);
      expect(_inDetail('Delete task'), findsOneWidget);

      await tester.tap(find.text('Delete task'));
      await _settle(tester);
      await shots.capture(tester, 'delete-confirm');
      expect(find.text('Delete this task?'), findsOneWidget);
      expect(
        find.text(
          '“Morning brief” will no longer run. Its past runs stay as chats.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Delete'));
      await _settle(tester);
      await shots.capture(tester, 'deleted');
      expect(server.requestsTo('DELETE', '/api/cron/jobs/job1'), hasLength(1));
      expect(find.text('Delete this task?'), findsNothing);
      expect(_row('Morning brief'), findsNothing);
      expect(find.byType(JobTile), findsNWidgets(6));
      // The pane moves on to the first task that is left.
      expect(_inDetail('*/7 9-17 * * 1-5'), findsOneWidget);
      expect(
        _inDetail('github, pr-review, summarise, discord-post'),
        findsOneWidget,
      );
      expect(_inDetail('0 8 * * 1-5'), findsNothing);
    });

    testWidgets('desktop: a task that has never run, and one that is done', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('schedules-desktop-detail-variants');
      await pumpSchedules(tester, shots, size: desktopSize);

      Future<void> open(String title, String step) async {
        await _openTile(tester, title);
        await shots.capture(tester, step);
        expect(_inDetail(title), findsOneWidget);
      }

      await open('Check the build and tell me', 'never-run');
      expect(_inDetail('Not run yet'), findsOneWidget);
      expect(_inDetail('Next run in 6 h'), findsOneWidget);
      expect(_inDetail('Every 6 hours'), findsOneWidget);
      expect(_inDetail('No runs yet'), findsOneWidget);
      expect(_inDetail('Pause'), findsOneWidget);

      await open('Renew the TLS certificate', 'completed');
      expect(_inDetail('Completed'), findsOneWidget);
      expect(_inDetail('once on 2026-09-18 09:00'), findsOneWidget);
      expect(_inDetail('Pause'), findsNothing);
      expect(_inDetail('Resume'), findsNothing);
      expect(_inDetail('Run now'), findsOneWidget);
      expect(_inDetail('Next run in 6 h'), findsNothing);

      await open('Standup notes', 'delivery-failed');
      expect(_inDetail('Ran, but delivery failed 5 h ago'), findsOneWidget);
      expect(_inDetail('Telegram: chat not found'), findsOneWidget);
      expect(_inDetail('Telegram'), findsOneWidget);
    });
  });

  group('create and edit', () {
    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await _reveal(tester, finder, _formList);
      await _settle(tester);
      await tester.tap(finder);
      await _settle(tester);
    }

    Future<void> type(WidgetTester tester, String key, String text) async {
      final finder = find.byKey(Key(key));
      await _reveal(tester, finder, _formList);
      await tester.enterText(finder, text);
      await _settle(tester);
    }

    Future<void> openGallery(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('schedules-new')));
      await _settle(tester);
    }

    Future<void> openCustom(WidgetTester tester) async {
      await openGallery(tester);
      await tester.tap(find.byKey(const Key('custom-task')));
      await _settle(tester);
    }

    Finder mode(String label) => find.descendant(
      of: find.byKey(const Key('when-mode')),
      matching: find.text(label),
    );

    final save = find.widgetWithText(TextButton, 'Save');
    final create = find.widgetWithText(TextButton, 'Create');

    // What the app last sent to [method] [path], as the server read it.
    Map<String, Object?> sent(String method, String path) =>
        jsonDecode(server.requestsTo(method, path).last.data as String)
            as Map<String, Object?>;

    // The day toggles that are on, by their labels.
    Set<String> daysOn(WidgetTester tester) => {
      for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
        if (tester
                .getSemantics(find.text(day))
                .getSemanticsData()
                .flagsCollection
                .isToggled ==
            Tristate.isTrue)
          day,
    };

    // The preview of the next runs under "When", or null without one.
    String? preview(WidgetTester tester) {
      final found = find.textContaining('Next runs:');
      return found.evaluate().isEmpty ? null : tester.widget<Text>(found).data;
    }

    // A preview of [count] runs, each a date and a time.
    Matcher runs(int count) => matches(
      RegExp(
        '^Next runs: ${List.filled(count, r'[A-Z][a-z]{2} \d+, \d{4} \d+:\d{2} [AP]M').join(', ')}\$',
      ),
    );

    bool enabled(WidgetTester tester, Finder button) =>
        tester.widget<TextButton>(button).onPressed != null;

    bool startPaused(WidgetTester tester) => tester
        .widget<Switch>(
          find.descendant(
            of: find.byKey(const Key('job-paused')),
            matching: find.byType(Switch),
          ),
        )
        .value;

    // A checked menu item takes the tap itself, not its label.
    Finder menuItem(String label) => find.ancestor(
      of: find.text(label).last,
      matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
    );

    testWidgets('phone: pick a template and fill it in', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-create-template');
      await pumpSchedules(tester, shots, size: phoneSize);

      await openGallery(tester);
      await shots.capture(tester, 'gallery');
      expect(find.text('New scheduled task'), findsOneWidget);
      expect(find.text('Custom task'), findsOneWidget);
      expect(find.text('Start from scratch'), findsOneWidget);
      expect(find.text('Morning briefing'), findsOneWidget);
      expect(
        find.text('A short daily briefing of your calendar and your mail'),
        findsOneWidget,
      );
      expect(find.text('daily at 08:00'), findsOneWidget);
      expect(find.text('Important mail'), findsOneWidget);
      expect(find.text('every hour'), findsOneWidget);
      expect(
        find.text(
          'A weekly digest of everything that happened across every '
          'repository',
        ),
        findsOneWidget,
      );
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('settings-search-field')),
        'urgent',
      );
      await _settle(tester);
      await shots.capture(tester, 'gallery-searched');
      expect(find.text('Important mail'), findsOneWidget);
      expect(find.text('Morning briefing'), findsNothing);
      expect(find.text('Custom task'), findsOneWidget);
      expect(find.text('No templates match'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('settings-search-field')),
        'zzz',
      );
      await _settle(tester);
      await shots.capture(tester, 'gallery-nothing-found');
      expect(find.text('No templates match'), findsOneWidget);
      expect(find.text('Important mail'), findsNothing);
      expect(find.text('Custom task'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('settings-search-field')),
        '',
      );
      await tester.tap(find.byKey(const Key('settings-search-filter')));
      await _settle(tester);
      await tester.tap(menuItem('Daily'));
      await _settle(tester);
      await shots.capture(tester, 'gallery-category');
      // Only the daily templates are left.
      expect(find.text('Morning briefing'), findsOneWidget);
      expect(
        find.text(
          'A weekly digest of everything that happened across every '
          'repository',
        ),
        findsOneWidget,
      );
      expect(find.text('Important mail'), findsNothing);
      expect(find.text('No templates match'), findsNothing);

      await tester.tap(find.text('Morning briefing'));
      await _settle(tester);
      await shots.capture(tester, 'template-form');
      expect(find.text('Morning briefing'), findsOneWidget);
      expect(
        find.text('A short daily briefing of your calendar and your mail'),
        findsOneWidget,
      );
      expect(find.text('What time?'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Where to deliver?'), findsOneWidget);
      expect(find.text('Anything to focus on? (optional)'), findsOneWidget);
      expect(find.text('Leave empty for a general briefing.'), findsOneWidget);
      expect(create, findsOneWidget);
      expect(enabled(tester, create), isTrue);
      expect(find.text('Important mail'), findsNothing);

      server.on('POST', '/api/cron/blueprints/instantiate', {
        'detail': "invalid time '25:00' — use HH:MM (24h)",
      }, status: 422);
      await tapVisible(tester, find.text('telegram'));
      await _settle(tester);
      await tester.tap(create);
      await _settle(tester);
      await shots.capture(tester, 'template-refused');
      // The server's reason is told by the field it is about; the form stays.
      expect(find.text('Check the fields marked below.'), findsOneWidget);
      expect(
        find.text("invalid time '25:00' — use HH:MM (24h)"),
        findsOneWidget,
      );
      expect(find.text('What time?'), findsOneWidget);
      expect(enabled(tester, create), isTrue);
      expect(
        server.requestsTo('POST', '/api/cron/blueprints/instantiate'),
        hasLength(1),
      );
      final asked = sent('POST', '/api/cron/blueprints/instantiate');
      expect(asked['blueprint'], 'morning-brief');
      expect(
        asked['values'],
        allOf(
          containsPair('time', '08:00'),
          containsPair('deliver', 'telegram'),
        ),
      );

      final held = Completer<FakeResponse>();
      server.onRequest(
        'POST',
        '/api/cron/blueprints/instantiate',
        (_) => held.future,
      );
      await tester.tap(create);
      await _frames(tester, 300);
      await shots.capture(tester, 'template-saving');
      // Busy: Create is replaced by a spinner and the reason is gone.
      expect(create, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('What time?'), findsOneWidget);
      expect(
        server.requestsTo('POST', '/api/cron/blueprints/instantiate'),
        hasLength(2),
      );

      cron.rows.add(
        cronJobRow(
          id: 'b',
          name: 'Morning briefing',
          nextRunAt: _iso(fixedNow),
        ),
      );
      cron.serve();
      held.complete((status: 200, body: cron.rows.last));
      await _settle(tester);
      await shots.capture(tester, 'template-created');
      // The new task is open, and the form is gone.
      expect(find.text('Morning briefing'), findsOneWidget);
      expect(find.text('Not run yet'), findsOneWidget);
      expect(find.text('Run now'), findsOneWidget);
      expect(find.text('What time?'), findsNothing);
      expect(create, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('phone: the gallery has no templates', (tester) async {
      server.on('GET', '/api/cron/blueprints', {}, status: 500);
      final shots = ScreenshotRecorder('schedules-phone-create-gallery-failed');
      await pumpSchedules(tester, shots, size: phoneSize);
      await openGallery(tester);
      await shots.capture(tester, 'templates-failed');
      expect(find.text('The templates could not be loaded.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // A custom task can still be made.
      expect(find.text('Custom task'), findsOneWidget);
      expect(find.text('Morning briefing'), findsNothing);
    });

    testWidgets('phone: the ways to say when', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-create-when');
      final semantics = tester.ensureSemantics();
      await pumpSchedules(tester, shots, size: phoneSize);
      await openCustom(tester);
      await shots.capture(tester, 'empty-form');
      expect(find.text('New task'), findsOneWidget);
      for (final label in ['Name', 'Task', 'When', 'Delivery', 'Advanced']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('What should Hermes do each time?'), findsOneWidget);
      for (final label in ['Every', 'Daily', 'Weekly', 'Once', 'Cron']) {
        expect(mode(label), findsOneWidget, reason: '$label is offered');
      }
      // A new task starts as every hour, delivered to a local file.
      expect(find.text('Unit'), findsOneWidget);
      expect(find.text('hours'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(preview(tester), runs(3));
      expect(find.text('Local (save only)'), findsOneWidget);
      expect(find.text('Start paused'), findsOneWidget);
      expect(startPaused(tester), isFalse);
      expect(enabled(tester, save), isTrue);

      await type(tester, 'job-name', 'Price watch for a GPU');
      await type(
        tester,
        'job-prompt',
        'Check the price of the RTX card on the three shops I follow and '
            'tell me if it dropped below 700.',
      );
      await shots.capture(tester, 'filled');
      expect(find.text('Price watch for a GPU'), findsOneWidget);
      expect(
        find.text(
          'Check the price of the RTX card on the three shops I follow and '
          'tell me if it dropped below 700.',
        ),
        findsOneWidget,
      );

      await tapVisible(tester, mode('Every'));
      await shots.capture(tester, 'every');
      expect(find.text('Unit'), findsOneWidget);
      final hourly = preview(tester);
      expect(hourly, runs(3));

      await type(tester, 'when-amount', '6');
      await tapVisible(tester, find.byKey(const Key('when-unit')));
      await shots.capture(tester, 'every-unit-menu');
      expect(find.text('6'), findsOneWidget);
      for (final unit in ['minutes', 'hours', 'days']) {
        expect(menuItem(unit), findsOneWidget, reason: '$unit is offered');
      }
      // Six hours apart now, not one.
      expect(preview(tester), runs(3));
      expect(preview(tester), isNot(hourly));
      await tester.tap(menuItem('hours'));
      await _settle(tester);
      await shots.capture(tester, 'every-6-hours');
      expect(menuItem('hours'), findsNothing);
      expect(find.text('hours'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(preview(tester), runs(3));
      expect(preview(tester), isNot(hourly));

      await type(tester, 'when-amount', '');
      await shots.capture(tester, 'every-nothing-typed');
      // No amount, no runs to preview.
      expect(preview(tester), isNull);
      expect(find.text('6'), findsNothing);

      await tapVisible(tester, mode('Daily'));
      await shots.capture(tester, 'daily');
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Unit'), findsNothing);
      expect(find.text('Tue'), findsNothing);
      expect(preview(tester), runs(3));
      await tapVisible(tester, find.byKey(const Key('when-time')));
      await shots.capture(tester, 'daily-time-picker');
      expect(find.text('Select time'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(find.text('Select time'), findsNothing);
      expect(find.text('08:00'), findsOneWidget);

      await tapVisible(tester, mode('Weekly'));
      await shots.capture(tester, 'weekly');
      // Weekdays to begin with.
      expect(daysOn(tester), {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'});
      expect(find.text('08:00'), findsOneWidget);
      expect(preview(tester), runs(3));
      for (final day in ['Tue', 'Wed', 'Fri']) {
        await tester.tap(find.text(day));
        await _settle(tester);
      }
      await shots.capture(tester, 'weekly-some-days');
      expect(daysOn(tester), {'Mon', 'Thu'});
      expect(preview(tester), runs(3));

      await tapVisible(tester, mode('Once'));
      await shots.capture(tester, 'once');
      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('Mon'), findsNothing);
      expect(preview(tester), runs(1));
      await tapVisible(tester, find.byKey(const Key('when-date')));
      await shots.capture(tester, 'once-date-picker');
      expect(find.text('Select date'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(find.text('Select date'), findsNothing);

      await tapVisible(tester, mode('Cron'));
      await type(tester, 'when-cron', '*/7 9-17 * * 1-5');
      await shots.capture(tester, 'cron');
      expect(find.text('Schedule'), findsOneWidget);
      expect(find.text('*/7 9-17 * * 1-5'), findsOneWidget);
      expect(
        find.text(
          'A five-field cron expression, for example 0 9 * * 1-5, or a '
          'phrase like every monday 9am.',
        ),
        findsOneWidget,
      );
      // Only the server can work a raw expression out.
      expect(preview(tester), isNull);
      expect(
        find.text('The server works out the next run when you save.'),
        findsOneWidget,
      );
      expect(find.text('Date'), findsNothing);
      semantics.dispose();
    });

    testWidgets('phone: validation, refusal, saving, saved', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-create-save');
      await pumpSchedules(tester, shots, size: phoneSize);
      await openCustom(tester);

      await tapVisible(tester, save);
      await shots.capture(tester, 'nothing-to-run');
      // Refused here, before anything is sent.
      expect(
        find.text('A task needs a prompt, a skill or a script'),
        findsOneWidget,
      );
      expect(server.requestsTo('POST', '/api/cron/jobs'), isEmpty);
      expect(find.text('New task'), findsOneWidget);
      expect(enabled(tester, save), isTrue);

      await type(tester, 'job-prompt', 'Say hello');
      await tapVisible(tester, find.byKey(const Key('job-advanced')));
      await type(tester, 'job-script', '../evil.sh');
      await type(tester, 'job-skills', 'web-search, calendar');
      await tapVisible(tester, find.byKey(const Key('job-model')));
      await shots.capture(tester, 'model-picker');
      expect(find.text('Use the profile’s default'), findsOneWidget);
      for (final label in [
        'Nous Portal',
        'hermes-4-405b',
        'hermes-4-70b',
        'OpenRouter',
        'anthropic/claude-opus-4',
        'openai/gpt-5.1',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '$label is offered');
      }
      await tester.tap(find.byKey(const Key('model-nous-hermes-4-70b')));
      await _settle(tester);
      await shots.capture(tester, 'advanced');
      expect(find.text('hermes-4-70b'), findsOneWidget);
      expect(find.text('Nous Portal'), findsOneWidget);
      expect(find.text('hermes-4-405b'), findsNothing);
      expect(find.text('web-search, calendar'), findsOneWidget);
      expect(find.text('../evil.sh'), findsOneWidget);
      for (final label in [
        'Skills',
        'Model',
        'Pre-run script',
        'Take context from',
        'Working directory',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(
        find.text(
          'Skills and task ids are separated by commas. The pre-run script is '
          'a file in the profile’s scripts folder; its output is added to the '
          'prompt.',
        ),
        findsOneWidget,
      );

      server.on('POST', '/api/cron/jobs', {
        'detail': 'script must be inside /home/hermes/work/scripts',
      }, status: 400);
      await tapVisible(tester, save);
      await shots.capture(tester, 'refused-by-server');
      expect(
        find.text('script must be inside /home/hermes/work/scripts'),
        findsOneWidget,
      );
      expect(find.text('New task'), findsOneWidget);
      expect(enabled(tester, save), isTrue);
      expect(server.requestsTo('POST', '/api/cron/jobs'), hasLength(1));
      expect(
        sent('POST', '/api/cron/jobs'),
        allOf(
          containsPair('prompt', 'Say hello'),
          containsPair('schedule', 'every 1h'),
          containsPair('deliver', 'local'),
          containsPair('skills', ['web-search', 'calendar']),
          containsPair('model', 'hermes-4-70b'),
          containsPair('provider', 'nous'),
          containsPair('script', '../evil.sh'),
        ),
      );
      expect(sent('POST', '/api/cron/jobs'), containsPair('paused', false));

      await type(tester, 'job-script', '');
      await tapVisible(tester, find.byKey(const Key('job-deliver')));
      await shots.capture(tester, 'deliver-menu');
      for (final label in ['Local (save only)', 'Discord', 'Telegram']) {
        expect(menuItem(label), findsOneWidget, reason: '$label is offered');
      }
      await tester.tap(menuItem('Discord'));
      await _settle(tester);
      await shots.capture(tester, 'deliver-without-home-channel');
      expect(find.text('Discord'), findsOneWidget);
      expect(
        find.text('No home channel is set on the server for this platform.'),
        findsOneWidget,
      );
      expect(find.text('Local (save only)'), findsNothing);

      await tapVisible(tester, find.byKey(const Key('job-profile')));
      await shots.capture(tester, 'profile-menu');
      expect(menuItem('work'), findsOneWidget);
      expect(menuItem('home'), findsOneWidget);
      await tester.tap(menuItem('home'));
      await _settle(tester);

      // The switch is what turns it on; the row around it does nothing.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('job-paused')),
          matching: find.byType(Switch),
        ),
      );
      await _settle(tester);
      await shots.capture(tester, 'start-paused');
      expect(startPaused(tester), isTrue);
      // The bar's subtitle and the Profile row both say home now.
      expect(find.text('home'), findsNWidgets(2));
      expect(find.text('work'), findsNothing);

      final held = Completer<void>();
      cron.holdCreate = held;
      server.on('POST', '/api/cron/jobs', {}, status: 200);
      cron.serve();
      await tapVisible(tester, save);
      await _frames(tester, 300);
      await shots.capture(tester, 'saving');
      // Busy: Save is replaced by a spinner.
      expect(save, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('New task'), findsOneWidget);

      held.complete();
      await _settle(tester);
      await shots.capture(tester, 'saved');
      expect(server.requestsTo('POST', '/api/cron/jobs'), hasLength(2));
      final created = server.requestsTo('POST', '/api/cron/jobs').last;
      expect(created.queryParameters, containsPair('profile', 'home'));
      expect(
        sent('POST', '/api/cron/jobs'),
        allOf(
          containsPair('prompt', 'Say hello'),
          containsPair('deliver', 'discord'),
          containsPair('paused', true),
        ),
      );
      // The form is gone and the new task is open, paused as asked.
      expect(find.text('New task'), findsNothing);
      expect(save, findsNothing);
      // Titled by its prompt, which it also shows in full.
      expect(find.text('Say hello'), findsNWidgets(2));
      expect(find.text('Run now'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('phone: leaving the form asks first', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-create-discard');
      await pumpSchedules(tester, shots, size: phoneSize);
      await openCustom(tester);
      await type(tester, 'job-prompt', 'half a thought');

      await tester.tap(find.byType(CloseButton));
      await _settle(tester);
      await shots.capture(tester, 'discard-changes');
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('What you entered will be lost.'), findsOneWidget);
      expect(find.text('Keep editing'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await _settle(tester);
      await shots.capture(tester, 'discarded');
      // Back on the gallery, with nothing saved.
      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New task'), findsNothing);
      expect(find.text('New scheduled task'), findsOneWidget);
      expect(find.text('Custom task'), findsOneWidget);
      expect(server.requestsTo('POST', '/api/cron/jobs'), isEmpty);
    });

    testWidgets('phone: edit a task', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-edit');
      await pumpSchedules(tester, shots, size: phoneSize);

      Future<void> edit(String title) async {
        await _openTile(tester, title);
        await tester.tap(find.text('Edit'));
        await _settle(tester);
      }

      await edit('Morning brief');
      await shots.capture(tester, 'weekday-task');
      // The form holds what the task has.
      expect(find.text('Edit task'), findsOneWidget);
      expect(find.text('Morning brief'), findsOneWidget);
      expect(
        find.text(
          'Say good morning and summarise my calendar and unread mail.',
        ),
        findsOneWidget,
      );
      expect(daysOn(tester), {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'});
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('web-search'), findsOneWidget);
      expect(find.text('hermes-4'), findsOneWidget);
      expect(find.text('Not in the server’s list'), findsOneWidget);
      expect(find.text('Local (save only)'), findsOneWidget);
      // Neither the profile nor a paused start can be changed here.
      expect(find.text('Start paused'), findsNothing);
      expect(find.byKey(const Key('job-profile')), findsNothing);
      expect(enabled(tester, save), isTrue);
      await type(tester, 'job-prompt', 'Say good morning, kindly');
      await tapVisible(tester, save);
      await shots.capture(tester, 'saved');
      // Only what changed was sent, and the task is open again.
      expect(server.requestsTo('PUT', '/api/cron/jobs/job1'), hasLength(1));
      expect(sent('PUT', '/api/cron/jobs/job1')['updates'], {
        'prompt': 'Say good morning, kindly',
      });
      expect(find.text('Edit task'), findsNothing);
      expect(find.text('Morning brief'), findsOneWidget);
      expect(find.text('Run now'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      await popRoute(tester);

      await edit('Price watch');
      await shots.capture(tester, 'interval-task');
      expect(find.text('Edit task'), findsOneWidget);
      expect(find.text('Price watch'), findsOneWidget);
      expect(
        find.text('Check the price of the RTX card and tell me if it dropped.'),
        findsOneWidget,
      );
      expect(find.text('30'), findsOneWidget);
      expect(find.text('minutes'), findsOneWidget);
      expect(preview(tester), runs(3));
      await popRoute(tester);
      await popRoute(tester);

      await edit(_longName);
      await shots.capture(tester, 'long-task');
      expect(find.text('Edit task'), findsOneWidget);
      expect(find.text(_longName), findsOneWidget);
      // Too long to say in the picker, it opens as a cron expression.
      expect(find.text('*/7 9-17 * * 1-5'), findsOneWidget);
      expect(preview(tester), isNull);
      expect(find.text('Discord'), findsOneWidget);
      expect(
        find.text('No home channel is set on the server for this platform.'),
        findsOneWidget,
      );
      expect(find.text('hermes-4-long-context-preview'), findsOneWidget);
      expect(find.text('Not in the server’s list'), findsOneWidget);
      await type(tester, 'job-name', 'Renamed');
      await tester.tap(find.byType(CloseButton));
      await _settle(tester);
      await shots.capture(tester, 'discard-edit');
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('What you entered will be lost.'), findsOneWidget);
      expect(find.text('Keep editing'), findsOneWidget);
      expect(find.text('Renamed'), findsOneWidget);
      expect(server.requestsTo('PUT', '/api/cron/jobs/long'), isEmpty);
    });

    testWidgets('desktop: pick a template and fill it in', (tester) async {
      final shots = ScreenshotRecorder('schedules-desktop-create-template');
      await pumpSchedules(tester, shots, size: desktopSize);
      await openGallery(tester);
      await shots.capture(tester, 'gallery');
      expect(find.text('New scheduled task'), findsOneWidget);
      expect(find.text('Custom task'), findsOneWidget);
      expect(find.text('Morning briefing'), findsOneWidget);
      expect(find.text('Important mail'), findsOneWidget);
      expect(find.text('daily at 08:00'), findsOneWidget);

      await tester.tap(find.text('Morning briefing'));
      await _settle(tester);
      await shots.capture(tester, 'template-form');
      expect(find.text('Morning briefing'), findsOneWidget);
      expect(find.text('What time?'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Where to deliver?'), findsOneWidget);
      expect(find.text('Anything to focus on? (optional)'), findsOneWidget);
      expect(enabled(tester, create), isTrue);
      expect(find.text('Important mail'), findsNothing);
    });

    testWidgets('desktop: custom task', (tester) async {
      final shots = ScreenshotRecorder('schedules-desktop-create');
      await pumpSchedules(tester, shots, size: desktopSize);
      final semantics = tester.ensureSemantics();
      await openCustom(tester);
      await shots.capture(tester, 'empty-form');
      expect(find.text('New task'), findsOneWidget);
      expect(find.text('What should Hermes do each time?'), findsOneWidget);
      expect(mode('Every'), findsOneWidget);
      expect(find.text('Unit'), findsOneWidget);
      expect(preview(tester), runs(3));
      expect(enabled(tester, save), isTrue);

      await tapVisible(tester, save);
      await shots.capture(tester, 'nothing-to-run');
      expect(
        find.text('A task needs a prompt, a skill or a script'),
        findsOneWidget,
      );
      expect(server.requestsTo('POST', '/api/cron/jobs'), isEmpty);

      await type(tester, 'job-name', 'Price watch for a GPU');
      await type(tester, 'job-prompt', 'Check the price of the RTX card.');
      await tapVisible(tester, mode('Weekly'));
      await shots.capture(tester, 'weekly');
      expect(daysOn(tester), {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'});
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Unit'), findsNothing);
      expect(preview(tester), runs(3));

      await tapVisible(tester, mode('Every'));
      await tapVisible(tester, find.byKey(const Key('job-advanced')));
      await shots.capture(tester, 'every-advanced');
      expect(find.text('Unit'), findsOneWidget);
      expect(find.text('Tue'), findsNothing);
      for (final label in [
        'Skills',
        'Model',
        'Pre-run script',
        'Take context from',
        'Working directory',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Profile default'), findsOneWidget);

      final held = Completer<void>();
      cron.holdCreate = held;
      cron.serve();
      await tapVisible(tester, save);
      await _frames(tester, 300);
      await shots.capture(tester, 'saving');
      expect(save, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('New task'), findsOneWidget);

      held.complete();
      await _settle(tester);
      await shots.capture(tester, 'saved');
      expect(
        sent('POST', '/api/cron/jobs'),
        allOf(
          containsPair('name', 'Price watch for a GPU'),
          containsPair('prompt', 'Check the price of the RTX card.'),
          containsPair('schedule', 'every 1h'),
        ),
      );
      // The form is gone; the list has the new task and shows it open.
      expect(find.text('New task'), findsNothing);
      expect(find.byType(JobTile), findsNWidgets(8));
      expect(_row('Price watch for a GPU'), findsOneWidget);
      expect(_rowSwitch(tester, 'Price watch for a GPU').value, isTrue);
      expect(_inDetail('Price watch for a GPU'), findsOneWidget);
      expect(_inDetail('Not run yet'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('desktop: edit a task', (tester) async {
      final shots = ScreenshotRecorder('schedules-desktop-edit');
      await pumpSchedules(tester, shots, size: desktopSize);
      await _openTile(tester, 'Price watch');
      await tester.tap(find.text('Edit'));
      await _settle(tester);
      await shots.capture(tester, 'interval-task');
      expect(find.text('Edit task'), findsOneWidget);
      expect(
        find.text('Check the price of the RTX card and tell me if it dropped.'),
        findsOneWidget,
      );
      expect(find.text('30'), findsOneWidget);
      expect(find.text('minutes'), findsOneWidget);
      expect(find.text('Start paused'), findsNothing);

      await type(tester, 'job-prompt', 'Check the price again');
      await tapVisible(tester, save);
      await shots.capture(tester, 'saved');
      expect(sent('PUT', '/api/cron/jobs/price')['updates'], {
        'prompt': 'Check the price again',
      });
      expect(find.text('Edit task'), findsNothing);
      expect(_inDetail('Price watch'), findsOneWidget);
      expect(_inDetail('Every 30 minutes'), findsOneWidget);
    });

    testWidgets('phone: dark form', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-create-dark');
      await pumpSchedules(
        tester,
        shots,
        size: phoneSize,
        brightness: Brightness.dark,
      );
      final semantics = tester.ensureSemantics();
      await openGallery(tester);
      await shots.capture(tester, 'gallery');
      expect(find.text('New scheduled task'), findsOneWidget);
      expect(find.text('Custom task'), findsOneWidget);
      expect(find.text('Morning briefing'), findsOneWidget);
      await tester.tap(find.byKey(const Key('custom-task')));
      await _settle(tester);
      await tapVisible(tester, save);
      await shots.capture(tester, 'form-with-error');
      expect(
        find.text('A task needs a prompt, a skill or a script'),
        findsOneWidget,
      );
      expect(find.text('New task'), findsOneWidget);
      expect(server.requestsTo('POST', '/api/cron/jobs'), isEmpty);
      await tapVisible(tester, mode('Weekly'));
      await shots.capture(tester, 'weekly');
      expect(daysOn(tester), {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'});
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Unit'), findsNothing);
      semantics.dispose();
    });
  });
}

const _longName =
    'Summarise every open pull request across all of the repositories in the '
    'organisation and post a digest';

final _boards = [(slug: 'default', name: 'Default', total: 2, current: true)];

final _tasks = [
  kanbanTaskRow(id: 't1', title: 'Investigate flaky test', status: 'todo'),
  kanbanTaskRow(
    id: 't2',
    title: 'Migrate webhooks',
    status: 'running',
    assignee: 'coder',
  ),
];

const _targets = {
  'targets': [
    {'id': 'local', 'name': 'Local (save only)', 'home_target_set': true},
    {'id': 'discord', 'name': 'Discord', 'home_target_set': false},
    {'id': 'telegram', 'name': 'Telegram', 'home_target_set': true},
  ],
};

final _blueprints = {
  'blueprints': [
    {
      'key': 'morning-brief',
      'title': 'Morning briefing',
      'description': 'A short daily briefing of your calendar and your mail',
      'category': 'daily',
      'tags': ['daily', 'briefing'],
      'scheduleHuman': 'daily at 08:00',
      'fields': [
        {
          'name': 'time',
          'type': 'time',
          'label': 'What time?',
          'default': '08:00',
        },
        {
          'name': 'deliver',
          'type': 'enum',
          'label': 'Where to deliver?',
          'default': 'origin',
          'options': ['origin', 'local', 'telegram'],
          'strict': false,
        },
        {
          'name': 'topic',
          'type': 'text',
          'label': 'Anything to focus on?',
          'optional': true,
          'help': 'Leave empty for a general briefing.',
        },
      ],
    },
    {
      'key': 'mail',
      'title': 'Important mail',
      'description': 'Check for urgent mail and tell me right away',
      'category': 'email',
      'tags': [],
      'scheduleHuman': 'every hour',
      'fields': [],
    },
    {
      'key': 'digest',
      'title':
          'A weekly digest of everything that happened across every '
          'repository',
      'description':
          'Collects merged pull requests, closed issues and failing builds '
          'from every repository you follow and sends one summary.',
      'category': 'daily',
      'tags': ['github'],
      'scheduleHuman': 'every Monday at 09:00',
      'fields': [],
    },
  ],
};

String _iso(DateTime time) => time.toUtc().toIso8601String();

/// Every state a task can be in, on the clock of [now].
List<Map<String, Object?>> _demoJobs(DateTime now) {
  String ago(Duration d) => _iso(now.subtract(d));
  String ahead(Duration d) => _iso(now.add(d));
  return [
    cronJobRow(
      id: 'job1',
      name: 'Morning brief',
      prompt: 'Say good morning and summarise my calendar and unread mail.',
      lastRunAt: ago(const Duration(hours: 2)),
      lastStatus: 'ok',
      nextRunAt: ahead(const Duration(hours: 3)),
      skills: ['web-search'],
      model: 'hermes-4',
    ),
    cronJobRow(
      id: 'digest',
      name: 'Weekly digest',
      prompt: 'Write the weekly digest of what the team shipped.',
      state: 'paused',
      display: 'Mondays at 09:00',
      schedule: {'kind': 'cron', 'expr': '0 9 * * 1', 'display': '0 9 * * 1'},
      lastRunAt: ago(const Duration(days: 3)),
      lastStatus: 'ok',
      profile: 'home',
    ),
    cronJobRow(
      id: 'price',
      name: 'Price watch',
      prompt: 'Check the price of the RTX card and tell me if it dropped.',
      display: 'every 30m',
      schedule: {'kind': 'interval', 'minutes': 30, 'display': 'every 30m'},
      lastRunAt: ago(const Duration(minutes: 40)),
      lastStatus: 'error',
      lastError: 'Provider timeout\nTraceback (most recent call last):\n  ...',
      nextRunAt: ahead(const Duration(minutes: 20)),
    ),
    cronJobRow(
      id: 'standup',
      name: 'Standup notes',
      prompt: 'Collect yesterday\'s notes and post them to the team.',
      deliver: 'telegram',
      lastRunAt: ago(const Duration(hours: 5)),
      lastStatus: 'ok',
      lastDeliveryError: 'Telegram: chat not found',
      nextRunAt: ahead(const Duration(hours: 19)),
    ),
    cronJobRow(
      id: 'long',
      name: _longName,
      prompt:
          'Go through every open pull request in every repository of the '
          'organisation, group them by author and by how long they have been '
          'waiting, flag the ones without a reviewer, and write a friendly '
          'digest that ends with the three that need attention today.',
      display:
          'Every weekday at 08:00, 12:00 and 17:00 except public holidays in '
          'the organisation\'s home country',
      schedule: {
        'kind': 'cron',
        'expr': '*/7 9-17 * * 1-5',
        'display': '*/7 9-17 * * 1-5',
      },
      deliver: 'discord',
      lastRunAt: ago(const Duration(minutes: 5)),
      lastStatus: 'error',
      lastError:
          'ConnectionError: HTTPSConnectionPool(host=\'api.github.example\', '
          'port=443): Max retries exceeded with url: /orgs/acme/pulls',
      nextRunAt: ahead(const Duration(minutes: 2)),
      skills: ['github', 'pr-review', 'summarise', 'discord-post'],
      model: 'hermes-4-long-context-preview',
    ),
    cronJobRow(
      id: 'fresh',
      name: '',
      prompt: 'Check the build and tell me when it is green',
      display: 'every 6h',
      schedule: {'kind': 'interval', 'minutes': 360, 'display': 'every 6h'},
      nextRunAt: ahead(const Duration(hours: 6)),
    ),
    cronJobRow(
      id: 'once',
      name: 'Renew the TLS certificate',
      prompt: 'Renew the certificate for the staging cluster.',
      state: 'completed',
      display: 'once on 2026-09-18 09:00',
      schedule: {
        'kind': 'once',
        'run_at': ago(const Duration(days: 2)),
        'display': 'once on 2026-09-18 09:00',
      },
      lastRunAt: ago(const Duration(days: 2)),
      lastStatus: 'ok',
    ),
  ];
}

Map<String, List<Map<String, Object?>>> _demoRuns(DateTime now) {
  final t = now.millisecondsSinceEpoch ~/ 1000;
  return {
    'job1': [
      cronRunRow(id: 'cron_job1_3', startedAt: t - 90, active: true),
      cronRunRow(id: 'cron_job1_2', startedAt: t - 7200, endedAt: t - 7158),
      cronRunRow(id: 'cron_job1_1', startedAt: t - 93600, endedAt: t - 93500),
    ],
    'price': [
      cronRunRow(id: 'cron_price_2', startedAt: t - 2400, endedAt: t - 2380),
      cronRunRow(id: 'cron_price_1', startedAt: t - 4200),
    ],
    'standup': [
      cronRunRow(
        id: 'cron_standup_1',
        startedAt: t - 18000,
        endedAt: t - 17300,
      ),
    ],
  };
}

/// An in-memory `/api/cron` that pausing, deleting, saving and creating
/// change, so the screens show what the server would.
class _Cron {
  _Cron(this.server, {required this.now});

  final FakeHermesServer server;
  final DateTime now;
  final rows = <Map<String, Object?>>[];
  final runs = <String, List<Map<String, Object?>>>{};

  /// While set, creating a job waits for it.
  Completer<void>? holdCreate;
  var _created = 0;

  Map<String, Object?>? _find(String id) =>
      rows.where((r) => r['id'] == id).firstOrNull;

  Map<String, Object?> _body(RequestOptions request) =>
      jsonDecode(request.data as String) as Map<String, Object?>;

  void serve() {
    server
      ..onRequest(
        'GET',
        '/api/cron/jobs',
        (_) => (
          status: 200,
          body: [
            for (final r in rows) {...r},
          ],
        ),
      )
      ..onRequest('POST', '/api/cron/jobs', (request) async {
        await holdCreate?.future;
        final body = _body(request);
        final id = 'new${++_created}';
        final row = cronJobRow(
          id: id,
          name: '${body['name'] ?? ''}',
          prompt: '${body['prompt'] ?? ''}',
          state: body['paused'] == true ? 'paused' : 'scheduled',
          display: '${body['schedule']}',
          nextRunAt: _iso(now.add(const Duration(hours: 1))),
        );
        rows.add(row);
        serve();
        return (status: 200, body: {...row});
      });
    for (final row in rows) {
      final id = row['id']! as String;
      final base = '/api/cron/jobs/$id';
      server
        ..onRequest('GET', base, (_) {
          final row = _find(id);
          return row == null
              ? (status: 404, body: {'detail': 'Job not found'})
              : (status: 200, body: {...row});
        })
        ..onRequest(
          'GET',
          '$base/runs',
          (_) => (status: 200, body: {'runs': runs[id] ?? const []}),
        )
        ..onRequest('POST', '$base/pause', (_) {
          _find(id)
            ?..['state'] = 'paused'
            ..['enabled'] = false
            ..['next_run_at'] = null;
          return (status: 200, body: {'id': id});
        })
        ..onRequest('POST', '$base/resume', (_) {
          _find(id)
            ?..['state'] = 'scheduled'
            ..['enabled'] = true
            ..['next_run_at'] = _iso(now.add(const Duration(hours: 1)));
          return (status: 200, body: {'id': id});
        })
        ..on('POST', '$base/trigger', {'ok': true})
        ..onRequest('DELETE', base, (_) {
          rows.removeWhere((r) => r['id'] == id);
          return (status: 200, body: {'ok': true});
        })
        ..onRequest('PUT', base, (request) {
          final row = _find(id);
          final updates = _body(request)['updates'];
          if (row != null && updates is Map<String, Object?>) {
            row.addAll({
              for (final e in updates.entries)
                if (e.key != 'schedule') e.key: e.value,
            });
          }
          return (status: 200, body: {...?row});
        });
    }
  }
}

/// The list row of the task titled [title].
Finder _row(String title) => find.widgetWithText(JobTile, title);

/// [text] inside the list row of [title].
Finder _inRow(String title, String text) =>
    find.descendant(of: _row(title), matching: find.text(text));

/// [text] inside the open task's detail.
Finder _inDetail(String text) =>
    find.descendant(of: find.byType(ScheduleDetail), matching: find.text(text));

/// Whether the open task's notifications are muted.
bool _muted(WidgetTester tester) => tester
    .widget<Switch>(
      find.descendant(
        of: find.widgetWithText(GroupedSwitchRow, 'Mute notifications'),
        matching: find.byType(Switch),
      ),
    )
    .value;

/// The pause switch of the list row of [title].
Switch _rowSwitch(WidgetTester tester, String title) => tester.widget<Switch>(
  find.descendant(of: _row(title), matching: find.byType(Switch)),
);

/// Whether the row of [above] sits higher in the list than the row of
/// [below].
bool _listedAbove(WidgetTester tester, String above, String below) =>
    tester.getTopLeft(_row(above)).dy < tester.getTopLeft(_row(below)).dy;

/// Runs the clock for [millis] a frame at a time. `pumpAndSettle` would never
/// return with a spinner (a run in progress, a save) on screen.
Future<void> _frames(WidgetTester tester, int millis) async {
  await tester.pump();
  for (var elapsed = 0; elapsed < millis; elapsed += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _settle(WidgetTester tester) => _frames(tester, 1000);

final _jobList = find.descendant(
  of: find.byType(SchedulesList),
  matching: find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  ),
);

final _formList = find.descendant(
  of: find.byType(ListView),
  matching: find.byType(Scrollable),
);

/// Scrolls [target] into view in [scrollable], from the top: a list builds
/// only what is near its viewport, so a widget further down is not there to
/// find until then.
Future<void> _reveal(
  WidgetTester tester,
  Finder target,
  Finder scrollable,
) async {
  if (target.evaluate().isEmpty) {
    await tester.drag(scrollable.first, const Offset(0, 5000));
    await tester.pump();
    await tester.scrollUntilVisible(target, 200, scrollable: scrollable.first);
  }
  await tester.ensureVisible(target);
}

/// Opens the task titled [title] from the list, on a phone or beside it.
Future<void> _openTile(WidgetTester tester, String title) async {
  final tile = find.widgetWithText(JobTile, title);
  await _reveal(tester, tile, _jobList);
  await _frames(tester, 100);
  await tester.tap(tile);
  await _settle(tester);
}

/// Picks [label] from the bar's filter menu, capturing the open menu when
/// [shots] is given.
Future<void> _filter(
  WidgetTester tester,
  String label, {
  ScreenshotRecorder? shots,
  String from = 'All tasks',
}) async {
  await tester.tap(find.byKey(const Key('schedule-filter')));
  await _settle(tester);
  await shots?.capture(tester, 'filter-menu');
  // Three choices, the one in force checked.
  expect(find.byType(CheckedPopupMenuItem<ScheduleFilter>), findsNWidgets(3));
  for (final choice in [from, label]) {
    expect(_menuItem(choice), findsOneWidget, reason: '$choice is offered');
  }
  expect(
    tester
        .widget<CheckedPopupMenuItem<ScheduleFilter>>(_menuItem(from))
        .checked,
    isTrue,
  );
  await tester.tap(_menuItem(label));
  await _settle(tester);
}

/// Every task of the demo list is on screen, each with what it shows and a
/// switch that says whether it runs.
void _expectEveryTask(WidgetTester tester) {
  for (final title in [
    _longName,
    'Price watch',
    'Morning brief',
    'Check the build and tell me',
    'Standup notes',
    'Renew the TLS certificate',
    'Weekly digest',
  ]) {
    expect(_row(title), findsOneWidget, reason: '$title is listed');
  }
  expect(find.byType(JobTile), findsNWidgets(7));
  void shows(String title, List<String> lines) {
    for (final line in lines) {
      expect(_inRow(title, line), findsOneWidget, reason: '$title: $line');
    }
  }

  shows(_longName, [
    "Every weekday at 08:00, 12:00 and 17:00 except public holidays in the organisation's home country · Discord",
    'Next run in 2 min',
  ]);
  expect(
    find.descendant(
      of: _row(_longName),
      matching: find.textContaining('Failed 5 min ago · ConnectionError'),
    ),
    findsOneWidget,
  );
  shows('Price watch', [
    'Every 30 minutes · Local',
    'Next run in 20 min',
    'Failed 40 min ago · Provider timeout',
  ]);
  shows('Morning brief', [
    'Weekdays at 08:00 · Local',
    'Last run succeeded 2 h ago · Next run in 3 h',
  ]);
  shows('Check the build and tell me', [
    'Every 6 hours · Local',
    'Not run yet · Next run in 6 h',
  ]);
  shows('Standup notes', [
    'Weekdays at 08:00 · Telegram',
    'Next run in 19 h',
    'Ran, but delivery failed 5 h ago · Telegram: chat not found',
  ]);
  shows('Renew the TLS certificate', [
    'once on 2026-09-18 09:00 · Local',
    'Completed',
  ]);
  shows('Weekly digest', ['Mondays at 09:00 · Local', 'Paused']);
  for (final title in [
    _longName,
    'Price watch',
    'Morning brief',
    'Check the build and tell me',
    'Standup notes',
  ]) {
    expect(_rowSwitch(tester, title).value, isTrue, reason: '$title runs');
  }
  expect(_rowSwitch(tester, 'Weekly digest').value, isFalse);
  // A completed task has nothing left to switch.
  final done = _rowSwitch(tester, 'Renew the TLS certificate');
  expect(done.value, isFalse);
  expect(done.onChanged, isNull);
}

/// Exactly the tasks titled [titles] are listed.
void _expectOnlyTasks(List<String> titles) {
  for (final title in titles) {
    expect(_row(title), findsOneWidget, reason: '$title is listed');
  }
  expect(find.byType(JobTile), findsNWidgets(titles.length));
}

/// Whether the list row of [title] is marked as the open one.
bool _selected(WidgetTester tester, String title) =>
    tester
        .getSemantics(_inRow(title, title))
        .getSemanticsData()
        .flagsCollection
        .isSelected ==
    Tristate.isTrue;

/// The open menu's item labelled [label].
Finder _menuItem(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((w) => w is CheckedPopupMenuItem),
);

/// Scrolls [finder] into view and taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _frames(tester, 100);
  await tester.tap(finder);
  await _settle(tester);
}

class _ReadyAuth extends AuthController {
  @override
  HermesConnectionState get state => HermesConnectionState.ready;

  @override
  bool get protectedRequestsAllowed => true;
}

/// [pumpScreen] without its final `pumpAndSettle`, which the spinner of a run
/// in progress would keep from ever returning.
Future<void> _mount(
  WidgetTester tester,
  ScreenshotRecorder shots,
  Widget home, {
  required Size size,
  Brightness brightness = Brightness.light,
  List<SingleChildWidget> providers = const [],
  TargetPlatform? platform,
}) async {
  await shots.start(tester, size);
  final dark = brightness == Brightness.dark;
  await tester.pumpWidget(
    shots.frame(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(create: (_) => _ReadyAuth()),
          ChangeNotifierProvider<ShareController>(
            create: (_) => ShareController(FakeShareInbox()),
          ),
          ChangeNotifierProvider(create: (_) => NotificationSettings()),
          ...providers,
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: withScreenshotFont(
            dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
          ).copyWith(platform: platform),
          home: home,
        ),
      ),
    ),
  );
  await _settle(tester);
}
