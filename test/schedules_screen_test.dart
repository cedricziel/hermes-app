import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedule_detail.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:hermes_app/src/schedules/schedules_screen.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late SchedulesController controller;
  late List<(CronRun, CronJob)> opened;

  final now = DateTime.utc(2026, 9, 20, 12);

  setUp(() {
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {
        'active': 'work',
        'current': 'work',
      });
    opened = [];
    controller = SchedulesController(
      repository: HermesCronRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
      now: () => now,
    );
  });

  tearDown(() => controller.dispose());

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Size size,
    NotificationSettings? settings,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Widget app = MaterialApp(
      theme: buildHermesLightTheme(),
      home: SchedulesScreen(
        controller: controller,
        onOpenRun: (run, job) => opened.add((run, job)),
      ),
    );
    if (settings != null) {
      app = ChangeNotifierProvider<NotificationSettings>.value(
        value: settings,
        child: app,
      );
    }
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  void jobs(List<Map<String, Object?>> rows) =>
      server.on('GET', '/api/cron/jobs', rows);

  Map<String, Object?> healthy() => cronJobRow(
    lastRunAt: '2026-09-20T10:00:00+00:00',
    lastStatus: 'ok',
    nextRunAt: '2026-09-20T15:00:00+00:00',
  );

  group('list', () {
    testWidgets('shows how a healthy job is doing', (tester) async {
      jobs([healthy()]);

      await pumpScreen(tester, size: const Size(400, 800));

      expect(find.text('Morning brief'), findsOneWidget);
      expect(find.text('Weekdays at 08:00'), findsOneWidget);
      expect(find.text('Last run succeeded 2 h ago'), findsOneWidget);
      expect(find.text('Next run in 3 h'), findsOneWidget);
      expect(find.text('Local'), findsOneWidget);
    });

    testWidgets('shows a failure with its reason', (tester) async {
      jobs([
        cronJobRow(
          name: 'Price watch',
          lastRunAt: '2026-09-20T11:20:00+00:00',
          lastStatus: 'error',
          lastError: 'Provider timeout\nTraceback ...',
        ),
      ]);

      await pumpScreen(tester, size: const Size(400, 800));

      expect(find.text('Failed 40 min ago'), findsOneWidget);
      expect(find.text('Provider timeout'), findsOneWidget);
    });

    testWidgets('shows a paused job as paused with its switch off', (
      tester,
    ) async {
      jobs([
        cronJobRow(state: 'paused', nextRunAt: '2026-09-21T08:00:00+00:00'),
      ]);

      await pumpScreen(tester, size: const Size(400, 800));

      expect(find.text('Paused'), findsWidgets);
      expect(find.textContaining('Next run'), findsNothing);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    });

    testWidgets('a failed run without a readable time still says it failed', (
      tester,
    ) async {
      jobs([cronJobRow(lastStatus: 'error', lastError: 'Boom')]);

      await pumpScreen(tester, size: const Size(400, 800));

      expect(find.text('Failed'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('says a job has not run yet', (tester) async {
      jobs([cronJobRow()]);

      await pumpScreen(tester, size: const Size(400, 800));

      expect(find.text('Not run yet'), findsOneWidget);
    });

    testWidgets('shows an empty state', (tester) async {
      jobs([]);

      await pumpScreen(tester, size: const Size(400, 800));

      expect(find.text('No scheduled tasks'), findsOneWidget);
    });

    testWidgets('shows an error with a retry that loads the jobs', (
      tester,
    ) async {
      server.on('GET', '/api/cron/jobs', {}, status: 500);
      await pumpScreen(tester, size: const Size(400, 800));
      expect(find.text('The server answered 500'), findsOneWidget);

      jobs([healthy()]);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Morning brief'), findsOneWidget);
    });

    testWidgets('the Failing filter keeps only failing jobs', (tester) async {
      jobs([
        healthy(),
        cronJobRow(id: 'bad', name: 'Broken', lastStatus: 'error'),
      ]);
      await pumpScreen(tester, size: const Size(400, 800));

      await tester.ensureVisible(find.text('Failing (1)'));
      await tester.tap(find.text('Failing (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Broken'), findsOneWidget);
      expect(find.text('Morning brief'), findsNothing);
    });

    testWidgets('the switch pauses a job and sends the request', (
      tester,
    ) async {
      jobs([healthy()]);
      server.on('POST', '/api/cron/jobs/job1/pause', {'id': 'job1'});
      await pumpScreen(tester, size: const Size(400, 800));

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(
        server.requests.any(
          (r) => r.method == 'POST' && r.path == '/api/cron/jobs/job1/pause',
        ),
        isTrue,
      );
    });

    testWidgets('a refused pause puts the switch back with a message', (
      tester,
    ) async {
      jobs([healthy()]);
      server.on('POST', '/api/cron/jobs/job1/pause', {}, status: 500);
      await pumpScreen(tester, size: const Size(400, 800));

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.textContaining('Could not pause'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });
  });

  group('detail', () {
    void detailRoutes({bool active = false}) {
      server
        ..on(
          'GET',
          '/api/cron/jobs/job1',
          cronJobRow(
            lastRunAt: '2026-09-20T10:00:00+00:00',
            lastStatus: 'ok',
            skills: ['web-search'],
            model: 'hermes-4',
            nextRunAt: '2026-09-20T15:00:00+00:00',
          ),
        )
        ..on('GET', '/api/cron/jobs/job1/runs', {
          'runs': [
            cronRunRow(
              id: 'cron_job1_2',
              startedAt: 1789900000,
              endedAt: active ? null : 1789900010,
              active: active,
            ),
            cronRunRow(
              id: 'cron_job1_1',
              startedAt: 1789800000,
              endedAt: 1789800042,
            ),
          ],
        });
    }

    testWidgets('shows the schedule, prompt, settings and runs', (
      tester,
    ) async {
      jobs([healthy()]);
      detailRoutes(active: true);
      await pumpScreen(tester, size: const Size(400, 800));

      await tester.tap(find.text('Morning brief'));
      // A run in progress shows a spinner that never settles.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('0 8 * * 1-5'), findsOneWidget);
      expect(find.text('Say good morning'), findsOneWidget);
      expect(find.text('web-search'), findsOneWidget);
      expect(find.text('hermes-4'), findsOneWidget);
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('42 s'), findsOneWidget);
      expect(find.text('Provider'), findsNothing);
    });

    testWidgets('opening a run hands its session and profile on', (
      tester,
    ) async {
      jobs([healthy()]);
      detailRoutes();
      await pumpScreen(tester, size: const Size(400, 800));
      await tester.tap(find.text('Morning brief'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('42 s'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ScheduleDetail),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.drag(find.byType(ScheduleDetail), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('42 s'));
      await tester.pumpAndSettle();

      expect(opened.single.$1.sessionId, 'cron_job1_1');
      expect(opened.single.$2.id, 'job1');
    });

    testWidgets('says when a job has never run', (tester) async {
      jobs([healthy()]);
      detailRoutes();
      server.on('GET', '/api/cron/jobs/job1/runs', {'runs': []});
      await pumpScreen(tester, size: const Size(400, 800));

      await tester.tap(find.text('Morning brief'));
      await tester.pumpAndSettle();

      expect(find.text('No runs yet'), findsOneWidget);
    });

    testWidgets('run now asks for a run and says it was requested', (
      tester,
    ) async {
      jobs([healthy()]);
      detailRoutes();
      server.on('POST', '/api/cron/jobs/job1/trigger', {'ok': true});
      await pumpScreen(tester, size: const Size(400, 800));
      await tester.tap(find.text('Morning brief'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Run now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Run requested'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });

    testWidgets('delete asks first, and cancelling sends nothing', (
      tester,
    ) async {
      jobs([healthy()]);
      detailRoutes();
      await pumpScreen(tester, size: const Size(400, 800));
      await tester.tap(find.text('Morning brief'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Delete task'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ScheduleDetail),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this task?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(server.requests.any((r) => r.method == 'DELETE'), isFalse);
    });

    testWidgets('a confirmed delete removes the job and returns to the list', (
      tester,
    ) async {
      jobs([healthy()]);
      detailRoutes();
      server.on('DELETE', '/api/cron/jobs/job1', {'ok': true});
      await pumpScreen(tester, size: const Size(400, 800));
      await tester.tap(find.text('Morning brief'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Delete task'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ScheduleDetail),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Delete task'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Morning brief'), findsNothing);
      expect(find.text('No scheduled tasks'), findsOneWidget);
    });

    testWidgets('a job that vanished returns to the list with a message', (
      tester,
    ) async {
      jobs([healthy()]);
      server
        ..on('GET', '/api/cron/jobs/job1', {}, status: 404)
        ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});
      await pumpScreen(tester, size: const Size(400, 800));

      await tester.tap(find.text('Morning brief'));
      await tester.pumpAndSettle();

      expect(find.text('No scheduled tasks'), findsOneWidget);
      expect(find.text('This task no longer exists'), findsOneWidget);
    });
  });

  group('wide layout', () {
    testWidgets('shows the list and the first job side by side', (
      tester,
    ) async {
      jobs([healthy()]);
      server
        ..on('GET', '/api/cron/jobs/job1', cronJobRow())
        ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});

      await pumpScreen(tester, size: const Size(1400, 900));

      expect(find.text('Say good morning'), findsOneWidget);
      expect(find.text('Morning brief'), findsWidgets);
      expect(find.text('No runs yet'), findsOneWidget);
    });
  });

  group('mute', () {
    testWidgets('a job can be muted from its page and unmuted', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final settings = NotificationSettings();
      await tester.runAsync(settings.load);
      jobs([healthy()]);
      server
        ..on('GET', '/api/cron/jobs/job1', cronJobRow())
        ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});
      await pumpScreen(tester, size: const Size(400, 800), settings: settings);
      await tester.tap(find.text('Morning brief'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('job-mute')));
      await tester.pumpAndSettle();
      expect(settings.isMuted('work/job1'), isTrue);
      expect(
        tester.widget<SwitchListTile>(find.byKey(const Key('job-mute'))).value,
        isTrue,
      );

      await tester.tap(find.byKey(const Key('job-mute')));
      await tester.pumpAndSettle();
      expect(settings.isMuted('work/job1'), isFalse);
    });

    testWidgets('has no mute switch without notification settings', (
      tester,
    ) async {
      jobs([healthy()]);
      server
        ..on('GET', '/api/cron/jobs/job1', cronJobRow())
        ..on('GET', '/api/cron/jobs/job1/runs', {'runs': []});
      await pumpScreen(tester, size: const Size(400, 800));
      await tester.tap(find.text('Morning brief'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('job-mute')), findsNothing);
    });
  });
}
