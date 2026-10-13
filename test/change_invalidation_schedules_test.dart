import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_change_feed.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_session_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHermesServer server;
  late FakeChangeFeed feed;
  late FakeSessionAuth auth;
  late SchedulesController controller;
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', {'active': 'work', 'current': 'work'})
      ..on('GET', '/api/cron/jobs', [cronJobRow()], query: {'profile': 'work'});
    feed = FakeChangeFeed();
    auth = FakeSessionAuth();
    controller = SchedulesController(
      repository: HermesCronRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
      auth: auth,
      changeSource: feed,
      refreshEvery: const Duration(days: 1),
    );
    controller.active = true;
    await pumpEventQueue();
  });
  tearDown(() async {
    controller.dispose();
    auth.dispose();
    await feed.close();
  });
  int reads() => server.requestsTo('GET', '/api/cron/jobs').length;

  test(
    'an active scoped hint refreshes rows without clearing selection or filter',
    () async {
      final selected = controller.jobs.single;
      controller.select(selected);
      controller.filter = ScheduleFilter.failing;
      server.on(
        'GET',
        '/api/cron/jobs',
        [cronJobRow(name: 'External title')],
        query: {'profile': 'work'},
      );
      feed.hint('cron.changed');
      await pumpEventQueue();
      expect(reads(), 2);
      expect(controller.selected!.name, 'External title');
      expect(controller.filter, ScheduleFilter.failing);
      expect(controller.activeProfile, 'work');
    },
  );
  test(
    'a covered destination holds one dirty hint until reactivated',
    () async {
      controller.invalidationVisible = false;
      feed.hint('cron.changed');
      feed.hint('cron.changed');
      await pumpEventQueue();
      expect(reads(), 1);
      controller.invalidationVisible = true;
      await pumpEventQueue();
      expect(reads(), 2);
    },
  );
  test(
    'refresh failure retains jobs and uses the existing failure state',
    () async {
      final before = controller.jobs.single;
      server.on(
        'GET',
        '/api/cron/jobs',
        {},
        status: 500,
        query: {'profile': 'work'},
      );
      feed.hint('cron.changed');
      await pumpEventQueue();
      expect(controller.jobs.single, same(before));
      expect(controller.error, isNotNull);
      expect(controller.loading, false);
    },
  );
  test(
    'a pending local pause excludes invalidation until the mutation finishes',
    () async {
      final response = Completer<FakeResponse>();
      server.onRequest(
        'POST',
        '/api/cron/jobs/job1/pause',
        (_) => response.future,
      );
      final action = controller.setPaused(controller.jobs.single, true);
      await pumpEventQueue();
      expect(controller.jobs.single.state, CronJobState.paused);
      feed.hint('cron.changed');
      await pumpEventQueue();
      expect(reads(), 1);
      expect(controller.jobs.single.state, CronJobState.paused);
      server.on(
        'GET',
        '/api/cron/jobs',
        [cronJobRow(state: 'paused')],
        query: {'profile': 'work'},
      );
      response.complete((status: 200, body: {'ok': true}));
      await action.timeout(const Duration(seconds: 5));
      await pumpEventQueue();
      expect(controller.jobs.single.state, CronJobState.paused);
      expect(controller.loading, false);
    },
  );
}
