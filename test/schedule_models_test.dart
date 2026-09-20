import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/schedules/schedule_models.dart';

import 'support/cron_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 9, 20, 12);

  CronJob job(Map<String, Object?> row) => CronJob.fromJson(row)!;

  group('CronJob.fromJson', () {
    test('reads a full row', () {
      final parsed = job(
        cronJobRow(
          nextRunAt: '2026-09-21T08:00:00+00:00',
          lastRunAt: '2026-09-20T08:00:00+00:00',
          lastStatus: 'ok',
          skills: ['web-search'],
          model: 'hermes-4',
        ),
      );

      expect(parsed.id, 'job1');
      expect(parsed.title, 'Morning brief');
      expect(parsed.scheduleDisplay, 'Weekdays at 08:00');
      expect(parsed.scheduleKind, 'cron');
      expect(parsed.scheduleExpr, '0 8 * * 1-5');
      expect(parsed.nextRunAt, DateTime.utc(2026, 9, 21, 8));
      expect(parsed.skills, ['web-search']);
      expect(parsed.model, 'hermes-4');
      expect(parsed.profile, 'work');
      expect(parsed.outcome, CronOutcome.ok);
    });

    test('skips rows without an id and rows that are not objects', () {
      expect(CronJob.fromJson({'name': 'no id'}), isNull);
      expect(CronJob.fromJson({'id': ''}), isNull);
      expect(CronJob.fromJson('nope'), isNull);
    });

    test('treats an unknown state as scheduled', () {
      expect(job(cronJobRow(state: 'exploding')).state, CronJobState.scheduled);
    });

    test('ignores a time that does not parse', () {
      expect(job(cronJobRow(nextRunAt: 'tomorrow-ish')).nextRunAt, isNull);
    });

    test('names a job without a name by its prompt', () {
      final parsed = job(
        cronJobRow(name: '', prompt: 'Check the price of the GPU every day'),
      );
      expect(parsed.title, 'Check the price of the GPU');
    });
  });

  group('outcome', () {
    test('is none before the first run', () {
      expect(job(cronJobRow()).outcome, CronOutcome.none);
    });

    test('is failed for an error and for other non-ok statuses', () {
      expect(job(cronJobRow(lastStatus: 'error')).outcome, CronOutcome.failed);
      expect(
        job(cronJobRow(lastStatus: 'blocked_config')).outcome,
        CronOutcome.failed,
      );
    });

    test(
      'is deliveryFailed for the status and for ok with a delivery error',
      () {
        expect(
          job(cronJobRow(lastStatus: 'delivery_failed')).outcome,
          CronOutcome.deliveryFailed,
        );
        expect(
          job(cronJobRow(lastStatus: 'ok', lastDeliveryError: 'no channel'))
              .outcome,
          CronOutcome.deliveryFailed,
        );
      },
    );
  });

  group('scheduleWords', () {
    String words(Map<String, Object?> schedule, {String display = ''}) =>
        job(cronJobRow(display: display, schedule: schedule)).scheduleWords;

    test('spells out daily, weekday, weekend and weekly expressions', () {
      String cron(String expr) => words({'kind': 'cron', 'expr': expr});
      expect(cron('30 8 * * *'), 'Daily at 08:30');
      expect(cron('0 8 * * 1-5'), 'Weekdays at 08:00');
      expect(cron('0 10 * * 0,6'), 'Weekends at 10:00');
      expect(cron('0 16 * * 5'), 'Fridays at 16:00');
      expect(cron('0 9 * * 1,4'), 'Mon, Thu at 09:00');
    });

    test('keeps the expression for shapes it does not spell out', () {
      expect(
        words({'kind': 'cron', 'expr': '*/7 9-17 * * 1-5'}),
        '*/7 9-17 * * 1-5',
      );
    });

    test('spells out intervals', () {
      Map<String, Object?> every(int minutes) => {
        'kind': 'interval',
        'minutes': minutes,
      };
      expect(words(every(360)), 'Every 6 hours');
      expect(words(every(60)), 'Every hour');
      expect(words(every(30)), 'Every 30 minutes');
      expect(words(every(2880)), 'Every 2 days');
    });

    test('uses the server display for a one-shot', () {
      expect(
        words({'kind': 'once'}, display: 'once at 2026-10-01 09:00'),
        'once at 2026-10-01 09:00',
      );
    });
  });

  group('sortJobs', () {
    test('puts failing first, then soonest, then paused', () {
      final jobs = [
        job(cronJobRow(id: 'paused', state: 'paused', name: 'Paused')),
        job(
          cronJobRow(
            id: 'later',
            name: 'Later',
            nextRunAt: '2026-09-22T08:00:00+00:00',
          ),
        ),
        job(
          cronJobRow(
            id: 'soon',
            name: 'Soon',
            nextRunAt: '2026-09-21T08:00:00+00:00',
          ),
        ),
        job(
          cronJobRow(
            id: 'bad',
            name: 'Bad',
            lastStatus: 'error',
            nextRunAt: '2026-09-25T08:00:00+00:00',
          ),
        ),
      ];

      expect(sortJobs(jobs).map((j) => j.id), [
        'bad',
        'soon',
        'later',
        'paused',
      ]);
    });
  });

  group('filterJobs', () {
    final jobs = [
      job(cronJobRow(id: 'ok', lastStatus: 'ok')),
      job(cronJobRow(id: 'bad', lastStatus: 'error')),
      job(cronJobRow(id: 'stuck', state: 'error')),
      job(cronJobRow(id: 'off', state: 'paused')),
    ];

    test('failing covers a failed run and the error state', () {
      expect(filterJobs(jobs, ScheduleFilter.failing).map((j) => j.id), [
        'bad',
        'stuck',
      ]);
    });

    test('paused keeps only paused jobs', () {
      expect(filterJobs(jobs, ScheduleFilter.paused).map((j) => j.id), ['off']);
    });
  });

  group('relativeTime', () {
    test('says in the future and ago in the past', () {
      expect(relativeTime(now.add(const Duration(hours: 3)), now), 'in 3 h');
      expect(
        relativeTime(now.subtract(const Duration(hours: 2)), now),
        '2 h ago',
      );
      expect(
        relativeTime(now.add(const Duration(minutes: 80)), now),
        'in 1 h 20 min',
      );
      expect(relativeTime(now.add(const Duration(days: 2)), now), 'in 2 d');
    });

    test('says now under a minute', () {
      expect(relativeTime(now.add(const Duration(seconds: 20)), now), 'now');
    });
  });

  test('CronRun reads epoch seconds and skips rows without an id', () {
    final run = CronRun.fromJson(
      cronRunRow(id: 'cron_job1_1', startedAt: 1000, endedAt: 1042),
    )!;
    expect(run.duration, const Duration(seconds: 42));
    expect(run.isActive, isFalse);
    expect(CronRun.fromJson({'started_at': 1}), isNull);
  });

  test('DeliveryTarget reads whether a home channel is set', () {
    final target = DeliveryTarget.fromJson({
      'id': 'discord',
      'name': 'Discord',
      'home_target_set': false,
    })!;
    expect(target.homeTargetSet, isFalse);
    expect(DeliveryTarget.fromJson({'name': 'x'}), isNull);
  });
}
