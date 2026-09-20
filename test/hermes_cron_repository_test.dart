import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';

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
}
