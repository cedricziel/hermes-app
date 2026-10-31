import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedule_alerts.dart';
import 'package:hermes_app/src/schedules/schedule_baseline.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';

void main() {
  CronJob job(Map<String, Object?> row) => CronJob.fromJson(row)!;

  Map<String, Object?> ran(
    String at, {
    String id = 'job1',
    String name = 'Morning brief',
    String status = 'ok',
    String? error,
    String? deliveryError,
    String profile = 'work',
  }) => cronJobRow(
    id: id,
    name: name,
    lastRunAt: at,
    lastStatus: status,
    lastError: error,
    lastDeliveryError: deliveryError,
    profile: profile,
  );

  group('runsSince', () {
    test('reports nothing on the first look and sets every baseline', () {
      final pass = runsSince(null, [
        job(ran('2026-09-20T08:00:00+00:00')),
        job(cronJobRow(id: 'new')),
      ]);

      expect(pass.ran, isEmpty);
      expect(pass.baseline.keys, ['work/job1', 'work/new']);
    });

    test('reports a job whose last run moved on', () {
      final first = runsSince(null, [job(ran('2026-09-20T08:00:00+00:00'))]);

      final next = runsSince(first.baseline, [
        job(ran('2026-09-21T08:00:00+00:00')),
      ]);

      expect(next.ran.map((j) => j.id), ['job1']);
    });

    test('does not report a run it has already seen', () {
      final first = runsSince(null, [job(ran('2026-09-20T08:00:00+00:00'))]);

      final next = runsSince(first.baseline, [
        job(ran('2026-09-20T08:00:00+00:00')),
      ]);

      expect(next.ran, isEmpty);
    });

    test('does not report a job seen for the first time later', () {
      final first = runsSince(null, [job(ran('2026-09-20T08:00:00+00:00'))]);

      final next = runsSince(first.baseline, [
        job(ran('2026-09-20T08:00:00+00:00')),
        job(ran('2026-09-20T09:00:00+00:00', id: 'other')),
      ]);

      expect(next.ran, isEmpty);
    });

    test('reports the first run of a job that had none', () {
      final first = runsSince(null, [job(cronJobRow())]);

      final next = runsSince(first.baseline, [
        job(ran('2026-09-20T08:00:00+00:00')),
      ]);

      expect(next.ran, hasLength(1));
    });

    test('a run time that moves backwards is not a run', () {
      final first = runsSince(null, [job(ran('2026-09-21T08:00:00+00:00'))]);

      final back = runsSince(first.baseline, [
        job(ran('2026-09-20T08:00:00+00:00')),
      ]);
      expect(back.ran, isEmpty);

      final forward = runsSince(back.baseline, [
        job(ran('2026-09-20T09:00:00+00:00')),
      ]);
      expect(forward.ran, hasLength(1));
    });

    test('keeps jobs of two profiles with one id apart', () {
      final first = runsSince(null, [
        job(ran('2026-09-20T08:00:00+00:00')),
        job(ran('2026-09-20T08:00:00+00:00', profile: 'home')),
      ]);

      final next = runsSince(first.baseline, [
        job(ran('2026-09-20T08:00:00+00:00')),
        job(ran('2026-09-21T08:00:00+00:00', profile: 'home')),
      ]);

      expect(next.ran.map((j) => j.key), ['home/job1']);
    });

    test('a job that is gone leaves no baseline behind', () {
      final first = runsSince(null, [job(ran('2026-09-20T08:00:00+00:00'))]);

      final next = runsSince(first.baseline, const []);

      expect(next.baseline, isEmpty);
    });
  });

  group('alertsFor', () {
    test('says finished, failed or not delivered, and nothing else', () {
      final alerts = alertsFor([
        job(ran('2026-09-20T08:00:00+00:00', name: 'A')),
        job(
          ran(
            '2026-09-20T08:00:00+00:00',
            name: 'B',
            status: 'error',
            error: 'Provider timeout',
          ),
        ),
        job(
          ran(
            '2026-09-20T08:00:00+00:00',
            name: 'C',
            deliveryError: 'no home channel',
          ),
        ),
        job(
          ran(
            '2026-09-20T08:00:00+00:00',
            name: 'D',
            status: 'delivery_queued',
          ),
        ),
      ]);

      expect(alerts.map((a) => (a.title, a.body)), [
        ('A', 'Finished'),
        ('B', 'Failed'),
        ('C', 'Result could not be delivered'),
        ('D', 'Finished'),
      ]);
      expect(alerts.every((a) => !a.body.contains('timeout')), isTrue);
    });

    test(
      'names the job and its profile so it replaces its own notification',
      () {
        final a = alertsFor([job(ran('2026-09-20T08:00:00+00:00'))]).single;

        expect(a.jobId, 'job1');
        expect(a.profile, 'work');
        expect(a.threadId, 'job:job1');
      },
    );

    test('names the profile when it is not the one in use', () {
      final alerts = alertsFor([
        job(ran('2026-09-20T08:00:00+00:00', profile: 'home')),
      ], activeProfile: 'work');

      expect(alerts.single.title, 'Morning brief (home)');
    });

    test('does not name the profile in use', () {
      final alerts = alertsFor([
        job(ran('2026-09-20T08:00:00+00:00')),
      ], activeProfile: 'work');

      expect(alerts.single.title, 'Morning brief');
    });

    test('folds a burst into one notification with the count', () {
      final ranJobs = [
        for (var i = 0; i < 7; i++)
          job(
            ran(
              '2026-09-20T08:00:00+00:00',
              id: 'j$i',
              status: i < 2 ? 'error' : 'ok',
            ),
          ),
      ];

      final alerts = alertsFor(ranJobs);

      expect(alerts, hasLength(1));
      expect(alerts.single.title, 'Scheduled tasks');
      expect(alerts.single.body, '7 scheduled tasks ran, 2 failed');
    });

    test('a burst without a failure says only how many ran', () {
      final ranJobs = [
        for (var i = 0; i < 6; i++)
          job(ran('2026-09-20T08:00:00+00:00', id: 'j$i')),
      ];

      expect(alertsFor(ranJobs).single.body, '6 scheduled tasks ran');
    });

    test('five runs are still one each', () {
      final ranJobs = [
        for (var i = 0; i < 5; i++)
          job(ran('2026-09-20T08:00:00+00:00', id: 'j$i')),
      ];

      expect(alertsFor(ranJobs), hasLength(5));
    });
  });

  group('ScheduleWatcher', () {
    late FakeHermesServer server;
    late FakeNotificationService service;
    late NotificationSettings settings;
    late ScheduleWatcher watcher;

    void jobs(List<Map<String, Object?>> rows) =>
        server.on('GET', '/api/cron/jobs', rows);

    int jobRequests() =>
        server.requests.where((r) => r.path == '/api/cron/jobs').length;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      server = FakeHermesServer()
        ..on('GET', '/api/profiles/active', {
          'active': 'work',
          'current': 'work',
        });
      service = FakeNotificationService();
      settings = NotificationSettings();
      await settings.load();
      watcher = ScheduleWatcher(
        repository: HermesCronRepository(server.client().raw),
        service: service,
        settings: settings,
        profiles: HermesProfilesRepository(server.client().raw),
        account: () => 'acct',
        interval: const Duration(minutes: 1),
      );
    });

    tearDown(() => watcher.dispose());

    Future<void> look() => watcher.check();

    testWidgets('pause fences held jobs before mute and baseline writes', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await settings.setMuted('work/other', true);
        jobs([
          ran('2026-09-20T08:00:00+00:00'),
          ran('2026-09-20T08:00:00+00:00', id: 'other'),
        ]);
        watcher.available = true;
        await look();
        final held = Completer<FakeResponse>();
        final started = Completer<void>();
        server.onRequest('GET', '/api/cron/jobs', (_) {
          started.complete();
          return held.future;
        });
        final pending = look();
        await started.future;

        watcher.paused = true;
        held.complete((status: 200, body: [ran('2026-09-21T08:00:00+00:00')]));
        await pending;

        expect(settings.isMuted('work/other'), isTrue);
        expect(
          (await ScheduleBaseline().read('acct'))!['work/job1'],
          DateTime.utc(2026, 9, 20, 8),
        );
        expect(service.shown, isEmpty);
      });
    });

    testWidgets('resume checks fresh while old jobs cannot clear newer work', (
      tester,
    ) async {
      await tester.runAsync(() async {
        jobs([ran('2026-09-20T08:00:00+00:00')]);
        watcher.available = true;
        await look();
        final old = Completer<FakeResponse>();
        final oldStarted = Completer<void>();
        server.onRequest('GET', '/api/cron/jobs', (_) {
          oldStarted.complete();
          return old.future;
        });
        final pendingOld = look();
        await oldStarted.future;
        watcher.paused = true;
        jobs([ran('2026-09-22T08:00:00+00:00')]);

        watcher.paused = false;
        final resumed = look();
        await pumpEventQueue();
        expect(jobRequests(), 3);
        await resumed;
        expect(service.shown, hasLength(1));
        final fresh = Completer<FakeResponse>();
        final freshStarted = Completer<void>();
        server.onRequest('GET', '/api/cron/jobs', (_) {
          if (!freshStarted.isCompleted) freshStarted.complete();
          return fresh.future;
        });
        final pendingFresh = look();
        await freshStarted.future;
        old.complete((status: 200, body: [ran('2026-09-21T08:00:00+00:00')]));
        await pendingOld;
        final joined = look();
        await pumpEventQueue();
        expect(jobRequests(), 4);
        expect(
          (await ScheduleBaseline().read('acct'))!['work/job1'],
          DateTime.utc(2026, 9, 22, 8),
        );
        fresh.complete((status: 200, body: [ran('2026-09-22T08:00:00+00:00')]));
        await Future.wait([pendingFresh, joined]);

        expect(service.shown, hasLength(1));
      });
    });

    testWidgets('pause fences a held baseline read', (tester) async {
      await tester.runAsync(() async {
        watcher.dispose();
        final baseline = _HeldBaseline();
        await baseline.write('acct', {
          'work/job1': DateTime.utc(2026, 9, 20, 8),
        });
        watcher = ScheduleWatcher(
          repository: HermesCronRepository(server.client().raw),
          service: service,
          settings: settings,
          baseline: baseline,
          account: () => 'acct',
        );
        jobs([ran('2026-09-21T08:00:00+00:00')]);
        watcher.available = true;
        final pending = look();
        await baseline.started.future;

        watcher.paused = true;
        baseline.release.complete();
        await pending;

        expect(
          (await ScheduleBaseline().read('acct'))!['work/job1'],
          DateTime.utc(2026, 9, 20, 8),
        );
        expect(service.shown, isEmpty);
      });
    });

    testWidgets(
      'pause fences a held profile lookup before committing the run',
      (tester) async {
        await tester.runAsync(() async {
          jobs([ran('2026-09-20T08:00:00+00:00')]);
          watcher.available = true;
          await look();
          final held = Completer<FakeResponse>();
          final started = Completer<void>();
          server.onRequest('GET', '/api/profiles/active', (_) {
            started.complete();
            return held.future;
          });
          jobs([ran('2026-09-21T08:00:00+00:00')]);
          final pending = look();
          await started.future;

          watcher.paused = true;
          held.complete((
            status: 200,
            body: {'active': 'work', 'current': 'work'},
          ));
          await pending;

          expect(
            (await ScheduleBaseline().read('acct'))!['work/job1'],
            DateTime.utc(2026, 9, 20, 8),
          );
          expect(service.shown, isEmpty);
        });
      },
    );

    testWidgets('paused timers and explicit checks start no lookups', (
      tester,
    ) async {
      jobs([ran('2026-09-20T08:00:00+00:00')]);
      watcher.available = true;
      await tester.pumpAndSettle();

      watcher.paused = true;
      await look();
      await tester.pump(const Duration(minutes: 3));
      await tester.pumpAndSettle();

      expect(jobRequests(), 1);
      watcher.dispose();
      await look();
      expect(jobRequests(), 1);
    });

    testWidgets(
      'pause prevents delivery after guarded notification preparation',
      (tester) async {
        await tester.runAsync(() async {
          watcher.dispose();
          final guarded = _HeldNotificationService();
          watcher = ScheduleWatcher(
            repository: HermesCronRepository(server.client().raw),
            service: guarded,
            settings: settings,
            account: () => 'acct',
          );
          jobs([ran('2026-09-20T08:00:00+00:00')]);
          watcher.available = true;
          await look();
          jobs([ran('2026-09-21T08:00:00+00:00')]);
          final pending = look();
          await guarded.started.future;

          watcher.paused = true;
          guarded.release.complete();
          await pending;

          expect(guarded.shown, isEmpty);
        });
      },
    );

    testWidgets('announces a run after the first look, not before', (
      tester,
    ) async {
      await tester.runAsync(() async {
        jobs([ran('2026-09-20T08:00:00+00:00')]);
        watcher.available = true;
        await look();
        expect(service.shown, isEmpty);

        jobs([ran('2026-09-21T08:00:00+00:00')]);
        await look();

        expect(service.shown.single.title, 'Morning brief');
        expect(service.shown.single.body, 'Finished');
        expect(service.shown.single.jobId, 'job1');
      });
    });

    testWidgets('does not look while the server has no cron routes', (
      tester,
    ) async {
      await tester.runAsync(() async {
        jobs([ran('2026-09-20T08:00:00+00:00')]);

        await look();

        expect(jobRequests(), 0);
      });
    });

    testWidgets('a muted job is silent', (tester) async {
      await tester.runAsync(() async {
        await settings.setMuted('work/job1', true);
        jobs([ran('2026-09-20T08:00:00+00:00')]);
        watcher.available = true;
        await look();

        jobs([ran('2026-09-21T08:00:00+00:00')]);
        await look();

        expect(service.shown, isEmpty);
      });
    });

    testWidgets(
      'does not post while Schedules is in front, nor repeat it later',
      (tester) async {
        await tester.runAsync(() async {
          jobs([ran('2026-09-20T08:00:00+00:00')]);
          watcher.available = true;
          await look();
          watcher.schedulesInFront = true;

          jobs([ran('2026-09-21T08:00:00+00:00')]);
          await look();
          watcher.schedulesInFront = false;
          await look();

          expect(service.shown, isEmpty);
        });
      },
    );

    testWidgets(
      'a switched off setting stops the looking and restarts the baseline',
      (tester) async {
        await tester.runAsync(() async {
          jobs([ran('2026-09-20T08:00:00+00:00')]);
          watcher.available = true;
          await look();
          await settings.setScheduleAlerts(false);
          final before = jobRequests();

          jobs([ran('2026-09-21T08:00:00+00:00')]);
          await look();
          expect(jobRequests(), before);

          await settings.setScheduleAlerts(true);
          await pumpEventQueue();
          await look();

          expect(service.shown, isEmpty);
        });
      },
    );

    testWidgets('notifications off stops the looking', (tester) async {
      await tester.runAsync(() async {
        await settings.setEnabled(false);
        jobs([ran('2026-09-20T08:00:00+00:00')]);
        watcher.available = true;

        await look();

        expect(jobRequests(), 0);
      });
    });

    testWidgets('names the profile of a job that is not the active one', (
      tester,
    ) async {
      await tester.runAsync(() async {
        jobs([ran('2026-09-20T08:00:00+00:00', profile: 'home')]);
        watcher.available = true;
        await look();

        jobs([ran('2026-09-21T08:00:00+00:00', profile: 'home')]);
        await look();

        expect(service.shown.single.title, 'Morning brief (home)');
      });
    });

    testWidgets('drops the mute of a job that is gone', (tester) async {
      await tester.runAsync(() async {
        await settings.setMuted('work/gone', true);
        jobs([ran('2026-09-20T08:00:00+00:00')]);
        watcher.available = true;

        await look();
        await pumpEventQueue();

        expect(settings.isMuted('work/gone'), isFalse);
      });
    });

    group('baseline kept on the device', () {
      late ScheduleBaseline stored;
      setUp(() => stored = ScheduleBaseline());

      testWidgets('is saved after each look', (tester) async {
        await tester.runAsync(() async {
          jobs([ran('2026-09-20T08:00:00+00:00')]);
          watcher.available = true;
          await look();

          expect(await stored.read('acct'), {
            'work/job1': DateTime.utc(2026, 9, 20, 8),
          });
        });
      });

      testWidgets('is loaded before the first look', (tester) async {
        await tester.runAsync(() async {
          await stored.write('acct', {
            'work/job1': DateTime.utc(2026, 9, 20, 8),
          });
          jobs([ran('2026-09-21T08:00:00+00:00')]);
          watcher.available = true;

          await look();

          expect(service.shown.single.title, 'Morning brief');
        });
      });

      testWidgets('does not announce a run a background run announced', (
        tester,
      ) async {
        await tester.runAsync(() async {
          jobs([ran('2026-09-20T08:00:00+00:00')]);
          watcher.available = true;
          await look();
          await stored.write('acct', {
            'work/job1': DateTime.utc(2026, 9, 21, 8),
          });

          jobs([ran('2026-09-21T08:00:00+00:00')]);
          await look();

          expect(service.shown, isEmpty);
        });
      });

      testWidgets('is forgotten when the setting is switched off', (
        tester,
      ) async {
        await tester.runAsync(() async {
          jobs([ran('2026-09-20T08:00:00+00:00')]);
          watcher.available = true;
          await look();

          await settings.setScheduleAlerts(false);
          await pumpEventQueue();

          expect(await stored.read('acct'), isNull);
        });
      });

      testWidgets('is forgotten when the cron routes go away', (tester) async {
        await tester.runAsync(() async {
          jobs([ran('2026-09-20T08:00:00+00:00')]);
          watcher.available = true;
          await look();

          watcher.available = false;
          await pumpEventQueue();

          expect(await stored.read('acct'), isNull);
        });
      });

      testWidgets('of another account is not used', (tester) async {
        await tester.runAsync(() async {
          await stored.write('other', {
            'work/job1': DateTime.utc(2026, 9, 20, 8),
          });
          jobs([ran('2026-09-21T08:00:00+00:00')]);
          watcher.available = true;

          await look();

          expect(service.shown, isEmpty);
          expect(await stored.read('acct'), isNotNull);
        });
      });

      testWidgets('is gone before the look that follows its removal', (
        tester,
      ) async {
        await tester.runAsync(() async {
          jobs([ran('2026-09-20T08:00:00+00:00')]);
          final slow = _SlowClearPrefs();
          SharedPreferencesAsyncPlatform.instance = slow;
          final fresh = ScheduleWatcher(
            repository: HermesCronRepository(server.client().raw),
            service: service,
            settings: settings,
            baseline: ScheduleBaseline(),
            account: () => 'acct',
          );
          addTearDown(fresh.dispose);
          await ScheduleBaseline().write('acct', {
            'work/job1': DateTime.utc(2026, 9, 20, 8),
          });
          fresh.available = true;
          await fresh.check();
          fresh.available = false;
          jobs([ran('2026-09-21T08:00:00+00:00')]);
          fresh.available = true;

          await fresh.check();

          expect(service.shown, isEmpty);
        });
      });

      testWidgets('keeps a run unannounced when saving the baseline fails', (
        tester,
      ) async {
        await tester.runAsync(() async {
          await stored.write('acct', {
            'work/job1': DateTime.utc(2026, 9, 20, 8),
          });
          SharedPreferencesAsyncPlatform.instance = _FailingWritePrefs();
          final failing = ScheduleWatcher(
            repository: HermesCronRepository(server.client().raw),
            service: service,
            settings: settings,
            baseline: ScheduleBaseline(),
            account: () => 'acct',
          );
          jobs([ran('2026-09-21T08:00:00+00:00')]);
          failing.available = true;
          await failing.check();
          failing.dispose();
          expect(service.shown, isEmpty);

          watcher.available = true;
          await look();

          expect(service.shown, hasLength(1));
        });
      });
    });

    testWidgets('keeps quiet after a failed look and tries again', (
      tester,
    ) async {
      await tester.runAsync(() async {
        watcher.available = true;
        jobs([ran('2026-09-20T08:00:00+00:00')]);
        await look();
        server.on('GET', '/api/cron/jobs', {}, status: 500);
        await look();

        jobs([ran('2026-09-21T08:00:00+00:00')]);
        await look();

        expect(service.shown, hasLength(1));
      });
    });
  });

  group('timing', () {
    testWidgets('looks every minute in front and not in the background', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final server = FakeHermesServer()
        ..on('GET', '/api/cron/jobs', [ran('2026-09-20T08:00:00+00:00')]);
      final settings = NotificationSettings();
      await settings.load();
      final watcher = ScheduleWatcher(
        repository: HermesCronRepository(server.client().raw),
        service: FakeNotificationService(),
        settings: settings,
      );
      int requests() =>
          server.requests.where((r) => r.path == '/api/cron/jobs').length;

      watcher.available = true;
      await tester.pumpAndSettle();
      expect(requests(), 1);

      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();
      expect(requests(), 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 3));
      await tester.pumpAndSettle();
      expect(requests(), 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(requests(), 3);

      // The timer would otherwise outlive the test.
      watcher.dispose();
    });

    testWidgets('backs off while looks fail and is back on the minute after', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final server = FakeHermesServer()
        ..on('GET', '/api/cron/jobs', {}, status: 503);
      final settings = NotificationSettings();
      await settings.load();
      final watcher = ScheduleWatcher(
        repository: HermesCronRepository(server.client().raw),
        service: FakeNotificationService(),
        settings: settings,
      );
      int requests() =>
          server.requests.where((r) => r.path == '/api/cron/jobs').length;
      Future<void> minutes(int n) async {
        for (var i = 0; i < n; i++) {
          await tester.pump(const Duration(minutes: 1));
          await tester.pumpAndSettle();
        }
      }

      watcher.available = true;
      await tester.pumpAndSettle();
      expect(requests(), 1);

      // One failure skips one tick, two skip three.
      await minutes(1);
      expect(requests(), 1);
      await minutes(1);
      expect(requests(), 2);
      await minutes(3);
      expect(requests(), 2);
      await minutes(1);
      expect(requests(), 3);

      // Coming back to the front looks at once.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(requests(), 4);

      server.on('GET', '/api/cron/jobs', [ran('2026-09-20T08:00:00+00:00')]);
      await minutes(2);
      expect(requests(), 5);
      await minutes(1);
      expect(requests(), 6);

      watcher.dispose();
    });

    testWidgets('another setting changing does not look again', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final server = FakeHermesServer()
        ..on('GET', '/api/cron/jobs', [ran('2026-09-20T08:00:00+00:00')]);
      final settings = NotificationSettings();
      await settings.load();
      final watcher = ScheduleWatcher(
        repository: HermesCronRepository(server.client().raw),
        service: FakeNotificationService(),
        settings: settings,
      );
      int requests() =>
          server.requests.where((r) => r.path == '/api/cron/jobs').length;

      watcher.available = true;
      await tester.pumpAndSettle();
      expect(requests(), 1);

      await settings.recordPermission(granted: true);
      await tester.pumpAndSettle();
      expect(requests(), 1);

      watcher.dispose();
    });

    group('on macOS', () {
      Future<(ScheduleWatcher, int Function())> watch(
        WidgetTester tester,
      ) async {
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.empty();
        final server = FakeHermesServer()
          ..on('GET', '/api/cron/jobs', [ran('2026-09-20T08:00:00+00:00')]);
        final settings = NotificationSettings();
        await settings.load();
        final watcher = ScheduleWatcher(
          repository: HermesCronRepository(server.client().raw),
          service: FakeNotificationService(),
          settings: settings,
        );
        watcher.available = true;
        await tester.pumpAndSettle();
        return (
          watcher,
          () => server.requests.where((r) => r.path == '/api/cron/jobs').length,
        );
      }

      testWidgets('keeps looking every minute while the window is closed', (
        tester,
      ) async {
        final (watcher, requests) = await watch(tester);
        expect(requests(), 1);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();
        expect(requests(), 2);

        await tester.pump(const Duration(minutes: 1));
        await tester.pumpAndSettle();
        expect(requests(), 3);

        // The timer would otherwise outlive the test.
        watcher.dispose();
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

      testWidgets('stops when the system pauses the app', (tester) async {
        final (_, requests) = await watch(tester);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump(const Duration(minutes: 3));
        await tester.pumpAndSettle();
        expect(requests(), 1);
      }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
    });
  });
}

base class _FailingWritePrefs extends InMemorySharedPreferencesAsync {
  _FailingWritePrefs()
    : super.withData({
        'hermes.schedules.baseline.v1':
            '{"work/job1":"2026-09-20T08:00:00.000Z"}',
      });

  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async => throw StateError('disk full');
}

class _HeldBaseline extends ScheduleBaseline {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Map<String, DateTime>?> read(String account) async {
    started.complete();
    await release.future;
    return super.read(account);
  }
}

class _HeldNotificationService extends FakeNotificationService
    implements GuardedNotificationService {
  final started = Completer<void>();
  final release = Completer<void>();

  Future<void> _prepare() async {
    started.complete();
    await release.future;
  }

  @override
  Future<void> show(AttentionNotification notification) async {
    await _prepare();
    await super.show(notification);
  }

  @override
  Future<void> showWhile(
    AttentionNotification notification,
    bool Function() canDeliver,
  ) async {
    await _prepare();
    if (canDeliver()) await super.show(notification);
  }
}

base class _SlowClearPrefs extends InMemorySharedPreferencesAsync {
  _SlowClearPrefs() : super.empty();

  @override
  Future<bool> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return super.clear(parameters, options);
  }
}
