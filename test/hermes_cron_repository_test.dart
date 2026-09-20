import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/job_draft.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';

import 'support/cron_fixtures.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesCronRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesCronRepository(server.client().raw);
  });

  group('isAvailable', () {
    test('is true when the delivery targets answer', () async {
      server.on('GET', '/api/cron/delivery-targets', cronDeliveryTargets);
      expect(await repository.isAvailable(), isTrue);
    });

    test('is false on a server without the route', () async {
      server.on('GET', '/api/cron/delivery-targets', {}, status: 404);
      expect(await repository.isAvailable(), isFalse);
    });
  });

  group('listJobs', () {
    test('asks for a profile and parses the rows', () async {
      server.on(
        'GET',
        '/api/cron/jobs',
        [
          cronJobRow(),
          {'name': 'no id'},
          'junk',
        ],
        query: {'profile': 'work'},
      );

      final jobs = await repository.listJobs(profile: 'work');

      expect(jobs.map((j) => j.id), ['job1']);
    });

    test('returns nothing for a body that is not a list', () async {
      server.on('GET', '/api/cron/jobs', {'jobs': []});
      expect(await repository.listJobs(), isEmpty);
    });

    test('reports the reason the server gave', () async {
      server.on(
        'GET',
        '/api/cron/jobs',
        {'detail': "Profile 'x' does not exist."},
        status: 404,
        query: {'profile': 'x'},
      );

      expect(
        () => repository.listJobs(profile: 'x'),
        throwsA(
          isA<CronException>()
              .having((e) => e.message, 'message', contains('does not exist'))
              .having((e) => e.isNotFound, 'isNotFound', isTrue),
        ),
      );
    });
  });

  test(
    'pause, resume, trigger and delete name the job and its profile',
    () async {
      for (final (method, path) in [
        ('POST', '/api/cron/jobs/job1/pause'),
        ('POST', '/api/cron/jobs/job1/resume'),
        ('POST', '/api/cron/jobs/job1/trigger'),
        ('DELETE', '/api/cron/jobs/job1'),
      ]) {
        server.on(method, path, {'ok': true});
      }

      await repository.pause('job1', profile: 'work');
      await repository.resume('job1', profile: 'work');
      await repository.trigger('job1', profile: 'work');
      await repository.delete('job1', profile: 'work');

      expect(server.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /api/cron/jobs/job1/pause',
        'POST /api/cron/jobs/job1/resume',
        'POST /api/cron/jobs/job1/trigger',
        'DELETE /api/cron/jobs/job1',
      ]);
      expect(
        server.requests.every((r) => r.queryParameters['profile'] == 'work'),
        isTrue,
      );
    },
  );

  test('listRuns reads the runs array and passes the limit', () async {
    server.on(
      'GET',
      '/api/cron/jobs/job1/runs',
      {
        'runs': [
          cronRunRow(id: 'cron_job1_1', startedAt: 1000, endedAt: 1042),
          {'started_at': 5},
        ],
        'limit': 40,
      },
      query: {'limit': '40'},
    );

    final runs = await repository.listRuns('job1', limit: 40);

    expect(runs.map((r) => r.sessionId), ['cron_job1_1']);
  });

  test('deliveryTargets reads the targets array', () async {
    server.on('GET', '/api/cron/delivery-targets', {
      'targets': [
        {'id': 'local', 'name': 'Local (save only)', 'home_target_set': true},
        {'id': 'discord', 'name': 'Discord', 'home_target_set': false},
      ],
    });

    final targets = await repository.deliveryTargets();

    expect(targets.map((t) => t.id), ['local', 'discord']);
    expect(targets.last.homeTargetSet, isFalse);
  });

  group('create and change', () {
    test('createJob posts the draft to the chosen profile', () async {
      server.on(
        'POST',
        '/api/cron/jobs',
        cronJobRow(id: 'new'),
        query: {'profile': 'work'},
      );

      final job = await repository.createJob(
        JobDraft(
          name: 'Price watch',
          prompt: 'Check it',
          spec: const EverySpec(6, EveryUnit.hours),
        ),
        profile: 'work',
      );

      expect(job.id, 'new');
      final request = server.requests.last;
      final body = jsonDecode(request.data as String) as Map;
      expect(body, containsPair('schedule', 'every 6h'));
      expect(body, containsPair('prompt', 'Check it'));
      expect(body, isNot(contains('model')));
    });

    test('updateJob sends only the updates', () async {
      server.on('PUT', '/api/cron/jobs/job1', cronJobRow());

      await repository.updateJob('job1', {'prompt': 'New'}, profile: 'work');

      final request = server.requests.last;
      expect(jsonDecode(request.data as String), {
        'updates': {'prompt': 'New'},
      });
      expect(request.queryParameters['profile'], 'work');
    });

    test('a refusal carries the server reason and status', () async {
      server.on('POST', '/api/cron/jobs', {
        'detail': 'script must be inside /x/scripts',
      }, status: 400);

      await expectLater(
        repository.createJob(JobDraft(prompt: 'x')),
        throwsA(
          isA<CronException>()
              .having((e) => e.message, 'message', contains('script must'))
              .having((e) => e.status, 'status', 400),
        ),
      );
    });
  });

  group('blueprints', () {
    test('blueprints reads the catalog and skips bad entries', () async {
      server.on('GET', '/api/cron/blueprints', {
        'blueprints': [
          {'key': 'morning-brief', 'title': 'Morning briefing', 'fields': []},
          {'title': 'no key'},
        ],
      });

      final blueprints = await repository.blueprints();

      expect(blueprints.map((b) => b.key), ['morning-brief']);
    });

    test('instantiate sends the key and values for the profile', () async {
      server.on(
        'POST',
        '/api/cron/blueprints/instantiate',
        cronJobRow(id: 'b'),
        query: {'profile': 'work'},
      );

      final job = await repository.instantiate('morning-brief', {
        'time': '07:30',
      }, profile: 'work');

      expect(job.id, 'b');
      expect(jsonDecode(server.requests.last.data as String), {
        'blueprint': 'morning-brief',
        'values': {'time': '07:30'},
      });
    });

    test('a 422 keeps its message', () async {
      server.on('POST', '/api/cron/blueprints/instantiate', {
        'detail': 'missing required value: time (What time?)',
      }, status: 422);

      await expectLater(
        repository.instantiate('morning-brief', {}),
        throwsA(isA<CronException>().having((e) => e.status, 'status', 422)),
      );
    });
  });
}
