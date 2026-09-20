import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late SchedulesController controller;

  SchedulesController build() => SchedulesController(
    repository: HermesCronRepository(server.client().raw),
    profiles: HermesProfilesRepository(server.client().raw),
  );

  void activeProfile(String name) => server.on('GET', '/api/profiles/active', {
    'active': name,
    'current': name,
  });

  setUp(() {
    server = FakeHermesServer();
    activeProfile('work');
    controller = build();
  });

  tearDown(() => controller.dispose());

  List<String> jobRequests() => [
    for (final r in server.requests)
      if (r.path == '/api/cron/jobs' && r.method == 'GET')
        'profile=${r.queryParameters['profile']}',
  ];

  group('scope', () {
    test('lists the active profile by default', () async {
      server.on('GET', '/api/cron/jobs', [cronJobRow()]);

      await controller.refresh();

      expect(jobRequests(), ['profile=work']);
      expect(controller.jobs.map((j) => j.id), ['job1']);
      expect(controller.activeProfile, 'work');
    });

    test('lists every profile on request and names them in the rows', () async {
      server.on('GET', '/api/cron/jobs', [
        cronJobRow(),
        cronJobRow(id: 'job2', profile: 'home'),
      ]);
      await controller.refresh();

      controller.allProfiles = true;
      await pumpEventQueue();

      expect(jobRequests().last, 'profile=all');
      expect(controller.showProfiles, isTrue);
      expect(controller.jobs.map((j) => j.key), ['work/job1', 'home/job2']);
    });

    test('lists unscoped when the server has no profiles route', () async {
      server
        ..on('GET', '/api/profiles/active', {}, status: 404)
        ..on('GET', '/api/cron/jobs', [cronJobRow()]);

      await controller.refresh();

      expect(jobRequests(), ['profile=null']);
      expect(controller.jobs, hasLength(1));
    });

    test(
      'does not list unscoped when the active profile lookup fails',
      () async {
        server.on('GET', '/api/profiles/active', {}, status: 500);

        await controller.refresh();

        expect(jobRequests(), isEmpty);
        expect(controller.error, isNotNull);
        expect(controller.loaded, isFalse);
      },
    );
  });

  group('refresh', () {
    test('keeps the rows on screen when a later refresh fails', () async {
      server.on('GET', '/api/cron/jobs', [cronJobRow()]);
      await controller.refresh();

      server.on('GET', '/api/cron/jobs', {}, status: 500);
      await controller.refresh();

      expect(controller.jobs, hasLength(1));
      expect(controller.error, isNotNull);
    });

    test('ignores an older answer that lands after a newer one', () async {
      final slow = Completer<FakeResponse>();
      var calls = 0;
      server.onRequest('GET', '/api/cron/jobs', (_) {
        calls++;
        return calls == 1
            ? slow.future
            : (status: 200, body: [cronJobRow(name: 'Newer')]);
      });

      final first = controller.refresh();
      await pumpEventQueue();
      await controller.refresh();
      slow.complete((status: 200, body: [cronJobRow(name: 'Older')]));
      await first;

      expect(controller.jobs.single.name, 'Newer');
    });

    test('filters and sorts what it shows', () async {
      server.on('GET', '/api/cron/jobs', [
        cronJobRow(id: 'ok', lastStatus: 'ok'),
        cronJobRow(id: 'bad', lastStatus: 'error'),
        cronJobRow(id: 'off', state: 'paused'),
      ]);
      await controller.refresh();

      expect(controller.visibleJobs.map((j) => j.id), ['bad', 'ok', 'off']);
      controller.filter = ScheduleFilter.failing;
      expect(controller.visibleJobs.map((j) => j.id), ['bad']);
      expect(controller.failingCount, 1);
    });
  });

  group('pause and resume', () {
    setUp(() async {
      server.on('GET', '/api/cron/jobs', [
        cronJobRow(nextRunAt: '2026-09-21T08:00:00+00:00'),
      ]);
      await controller.refresh();
    });

    test('pauses at once and reloads', () async {
      final answer = Completer<FakeResponse>();
      server.onRequest(
        'POST',
        '/api/cron/jobs/job1/pause',
        (_) => answer.future,
      );
      server.on('GET', '/api/cron/jobs', [cronJobRow(state: 'paused')]);

      final result = controller.setPaused(controller.jobs.single, true);
      await pumpEventQueue();

      expect(controller.jobs.single.isPaused, isTrue);
      expect(controller.jobs.single.nextRunAt, isNull);
      answer.complete((status: 200, body: {'id': 'job1'}));
      expect(await result, isNull);
      expect(controller.jobs.single.isPaused, isTrue);
    });

    test('puts the switch back and says so when the server refuses', () async {
      server.on('POST', '/api/cron/jobs/job1/pause', {
        'detail': 'no',
      }, status: 400);

      final message = await controller.setPaused(controller.jobs.single, true);

      expect(message, contains('Could not pause'));
      expect(controller.jobs.single.isPaused, isFalse);
    });

    test('a refresh landing meanwhile does not undo the switch', () async {
      final answer = Completer<FakeResponse>();
      server.onRequest(
        'POST',
        '/api/cron/jobs/job1/pause',
        (_) => answer.future,
      );
      final result = controller.setPaused(controller.jobs.single, true);
      await pumpEventQueue();

      await controller.refresh();
      expect(controller.jobs.single.isPaused, isTrue);

      answer.complete((status: 200, body: {'id': 'job1'}));
      await result;
    });

    test('drops a job the server no longer has', () async {
      server.on('POST', '/api/cron/jobs/job1/pause', {}, status: 404);

      final message = await controller.setPaused(controller.jobs.single, true);

      expect(message, contains('no longer exists'));
      expect(controller.jobs, isEmpty);
    });
  });

  group('run now and delete', () {
    setUp(() async {
      server.on('GET', '/api/cron/jobs', [cronJobRow()]);
      await controller.refresh();
    });

    test('run now reports only that a run was requested', () async {
      server.on('POST', '/api/cron/jobs/job1/trigger', {'ok': true});
      expect(await controller.runNow(controller.jobs.single), isNull);
    });

    test('run now says when it could not start', () async {
      server.on('POST', '/api/cron/jobs/job1/trigger', {}, status: 500);
      expect(
        await controller.runNow(controller.jobs.single),
        contains('Could not start'),
      );
    });

    test('delete removes the job', () async {
      server.on('DELETE', '/api/cron/jobs/job1', {'ok': true});
      expect(await controller.delete(controller.jobs.single), isNull);
      expect(controller.jobs, isEmpty);
    });

    test('a job that is already gone counts as deleted', () async {
      server.on('DELETE', '/api/cron/jobs/job1', {}, status: 404);
      expect(await controller.delete(controller.jobs.single), isNull);
      expect(controller.jobs, isEmpty);
    });

    test('a failed delete keeps the job', () async {
      server.on('DELETE', '/api/cron/jobs/job1', {}, status: 500);
      expect(
        await controller.delete(controller.jobs.single),
        contains('Could not delete'),
      );
      expect(controller.jobs, hasLength(1));
    });
  });

  group('reload', () {
    test('replaces the row with what the server has', () async {
      server.on('GET', '/api/cron/jobs', [cronJobRow()]);
      await controller.refresh();
      server.on('GET', '/api/cron/jobs/job1', cronJobRow(name: 'Renamed'));

      final fresh = await controller.reload(controller.jobs.single);

      expect(fresh?.name, 'Renamed');
      expect(controller.jobs.single.name, 'Renamed');
    });

    test('drops a job that is gone', () async {
      server.on('GET', '/api/cron/jobs', [cronJobRow()]);
      await controller.refresh();
      server.on('GET', '/api/cron/jobs/job1', {}, status: 404);

      expect(await controller.reload(controller.jobs.single), isNull);
      expect(controller.jobs, isEmpty);
    });
  });

  group('after disposal', () {
    Future<SchedulesController> loaded() async {
      server.on('GET', '/api/cron/jobs', [cronJobRow()]);
      final c = build();
      await c.refresh();
      return c;
    }

    test('a delete that answers late does not notify', () async {
      final c = await loaded();
      final answer = Completer<FakeResponse>();
      server.onRequest('DELETE', '/api/cron/jobs/job1', (_) => answer.future);

      final result = c.delete(c.jobs.single);
      await pumpEventQueue();
      c.dispose();
      answer.complete((status: 404, body: <String, Object?>{}));

      expect(await result, isNull);
    });

    test('a run request that answers 404 late does not notify', () async {
      final c = await loaded();
      final answer = Completer<FakeResponse>();
      server.onRequest(
        'POST',
        '/api/cron/jobs/job1/trigger',
        (_) => answer.future,
      );

      final result = c.runNow(c.jobs.single);
      await pumpEventQueue();
      c.dispose();
      answer.complete((status: 404, body: <String, Object?>{}));

      expect(await result, contains('no longer exists'));
    });
  });
}
