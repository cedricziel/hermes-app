import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/kanban/kanban_screen.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedule_detail.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/schedules/schedules_list.dart';
import 'package:hermes_app/src/schedules/schedules_screen.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/shell/shell_navigation.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
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
      providers: [
        Provider<NotificationService>.value(value: FakeNotificationService()),
      ],
    );

    Future<void> openTab(WidgetTester tester, String label) async {
      await tester.tap(
        find.descendant(
          of: find.byWidgetPredicate(
            (w) => w is NavigationBar || w is ShellNavigation,
          ),
          matching: find.text(label),
        ),
      );
      await _settle(tester);
    }

    // Comes back to the foreground, which is when the shell asks the server
    // again what it offers.
    Future<void> resume(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _settle(tester);
    }

    testWidgets('phone: Chat, Kanban and Schedules', (tester) async {
      setKanban(true);
      final shots = ScreenshotRecorder('schedules-shell-phone');
      await pumpShell(tester, shots, size: phoneSize);
      await shots.capture(tester, 'chat-with-three-tabs');

      await openTab(tester, 'Schedules');
      await shots.capture(tester, 'schedules-tab');

      await _openTile(tester, 'Price watch');
      await shots.capture(tester, 'task-opened-over-the-tabs');
      await popRoute(tester);

      await openTab(tester, 'Chat');
      await shots.capture(tester, 'back-on-chat');

      // Only now: with both pages built, pushing a route trips the
      // duplicate FloatingActionButton hero assertion.
      await openTab(tester, 'Kanban');
      await shots.capture(tester, 'kanban-tab');
    });

    testWidgets('phone: the tab follows what the server has', (tester) async {
      setCron(false);
      setKanban(false);
      final shots = ScreenshotRecorder('schedules-shell-phone-detection');
      await pumpShell(tester, shots, size: phoneSize);
      await shots.capture(tester, 'server-has-neither');

      setCron(true);
      await resume(tester);
      await shots.capture(tester, 'cron-appears');

      await openTab(tester, 'Schedules');
      await shots.capture(tester, 'schedules-open');

      setKanban(true);
      await resume(tester);
      await shots.capture(tester, 'kanban-appears-too');

      setCron(false);
      await resume(tester);
      await shots.capture(tester, 'cron-gone-back-to-chat');
    });

    testWidgets('desktop: sidebar with three destinations', (tester) async {
      setKanban(true);
      final shots = ScreenshotRecorder('schedules-shell-desktop');
      await pumpShell(tester, shots, size: desktopSize);
      await shots.capture(tester, 'chat-with-sidebar-navigation');

      await openTab(tester, 'Schedules');
      await shots.capture(tester, 'schedules-tab');

      await openTab(tester, 'Kanban');
      await shots.capture(tester, 'kanban-tab');
    });

    testWidgets('desktop: the tab follows what the server has', (tester) async {
      setCron(false);
      setKanban(false);
      final shots = ScreenshotRecorder('schedules-shell-desktop-detection');
      await pumpShell(tester, shots, size: desktopSize);
      await shots.capture(tester, 'server-has-neither');

      setCron(true);
      await resume(tester);
      await shots.capture(tester, 'cron-appears');

      await openTab(tester, 'Schedules');
      setCron(false);
      await resume(tester);
      await shots.capture(tester, 'cron-gone-back-to-chat');
    });

    for (final (flow, size) in [
      ('schedules-shell-phone-dark', phoneSize),
      ('schedules-shell-desktop-dark', desktopSize),
    ]) {
      testWidgets('$flow: Schedules', (tester) async {
        setKanban(true);
        final shots = ScreenshotRecorder(flow);
        await pumpShell(tester, shots, size: size, brightness: Brightness.dark);
        await shots.capture(tester, 'chat');
        await openTab(tester, 'Schedules');
        await shots.capture(tester, 'schedules');
      });
    }
  });

  group('list', () {
    testWidgets('phone: every state a task can be in', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-list');
      await pumpSchedules(tester, shots, size: phoneSize);
      await shots.capture(tester, 'list-top');

      final list = find.byType(ListView);
      await tester.drag(list, const Offset(0, -500));
      await _settle(tester);
      await shots.capture(tester, 'list-middle');

      await tester.drag(list, const Offset(0, -3000));
      await _settle(tester);
      await shots.capture(tester, 'list-bottom');

      await _tap(tester, find.text('Failing (2)'));
      await shots.capture(tester, 'filter-failing');

      await _tap(tester, find.text('Failing (2)'));
      await _tap(tester, find.widgetWithText(FilterChip, 'Paused'));
      await shots.capture(tester, 'filter-paused');

      await _tap(tester, find.widgetWithText(FilterChip, 'Paused'));
      await _tap(tester, find.text('All profiles'));
      await shots.capture(tester, 'all-profiles');
    });

    testWidgets('phone: pausing from the list, and a refusal', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-list-pause');
      await pumpSchedules(tester, shots, size: phoneSize);
      final morning = find.descendant(
        of: find.widgetWithText(JobTile, 'Morning brief'),
        matching: find.byType(Switch),
      );

      await _reveal(tester, morning, _jobList);
      await tester.tap(morning);
      await _settle(tester);
      await shots.capture(tester, 'paused');

      await _reveal(tester, morning, _jobList);
      await tester.tap(morning);
      await _settle(tester);
      await shots.capture(tester, 'resumed');

      server.on('POST', '/api/cron/jobs/job1/pause', {}, status: 500);
      await _reveal(tester, morning, _jobList);
      await tester.tap(morning);
      await _frames(tester, 600);
      await shots.capture(tester, 'refused');
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
    });

    testWidgets('phone: loading, empty, failed, nothing matches', (
      tester,
    ) async {
      final held = Completer<FakeResponse>();
      server.onRequest('GET', '/api/cron/jobs', (_) => held.future);
      final shots = ScreenshotRecorder('schedules-phone-list-states');
      await pumpSchedules(tester, shots, size: phoneSize);
      await shots.capture(tester, 'loading');

      held.complete((status: 200, body: <Object?>[]));
      await _settle(tester);
      await shots.capture(tester, 'empty');

      server.on('GET', '/api/cron/jobs', {}, status: 500);
      await tester.tap(find.byTooltip('Refresh'));
      await _settle(tester);
      await shots.capture(tester, 'still-empty-after-failed-refresh');

      cron
        ..rows.removeWhere((r) => r['state'] != 'scheduled')
        ..serve();
      await tester.tap(find.byTooltip('Refresh'));
      await _settle(tester);
      await _tap(tester, find.widgetWithText(FilterChip, 'Paused'));
      await shots.capture(tester, 'no-match-for-filter');
    });

    testWidgets('phone: the first load fails, then works', (tester) async {
      server.on('GET', '/api/cron/jobs', {}, status: 500);
      final shots = ScreenshotRecorder('schedules-phone-list-load-failed');
      await pumpSchedules(tester, shots, size: phoneSize);
      await shots.capture(tester, 'load-failed');

      server.on('GET', '/api/cron/jobs', {}, status: 502);
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      await shots.capture(tester, 'load-failed-again');

      server.on('GET', '/api/cron/jobs', [
        for (final r in cron.rows) {...r},
      ]);
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      await shots.capture(tester, 'loaded');
    });

    testWidgets('desktop: list and detail side by side', (tester) async {
      final shots = ScreenshotRecorder('schedules-desktop-list');
      await pumpSchedules(tester, shots, size: desktopSize);
      await shots.capture(tester, 'first-task-selected');

      await _openTile(tester, 'Price watch');
      await shots.capture(tester, 'failed-task');

      await _openTile(tester, 'Weekly digest');
      await shots.capture(tester, 'paused-task');

      await _openTile(tester, _longName);
      await shots.capture(tester, 'long-task');

      await _tap(tester, find.text('Failing (2)'));
      await shots.capture(tester, 'filter-failing');
    });

    testWidgets('desktop: empty, failed and nothing selected', (tester) async {
      server.on('GET', '/api/cron/jobs', <Object?>[]);
      final shots = ScreenshotRecorder('schedules-desktop-list-states');
      await pumpSchedules(tester, shots, size: desktopSize);
      await shots.capture(tester, 'empty');

      server.on('GET', '/api/cron/jobs', {}, status: 500);
      await tester.tap(find.byTooltip('Refresh'));
      await _settle(tester);
      await shots.capture(tester, 'refresh-failed');
    });

    testWidgets('desktop: the first load fails', (tester) async {
      server.on('GET', '/api/cron/jobs', {}, status: 500);
      final shots = ScreenshotRecorder('schedules-desktop-list-load-failed');
      await pumpSchedules(tester, shots, size: desktopSize);
      await shots.capture(tester, 'load-failed');
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

        await _openTile(tester, 'Price watch');
        await shots.capture(tester, 'failed-task');

        if (size == phoneSize) {
          await tester.drag(find.byType(ScheduleDetail), const Offset(0, -700));
          await _settle(tester);
          await shots.capture(tester, 'failed-task-lower');
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

      await tester.tap(find.text('Pause'));
      await _settle(tester);
      await shots.capture(tester, 'paused');

      await tester.tap(find.text('Resume'));
      await _settle(tester);
      await shots.capture(tester, 'resumed');

      await tester.tap(find.text('Run now'));
      await _frames(tester, 400);
      await shots.capture(tester, 'run-requested');
      await _frames(tester, 6000);

      await tester.drag(detailList(), const Offset(0, -3000));
      await _settle(tester);
      await shots.capture(tester, 'run-history-and-delete');

      await tester.tap(find.text('Delete task'));
      await _settle(tester);
      await shots.capture(tester, 'delete-confirm');

      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      await shots.capture(tester, 'delete-cancelled');

      await tester.tap(find.text('Delete task'));
      await _settle(tester);
      await tester.tap(find.text('Delete'));
      await _settle(tester);
      await shots.capture(tester, 'deleted-back-on-list');
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
      await _frames(tester, 5000);

      await tester.tap(find.text('Run now'));
      await _frames(tester, 400);
      await shots.capture(tester, 'run-refused');
      await _frames(tester, 5000);

      await tester.drag(detailList(), const Offset(0, -3000));
      await _settle(tester);
      await tester.tap(find.text('Delete task'));
      await _settle(tester);
      await tester.tap(find.text('Delete'));
      await _frames(tester, 400);
      await shots.capture(tester, 'delete-refused');
    });

    testWidgets('phone: a failed task, a delivery failure, a long one', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('schedules-phone-detail-variants');
      await pumpSchedules(tester, shots, size: phoneSize);

      Future<void> open(String title, String step) async {
        await _openTile(tester, title);
        await shots.capture(tester, step);
        await tester.drag(detailList(), const Offset(0, -3000));
        await _settle(tester);
        await shots.capture(tester, '$step-lower');
        await popRoute(tester);
      }

      await open('Price watch', 'failed');
      await open('Standup notes', 'delivery-failed');
      await open(_longName, 'long');
      await open('Weekly digest', 'paused');
      await open('Renew the TLS certificate', 'completed');
      await open('Check the build and tell me', 'no-name');
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
    });

    testWidgets('desktop: run now, pause, delete', (tester) async {
      final shots = ScreenshotRecorder('schedules-desktop-detail');
      await pumpSchedules(tester, shots, size: desktopSize);
      await _openTile(tester, 'Morning brief');
      await shots.capture(tester, 'running-task');

      await tester.tap(find.text('Pause'));
      await _settle(tester);
      await shots.capture(tester, 'paused');

      await tester.tap(find.text('Resume'));
      await _settle(tester);

      await tester.tap(find.text('Run now'));
      await _frames(tester, 400);
      await shots.capture(tester, 'run-requested');
      await _frames(tester, 6000);

      await tester.drag(detailList(), const Offset(0, -3000));
      await _settle(tester);
      await shots.capture(tester, 'run-history-and-delete');

      await tester.tap(find.text('Delete task'));
      await _settle(tester);
      await shots.capture(tester, 'delete-confirm');

      await tester.tap(find.text('Delete'));
      await _settle(tester);
      await shots.capture(tester, 'deleted');
    });

    testWidgets('desktop: a task that has never run, and one that is done', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('schedules-desktop-detail-variants');
      await pumpSchedules(tester, shots, size: desktopSize);

      Future<void> open(String title, String step) async {
        await _openTile(tester, title);
        await shots.capture(tester, step);
      }

      await open('Check the build and tell me', 'never-run');
      await open('Renew the TLS certificate', 'completed');
      await open('Standup notes', 'delivery-failed');
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
      await tester.tap(find.text('New'));
      await _settle(tester);
    }

    Future<void> openCustom(WidgetTester tester) async {
      await openGallery(tester);
      await tester.tap(find.byKey(const Key('custom-task')));
      await _settle(tester);
    }

    Finder mode(String label) => find.widgetWithText(ChoiceChip, label);

    testWidgets('phone: pick a template and fill it in', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-create-template');
      await pumpSchedules(tester, shots, size: phoneSize);

      await openGallery(tester);
      await shots.capture(tester, 'gallery');

      await tester.enterText(
        find.byKey(const Key('blueprint-search')),
        'urgent',
      );
      await _settle(tester);
      await shots.capture(tester, 'gallery-searched');

      await tester.enterText(find.byKey(const Key('blueprint-search')), 'zzz');
      await _settle(tester);
      await shots.capture(tester, 'gallery-nothing-found');

      await tester.enterText(find.byKey(const Key('blueprint-search')), '');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Daily'));
      await _settle(tester);
      await shots.capture(tester, 'gallery-category');

      await tester.tap(find.text('Morning briefing'));
      await _settle(tester);
      await shots.capture(tester, 'template-form');

      server.on('POST', '/api/cron/blueprints/instantiate', {
        'detail': "invalid time '25:00' — use HH:MM (24h)",
      }, status: 422);
      await tester.tap(find.widgetWithText(ChoiceChip, 'telegram'));
      await _settle(tester);
      await tester.tap(find.text('Create task'));
      await _settle(tester);
      await shots.capture(tester, 'template-refused');

      final held = Completer<FakeResponse>();
      server.onRequest(
        'POST',
        '/api/cron/blueprints/instantiate',
        (_) => held.future,
      );
      await tester.tap(find.text('Create task'));
      await _frames(tester, 300);
      await shots.capture(tester, 'template-saving');

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
    });

    testWidgets('phone: the gallery has no templates', (tester) async {
      server.on('GET', '/api/cron/blueprints', {}, status: 500);
      final shots = ScreenshotRecorder('schedules-phone-create-gallery-failed');
      await pumpSchedules(tester, shots, size: phoneSize);
      await openGallery(tester);
      await shots.capture(tester, 'templates-failed');
    });

    testWidgets('phone: the ways to say when', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-create-when');
      await pumpSchedules(tester, shots, size: phoneSize);
      await openCustom(tester);
      await shots.capture(tester, 'empty-form');

      await type(tester, 'job-name', 'Price watch for a GPU');
      await type(
        tester,
        'job-prompt',
        'Check the price of the RTX card on the three shops I follow and '
            'tell me if it dropped below 700.',
      );
      await shots.capture(tester, 'filled');

      await tapVisible(tester, mode('Every'));
      await shots.capture(tester, 'every');

      await type(tester, 'when-amount', '6');
      await tapVisible(tester, find.byKey(const Key('when-unit')));
      await shots.capture(tester, 'every-unit-menu');
      await tester.tap(find.text('hours').last);
      await _settle(tester);
      await shots.capture(tester, 'every-6-hours');

      await type(tester, 'when-amount', '');
      await shots.capture(tester, 'every-nothing-typed');

      await tapVisible(tester, mode('Daily'));
      await shots.capture(tester, 'daily');
      await tapVisible(tester, find.byKey(const Key('when-time')));
      await shots.capture(tester, 'daily-time-picker');
      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      await tapVisible(tester, mode('Weekly'));
      await shots.capture(tester, 'weekly');
      for (final day in ['Tue', 'Wed', 'Fri']) {
        await tester.tap(find.widgetWithText(FilterChip, day));
        await _settle(tester);
      }
      await shots.capture(tester, 'weekly-some-days');

      await tapVisible(tester, mode('Once'));
      await shots.capture(tester, 'once');
      await tapVisible(tester, find.byKey(const Key('when-date')));
      await shots.capture(tester, 'once-date-picker');
      await tester.tap(find.text('Cancel'));
      await _settle(tester);

      await tapVisible(tester, mode('Cron'));
      await type(tester, 'when-cron', '*/7 9-17 * * 1-5');
      await shots.capture(tester, 'cron');
    });

    testWidgets('phone: validation, refusal, saving, saved', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-create-save');
      await pumpSchedules(tester, shots, size: phoneSize);
      await openCustom(tester);

      await tapVisible(tester, find.text('Save task'));
      await shots.capture(tester, 'nothing-to-run');

      await type(tester, 'job-prompt', 'Say hello');
      await tapVisible(tester, find.byKey(const Key('job-advanced')));
      await type(tester, 'job-script', '../evil.sh');
      await type(tester, 'job-skills', 'web-search, calendar');
      await type(tester, 'job-model', 'hermes-4');
      await shots.capture(tester, 'advanced');

      server.on('POST', '/api/cron/jobs', {
        'detail': 'script must be inside /home/hermes/work/scripts',
      }, status: 400);
      await tapVisible(tester, find.text('Save task'));
      await shots.capture(tester, 'refused-by-server');

      await type(tester, 'job-script', '');
      await tapVisible(tester, find.byKey(const Key('job-deliver')));
      await shots.capture(tester, 'deliver-menu');
      await tester.tap(find.text('Discord').last);
      await _settle(tester);
      await shots.capture(tester, 'deliver-without-home-channel');

      await tapVisible(tester, find.byKey(const Key('job-profile')));
      await shots.capture(tester, 'profile-menu');
      await tester.tap(find.text('home').last);
      await _settle(tester);

      await tester.tap(find.byKey(const Key('job-paused')));
      await _settle(tester);
      await shots.capture(tester, 'start-paused');

      final held = Completer<void>();
      cron.holdCreate = held;
      server.on('POST', '/api/cron/jobs', {}, status: 200);
      cron.serve();
      await tapVisible(tester, find.text('Save task'));
      await _frames(tester, 300);
      await shots.capture(tester, 'saving');

      held.complete();
      await _settle(tester);
      await shots.capture(tester, 'saved');
    });

    testWidgets('phone: leaving the form asks first', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-create-discard');
      await pumpSchedules(tester, shots, size: phoneSize);
      await openCustom(tester);
      await type(tester, 'job-prompt', 'half a thought');

      await tester.tap(find.byType(CloseButton));
      await _settle(tester);
      await shots.capture(tester, 'discard-changes');

      await tester.tap(find.text('Discard'));
      await _settle(tester);
      await shots.capture(tester, 'discarded');
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
      await type(tester, 'job-prompt', 'Say good morning, kindly');
      await tapVisible(tester, find.text('Save task'));
      await shots.capture(tester, 'saved');
      await popRoute(tester);

      await edit('Price watch');
      await shots.capture(tester, 'interval-task');
      await popRoute(tester);
      await popRoute(tester);

      await edit(_longName);
      await shots.capture(tester, 'long-task');
      await type(tester, 'job-name', 'Renamed');
      await tester.tap(find.byType(CloseButton));
      await _settle(tester);
      await shots.capture(tester, 'discard-edit');
    });

    testWidgets('desktop: pick a template and fill it in', (tester) async {
      final shots = ScreenshotRecorder('schedules-desktop-create-template');
      await pumpSchedules(tester, shots, size: desktopSize);
      await openGallery(tester);
      await shots.capture(tester, 'gallery');

      await tester.tap(find.text('Morning briefing'));
      await _settle(tester);
      await shots.capture(tester, 'template-form');
    });

    testWidgets('desktop: custom task', (tester) async {
      final shots = ScreenshotRecorder('schedules-desktop-create');
      await pumpSchedules(tester, shots, size: desktopSize);
      await openCustom(tester);
      await shots.capture(tester, 'empty-form');

      await tapVisible(tester, find.text('Save task'));
      await shots.capture(tester, 'nothing-to-run');

      await type(tester, 'job-name', 'Price watch for a GPU');
      await type(tester, 'job-prompt', 'Check the price of the RTX card.');
      await tapVisible(tester, mode('Weekly'));
      await shots.capture(tester, 'weekly');

      await tapVisible(tester, mode('Every'));
      await tapVisible(tester, find.byKey(const Key('job-advanced')));
      await shots.capture(tester, 'every-advanced');

      final held = Completer<void>();
      cron.holdCreate = held;
      cron.serve();
      await tapVisible(tester, find.text('Save task'));
      await _frames(tester, 300);
      await shots.capture(tester, 'saving');

      held.complete();
      await _settle(tester);
      await shots.capture(tester, 'saved');
    });

    testWidgets('desktop: edit a task', (tester) async {
      final shots = ScreenshotRecorder('schedules-desktop-edit');
      await pumpSchedules(tester, shots, size: desktopSize);
      await _openTile(tester, 'Price watch');
      await tester.tap(find.text('Edit'));
      await _settle(tester);
      await shots.capture(tester, 'interval-task');

      await type(tester, 'job-prompt', 'Check the price again');
      await tapVisible(tester, find.text('Save task'));
      await shots.capture(tester, 'saved');
    });

    testWidgets('phone: dark form', (tester) async {
      final shots = ScreenshotRecorder('schedules-phone-create-dark');
      await pumpSchedules(
        tester,
        shots,
        size: phoneSize,
        brightness: Brightness.dark,
      );
      await openGallery(tester);
      await shots.capture(tester, 'gallery');
      await tester.tap(find.byKey(const Key('custom-task')));
      await _settle(tester);
      await tapVisible(tester, find.text('Save task'));
      await shots.capture(tester, 'form-with-error');
      await tapVisible(tester, mode('Weekly'));
      await shots.capture(tester, 'weekly');
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

/// Scrolls [finder] into view and taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await _frames(tester, 100);
  await tester.tap(finder);
  await _settle(tester);
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
}) async {
  await shots.start(tester, size);
  final dark = brightness == Brightness.dark;
  await tester.pumpWidget(
    shots.frame(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(),
          ),
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
          ),
          home: home,
        ),
      ),
    ),
  );
  await _settle(tester);
}
