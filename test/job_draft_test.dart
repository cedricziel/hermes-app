import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/schedules/job_draft.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';

import 'support/cron_fixtures.dart';

void main() {
  final now = DateTime(2026, 9, 20, 12);

  CronJob stored({
    String name = 'Price watch',
    String prompt = 'Check the price',
    String? model,
    List<String> skills = const [],
  }) => CronJob.fromJson(
    cronJobRow(
      name: name,
      prompt: prompt,
      model: model,
      skills: skills,
      deliver: 'telegram',
      schedule: {'kind': 'interval', 'minutes': 360},
    ),
  )!;

  group('validate', () {
    test('needs a prompt, a skill or a script', () {
      final draft = JobDraft();
      expect(draft.validate(now), 'A task needs a prompt, a skill or a script');
      draft.prompt = 'x';
      expect(draft.validate(now), isNull);
      draft
        ..prompt = ''
        ..skills = ['web-search'];
      expect(draft.validate(now), isNull);
      draft
        ..skills = []
        ..script = 'check.py';
      expect(draft.validate(now), isNull);
    });

    test('reports a schedule problem first', () {
      final draft = JobDraft(prompt: 'x', spec: const WeeklySpec({}, 9, 0));
      expect(draft.validate(now), 'Choose at least one day');
    });
  });

  group('toCreate', () {
    test('sends the schedule and leaves empty optional fields out', () {
      final body = JobDraft(
        name: ' Price watch ',
        prompt: ' Check it ',
        spec: const EverySpec(6, EveryUnit.hours),
      ).toCreate();

      expect(body.schedule, 'every 6h');
      expect(body.name, 'Price watch');
      expect(body.prompt, 'Check it');
      expect(body.deliver, 'local');
      expect(body.model, isNull);
      expect(body.skills, isNull);
      expect(body.script, isNull);
      expect(body.contextFrom, isNull);
      expect(body.workdir, isNull);
      expect(body.paused, isFalse);
    });

    test('carries what was filled in', () {
      final body = JobDraft(
        prompt: 'x',
        deliver: 'telegram',
        skills: ['a', 'b'],
        model: 'hermes-4',
        provider: 'nous',
        script: 'check.py',
        contextFrom: ['job1'],
        workdir: '/srv',
        paused: true,
      ).toCreate();

      expect(body.deliver, 'telegram');
      expect(body.skills, ['a', 'b']);
      expect(body.model, 'hermes-4');
      expect(body.provider, 'nous');
      expect(body.script, 'check.py');
      expect(body.contextFrom, ['job1']);
      expect(body.workdir, '/srv');
      expect(body.paused, isTrue);
    });
  });

  group('diff', () {
    test('sends nothing when nothing changed', () {
      final job = stored();
      final draft = JobDraft.fromJob(job);
      expect(draft.diff(JobDraft.fromJob(job), whenTouched: false), isEmpty);
    });

    test('sends only the prompt when only the prompt changed', () {
      final job = stored();
      final draft = JobDraft.fromJob(job)..prompt = 'Check the price daily';
      expect(draft.diff(JobDraft.fromJob(job), whenTouched: false), {
        'prompt': 'Check the price daily',
      });
    });

    test('clears an optional field the user emptied', () {
      final job = stored(model: 'hermes-4');
      final draft = JobDraft.fromJob(job)..model = '  ';
      expect(draft.diff(JobDraft.fromJob(job), whenTouched: false), {
        'model': '',
      });
    });

    test('sends the schedule only when it was touched', () {
      final job = stored();
      final draft = JobDraft.fromJob(job);
      expect(
        draft
            .diff(JobDraft.fromJob(job), whenTouched: false)
            .containsKey('schedule'),
        isFalse,
      );
      draft.spec = const DailySpec(8, 0);
      expect(draft.diff(JobDraft.fromJob(job), whenTouched: true), {
        'schedule': '0 8 * * *',
      });
    });

    test('sends a changed delivery target and lists', () {
      final job = stored();
      final draft = JobDraft.fromJob(job)
        ..deliver = 'local'
        ..skills = ['web-search']
        ..contextFrom = ['job1'];
      expect(draft.diff(JobDraft.fromJob(job), whenTouched: false), {
        'deliver': 'local',
        'skills': ['web-search'],
        'context_from': ['job1'],
      });
    });
  });

  test('parseNames splits on commas and lines and trims', () {
    expect(JobDraft.parseNames('a, b\n c ,,\n'), ['a', 'b', 'c']);
    expect(JobDraft.parseNames('  '), isEmpty);
  });

  group('Blueprint', () {
    final row = {
      'key': 'morning-brief',
      'title': 'Morning briefing',
      'description': 'A short daily briefing',
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
          'options': ['origin', 'local'],
          'strict': false,
        },
        {'label': 'no name'},
      ],
    };

    test('reads a catalog entry and skips a slot without a name', () {
      final blueprint = Blueprint.fromJson(row)!;

      expect(blueprint.title, 'Morning briefing');
      expect(blueprint.scheduleHuman, 'daily at 08:00');
      expect(blueprint.fields.map((f) => f.name), ['time', 'deliver']);
      expect(blueprint.fields.last.strict, isFalse);
      expect(blueprint.fields.last.options, ['origin', 'local']);
    });

    test('skips an entry without a key', () {
      expect(Blueprint.fromJson({'title': 'x'}), isNull);
      expect(Blueprint.fromJson('nope'), isNull);
    });

    test('matches on title, description and tags', () {
      final blueprint = Blueprint.fromJson(row)!;
      expect(blueprint.matches('morning'), isTrue);
      expect(blueprint.matches('BRIEFING'), isTrue);
      expect(blueprint.matches('short'), isTrue);
      expect(blueprint.matches('weather'), isFalse);
      expect(blueprint.matches(''), isTrue);
    });

    test('finds the slot a server message names', () {
      final blueprint = Blueprint.fromJson(row)!;
      expect(
        blueprint.fieldIn('invalid time \'25:00\' — use HH:MM (24h)')?.name,
        'time',
      );
      expect(blueprint.fieldIn('something else'), isNull);
    });
  });
}
