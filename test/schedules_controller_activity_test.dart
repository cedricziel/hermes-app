import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedules_controller.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';

void main() {
  void scheduleTest(String name, void Function(FakeAsync, _Schedules) body) {
    test(name, () {
      fakeAsync((async) {
        final h = _Schedules();
        try {
          body(async, h);
        } finally {
          h.controller.dispose();
          h.activity.dispose();
          async.elapse(Duration.zero);
        }
      });
    });
  }

  scheduleTest(
    'inactive reads, commands and external publications are blocked',
    (async, h) {
      h.activity.value = false;
      h.controller.refresh();
      expectLater(h.controller.setPaused(h.job, true), throwsStateError);
      expectLater(h.controller.setPaused(h.job, false), throwsStateError);
      expectLater(h.controller.runNow(h.job), throwsStateError);
      expectLater(h.controller.delete(h.job), throwsStateError);
      expectLater(h.controller.reload(h.job), throwsStateError);
      expectLater(h.controller.findJob('other'), throwsStateError);
      expectLater(h.controller.profileNames(), throwsStateError);
      expectLater(h.controller.loadRuns(h.job), throwsStateError);
      h.controller.jobSaved(h.job);
      h.controller.requestOpen('job1');
      async.elapse(Duration.zero);

      expect(h.server.requests, isEmpty);
      expect(h.controller.jobs, isEmpty);
      expect(h.controller.takeOpenRequest(), isNull);
      expect(h.controller.loading, isFalse);
    },
  );

  scheduleTest(
    'suspension stops the minute timer and resume retains local context',
    (async, h) {
      h.controller.active = true;
      async.elapse(Duration.zero);
      h.controller.filter = ScheduleFilter.paused;
      h.controller.select(h.controller.jobs.single);
      h.controller.requestOpen('job1');
      h.activity.value = false;
      async.elapse(const Duration(minutes: 3));

      expect(h.fetches, 1);
      expect(h.controller.takeOpenRequest(), isNull);
      expect(h.controller.selected?.id, 'job1');
      h.serve(name: 'Fresh');
      h.activity.value = true;
      async.elapse(Duration.zero);

      expect(h.fetches, 2);
      expect(h.controller.jobs.single.name, 'Fresh');
      expect(h.controller.filter, ScheduleFilter.paused);
      expect(h.controller.selected?.id, 'job1');
      async.elapse(const Duration(minutes: 1));
      expect(h.fetches, 3);
    },
  );

  scheduleTest('resume does not load a destination never opened', (async, h) {
    h.activity.value = false;
    h.activity.value = true;
    async.elapse(Duration.zero);
    expect(h.server.requests, isEmpty);
  });

  scheduleTest(
    'an earlier activity listener cannot dispatch while value is false',
    (async, h) {
      h.controller.dispose();
      h.activity.addListener(() {
        if (!h.activity.value) {
          expectLater(h.controller.runNow(h.job), throwsStateError);
        }
      });
      h.build();

      h.activity.value = false;
      async.elapse(Duration.zero);

      expect(h.server.requests, isEmpty);
    },
  );

  scheduleTest('nested false to true notifications retire an old lookup', (
    async,
    h,
  ) {
    h.controller.dispose();
    h.activity.addListener(() {
      if (!h.activity.value) h.activity.value = true;
    });
    h.build();
    final answer = Completer<FakeResponse>();
    h.server.onRequest('GET', '/api/cron/jobs', (_) => answer.future);
    h.controller.refresh();
    async.elapse(Duration.zero);
    h.serve(name: 'Fresh');

    h.activity.value = false;
    async.elapse(Duration.zero);
    answer.complete((status: 200, body: [cronJobRow(name: 'Stale')]));
    async.elapse(Duration.zero);

    expect(h.controller.jobs.single.name, 'Fresh');
    expect(h.controller.loading, isFalse);
  });

  scheduleTest('loading listeners can suspend before profile dispatch', (
    async,
    h,
  ) {
    h.controller.addListener(() {
      if (h.controller.loading) h.activity.value = false;
    });
    h.controller.refresh();
    async.elapse(Duration.zero);

    expect(h.server.requests, isEmpty);
    expect(h.controller.loading, isFalse);
  });

  scheduleTest('late active-profile lookup cannot dispatch or set scope', (
    async,
    h,
  ) {
    final answer = Completer<FakeResponse>();
    h.server.onRequest('GET', '/api/profiles/active', (_) => answer.future);
    h.controller.refresh();
    async.elapse(Duration.zero);
    h.activity.value = false;
    answer.complete((status: 200, body: {'active': 'old'}));
    async.elapse(Duration.zero);

    expect(h.fetches, 0);
    expect(h.controller.activeProfile, isNull);
    expect(h.controller.loading, isFalse);
  });

  scheduleTest('late list failure cannot replace a fresh resumed list', (
    async,
    h,
  ) {
    final answer = Completer<FakeResponse>();
    h.server.onRequest('GET', '/api/cron/jobs', (_) => answer.future);
    h.controller.refresh();
    async.elapse(Duration.zero);
    h.activity.value = false;
    h.serve(name: 'Fresh');
    h.activity.value = true;
    async.elapse(Duration.zero);
    answer.complete((status: 500, body: {'detail': 'old error'}));
    async.elapse(Duration.zero);

    expect(h.controller.jobs.single.name, 'Fresh');
    expect(h.controller.error, isNull);
  });

  scheduleTest('optimistic-switch listeners cannot dispatch after suspension', (
    async,
    h,
  ) {
    h.controller.refresh();
    async.elapse(Duration.zero);
    h.controller.addListener(() {
      if (h.controller.jobs.single.isPaused) h.activity.value = false;
    });

    expectLater(h.controller.setPaused(h.job, true), throwsStateError);
    async.elapse(Duration.zero);

    expect(h.server.requestsTo('POST', '/api/cron/jobs/job1/pause'), isEmpty);
  });

  scheduleTest(
    'late pause is rejected and does not replay or retain optimism',
    (async, h) {
      h.controller.refresh();
      async.elapse(Duration.zero);
      final answer = Completer<FakeResponse>();
      h.server.onRequest(
        'POST',
        '/api/cron/jobs/job1/pause',
        (_) => answer.future,
      );
      expectLater(h.controller.setPaused(h.job, true), throwsStateError);
      async.elapse(Duration.zero);
      h.activity.value = false;
      h.serve(name: 'Fresh');
      h.activity.value = true;
      async.elapse(Duration.zero);
      final fetches = h.fetches;
      answer.complete((status: 200, body: {'ok': true}));
      async.elapse(Duration.zero);

      expect(h.controller.jobs.single.name, 'Fresh');
      expect(h.controller.jobs.single.isPaused, isFalse);
      expect(h.fetches, fetches);
      expect(
        h.server.requestsTo('POST', '/api/cron/jobs/job1/pause'),
        hasLength(1),
      );
    },
  );

  scheduleTest('late delete cannot remove the resumed row or report success', (
    async,
    h,
  ) {
    h.controller.refresh();
    async.elapse(Duration.zero);
    final answer = Completer<FakeResponse>();
    h.server.onRequest('DELETE', '/api/cron/jobs/job1', (_) => answer.future);
    expectLater(h.controller.delete(h.job), throwsStateError);
    async.elapse(Duration.zero);
    h.activity.value = false;
    h.serve(name: 'Fresh');
    h.activity.value = true;
    async.elapse(Duration.zero);
    answer.complete((status: 404, body: {'detail': 'gone'}));
    async.elapse(Duration.zero);

    expect(h.controller.jobs.single.name, 'Fresh');
  });

  scheduleTest('late trigger cannot report success or remove a current row', (
    async,
    h,
  ) {
    h.controller.refresh();
    async.elapse(Duration.zero);
    final answer = Completer<FakeResponse>();
    h.server.onRequest(
      'POST',
      '/api/cron/jobs/job1/trigger',
      (_) => answer.future,
    );
    expectLater(h.controller.runNow(h.job), throwsStateError);
    async.elapse(Duration.zero);
    h.activity.value = false;
    h.activity.value = true;
    async.elapse(Duration.zero);
    answer.complete((status: 404, body: {'detail': 'gone'}));
    async.elapse(Duration.zero);

    expect(h.controller.jobs, hasLength(1));
  });

  scheduleTest('reload cannot return or publish a row after suspension', (
    async,
    h,
  ) {
    h.controller.refresh();
    async.elapse(Duration.zero);
    final answer = Completer<FakeResponse>();
    h.server.onRequest('GET', '/api/cron/jobs/job1', (_) => answer.future);
    expectLater(h.controller.reload(h.job), throwsStateError);
    async.elapse(Duration.zero);
    h.activity.value = false;
    answer.complete((status: 200, body: cronJobRow(name: 'Stale')));
    async.elapse(Duration.zero);

    expect(h.controller.jobs.single.name, 'Nightly');
  });

  scheduleTest('find, runs and profile reads reject late results', (async, h) {
    final job = Completer<FakeResponse>();
    final runs = Completer<FakeResponse>();
    final profiles = Completer<FakeResponse>();
    h.server.onRequest('GET', '/api/cron/jobs/job1', (_) => job.future);
    h.server.onRequest('GET', '/api/cron/jobs/job1/runs', (_) => runs.future);
    h.server.onRequest('GET', '/api/profiles', (_) => profiles.future);
    expectLater(h.controller.findJob('job1'), throwsStateError);
    expectLater(h.controller.loadRuns(h.job), throwsStateError);
    expectLater(h.controller.profileNames(), throwsStateError);
    async.elapse(Duration.zero);
    h.activity.value = false;
    job.complete((status: 200, body: cronJobRow()));
    runs.complete((status: 200, body: {'runs': []}));
    profiles.complete((status: 200, body: {'profiles': []}));
    async.elapse(Duration.zero);
  });

  scheduleTest('saved-job listeners suspend before follow-up refresh', (
    async,
    h,
  ) {
    h.controller.addListener(() => h.activity.value = false);

    h.controller.jobSaved(h.job);
    async.elapse(Duration.zero);

    expect(h.server.requests, isEmpty);
  });

  scheduleTest(
    'scope listeners retiring activity prevent the old follow-up read',
    (async, h) {
      var suspended = false;
      h.controller.addListener(() {
        if (!suspended) {
          suspended = true;
          h.activity.value = false;
          h.activity.value = true;
        }
      });

      h.controller.allProfiles = true;
      async.elapse(Duration.zero);

      expect(h.server.requests, isEmpty);
      expect(h.controller.allProfiles, isTrue);
    },
  );
}

class _Schedules {
  _Schedules() {
    server.on('GET', '/api/profiles/active', {'active': 'work'});
    serve();
    build();
  }

  final server = FakeHermesServer();
  final activity = ValueNotifier(true);
  late SchedulesController controller;
  CronJob get job => CronJob.fromJson(cronJobRow())!;
  int get fetches => server.requestsTo('GET', '/api/cron/jobs').length;

  void serve({String name = 'Nightly'}) =>
      server.on('GET', '/api/cron/jobs', [cronJobRow(name: name)]);

  void build() {
    controller = SchedulesController(
      activity: activity,
      repository: HermesCronRepository(server.client().raw),
      profiles: HermesProfilesRepository(server.client().raw),
    );
  }
}
