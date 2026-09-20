import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/schedules/hermes_cron_repository.dart';
import 'package:hermes_app/src/schedules/job_draft.dart';
import 'package:hermes_app/src/schedules/job_form_controller.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
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

  Map<String, Object?> lastBody() =>
      jsonDecode(server.requests.last.data as String) as Map<String, Object?>;

  group('JobFormController', () {
    JobFormController create({String? profile = 'work'}) => JobFormController(
      repository: repository,
      profile: profile,
      now: () => DateTime(2026, 9, 20, 12),
    );

    test('does not save without a prompt, a skill or a script', () async {
      final form = create();

      final job = await form.save();

      expect(job, isNull);
      expect(form.error, 'A task needs a prompt, a skill or a script');
      expect(server.requests, isEmpty);
    });

    test('creates in the chosen profile', () async {
      server.on(
        'POST',
        '/api/cron/jobs',
        cronJobRow(id: 'new'),
        query: {'profile': 'work'},
      );
      final form = create()
        ..draft.prompt = 'Check it'
        ..draft.spec = const EverySpec(6, EveryUnit.hours);

      final job = await form.save();

      expect(job?.id, 'new');
      expect(lastBody(), containsPair('schedule', 'every 6h'));
    });

    test(
      'keeps the values and shows the reason when the server refuses',
      () async {
        server.on('POST', '/api/cron/jobs', {
          'detail': 'script must be inside /x/scripts',
        }, status: 400);
        final form = create()
          ..draft.prompt = 'x'
          ..draft.script = '../evil.sh';

        expect(await form.save(), isNull);

        expect(form.error, 'script must be inside /x/scripts');
        expect(form.draft.script, '../evil.sh');
        expect(form.saving, isFalse);
      },
    );

    test('sends one request for two quick saves', () async {
      final answer = Completer<FakeResponse>();
      server.onRequest('POST', '/api/cron/jobs', (_) => answer.future);
      final form = create()..draft.prompt = 'x';

      final first = form.save();
      final second = await form.save();
      answer.complete((status: 200, body: cronJobRow()));
      await first;

      expect(second, isNull);
      expect(server.requests.where((r) => r.method == 'POST'), hasLength(1));
    });

    test(
      'editing sends only what changed and leaves the schedule alone',
      () async {
        final job = CronJob.fromJson(cronJobRow(prompt: 'Old'))!;
        server.on('PUT', '/api/cron/jobs/job1', cronJobRow());
        final form = JobFormController(repository: repository, editing: job)
          ..draft.prompt = 'New';

        await form.save();

        expect(lastBody(), {
          'updates': {'prompt': 'New'},
        });
      },
    );

    test('editing sends the schedule once "when" was touched', () async {
      final job = CronJob.fromJson(cronJobRow())!;
      server.on('PUT', '/api/cron/jobs/job1', cronJobRow());
      final form = JobFormController(repository: repository, editing: job);
      form.draft.spec = const DailySpec(7, 0);
      form.changed(when: true);

      await form.save();

      expect(lastBody(), {
        'updates': {'schedule': '0 7 * * *'},
      });
    });

    test('is dirty only once something changed', () {
      final job = CronJob.fromJson(cronJobRow())!;
      final form = JobFormController(repository: repository, editing: job);
      expect(form.isDirty, isFalse);
      form.draft.name = 'Renamed';
      expect(form.isDirty, isTrue);
      expect(create().isDirty, isFalse);
    });

    test('offers the server targets and a stored one that is gone', () async {
      server.on('GET', '/api/cron/delivery-targets', {
        'targets': [
          {'id': 'local', 'name': 'Local (save only)', 'home_target_set': true},
          {'id': 'discord', 'name': 'Discord', 'home_target_set': false},
        ],
      });
      final job = CronJob.fromJson(cronJobRow(deliver: 'matrix'))!;
      final form = JobFormController(repository: repository, editing: job);

      await form.loadTargets();

      expect(form.targets.map((t) => t.id), ['local', 'discord', 'matrix']);
      expect(form.selectedTarget?.name, 'matrix (unavailable)');
    });

    test('offers local only when the targets cannot be loaded', () async {
      server.on('GET', '/api/cron/delivery-targets', {}, status: 500);
      final form = create();

      await form.loadTargets();

      expect(form.targets.map((t) => t.id), ['local']);
      expect(form.targetsFailed, isTrue);
    });
  });

  group('BlueprintFormController', () {
    const blueprint = Blueprint(
      key: 'morning-brief',
      title: 'Morning briefing',
      fields: [
        BlueprintField(
          name: 'time',
          type: 'time',
          label: 'What time?',
          defaultValue: '08:00',
        ),
        BlueprintField(
          name: 'note',
          type: 'text',
          label: 'Note',
          optional: true,
        ),
      ],
    );

    BlueprintFormController form() => BlueprintFormController(
      repository: repository,
      blueprint: blueprint,
      profile: 'work',
    );

    test('starts from the defaults and creates through the server', () async {
      server.on(
        'POST',
        '/api/cron/blueprints/instantiate',
        cronJobRow(id: 'b'),
        query: {'profile': 'work'},
      );

      final job = await form().save();

      expect(job?.id, 'b');
      expect(lastBody(), {
        'blueprint': 'morning-brief',
        'values': {'time': '08:00'},
      });
    });

    test('a required slot cannot be emptied', () async {
      final f = form()..set('time', '');

      expect(await f.save(), isNull);

      expect(f.fieldErrors['time'], 'Required');
      expect(server.requests, isEmpty);
    });

    test(
      'a 422 is shown against the slot it names and the values stay',
      () async {
        server.on('POST', '/api/cron/blueprints/instantiate', {
          'detail': "invalid time '25:00' — use HH:MM (24h)",
        }, status: 422);
        final f = form()..set('time', '25:00');

        expect(await f.save(), isNull);

        expect(f.fieldErrors['time'], contains('invalid time'));
        expect(f.values['time'], '25:00');
        expect(f.error, isNull);
      },
    );

    test('a refusal that names no slot goes on the form', () async {
      server.on('POST', '/api/cron/blueprints/instantiate', {
        'detail': 'nope',
      }, status: 400);
      final f = form();

      await f.save();

      expect(f.error, 'nope');
    });
  });
}
