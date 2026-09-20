import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/schedules/schedule_models.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';

import 'support/cron_fixtures.dart';

void main() {
  CronJob job(Map<String, Object?> schedule) =>
      CronJob.fromJson(cronJobRow(schedule: schedule))!;

  group('toSchedule', () {
    test('writes every, daily and weekly in the forms the server reads', () {
      expect(const EverySpec(6, EveryUnit.hours).toSchedule(), 'every 6h');
      expect(const EverySpec(30, EveryUnit.minutes).toSchedule(), 'every 30m');
      expect(const EverySpec(2, EveryUnit.days).toSchedule(), 'every 2d');
      expect(const DailySpec(8, 30).toSchedule(), '30 8 * * *');
      expect(const WeeklySpec({4, 1}, 9, 0).toSchedule(), '0 9 * * 1,4');
    });

    test('writes a one-shot as UTC ISO 8601', () {
      final at = DateTime.utc(2026, 10, 1, 7, 5).toLocal();
      expect(OnceSpec(at).toSchedule(), '2026-10-01T07:05:00Z');
    });

    test('trims a raw expression', () {
      expect(
        const CronSpec('  */7 9-17 * * 1-5 ').toSchedule(),
        '*/7 9-17 * * 1-5',
      );
    });
  });

  group('validate', () {
    final now = DateTime(2026, 9, 20, 12);

    test('refuses an interval below one', () {
      expect(const EverySpec(0, EveryUnit.hours).validate(now), isNotNull);
      expect(const EverySpec(1, EveryUnit.hours).validate(now), isNull);
    });

    test('refuses weekly without a day', () {
      expect(
        const WeeklySpec({}, 9, 0).validate(now),
        'Choose at least one day',
      );
    });

    test('refuses a one-shot in the past', () {
      expect(
        OnceSpec(DateTime(2026, 9, 20, 11)).validate(now),
        'That time is in the past',
      );
      expect(OnceSpec(DateTime(2026, 9, 20, 13)).validate(now), isNull);
    });

    test('refuses an empty expression', () {
      expect(const CronSpec('  ').validate(now), isNotNull);
    });
  });

  group('nextRuns', () {
    // A Sunday.
    final now = DateTime(2026, 9, 20, 12);

    test('daily: today if the time is ahead, otherwise tomorrow', () {
      expect(const DailySpec(15, 0).nextRuns(now, 2), [
        DateTime(2026, 9, 20, 15),
        DateTime(2026, 9, 21, 15),
      ]);
      expect(const DailySpec(8, 30).nextRuns(now, 1), [
        DateTime(2026, 9, 21, 8, 30),
      ]);
    });

    test('weekly: only the chosen days', () {
      expect(const WeeklySpec({1, 4}, 9, 0).nextRuns(now, 3), [
        DateTime(2026, 9, 21, 9),
        DateTime(2026, 9, 24, 9),
        DateTime(2026, 9, 28, 9),
      ]);
    });

    test('every: steps from now', () {
      expect(const EverySpec(6, EveryUnit.hours).nextRuns(now, 2), [
        DateTime(2026, 9, 20, 18),
        DateTime(2026, 9, 21),
      ]);
    });

    test('a raw expression has no preview', () {
      expect(const CronSpec('*/7 * * * *').nextRuns(now, 3), isNull);
    });
  });

  group('fromJob', () {
    test('reads an interval as every, in the largest whole unit', () {
      final spec = ScheduleSpec.fromJob(
        job({'kind': 'interval', 'minutes': 360}),
      );
      expect(spec, isA<EverySpec>());
      expect(spec.toSchedule(), 'every 6h');
      expect(
        ScheduleSpec.fromJob(job({'kind': 'interval', 'minutes': 45}))
            .toSchedule(),
        'every 45m',
      );
      expect(
        ScheduleSpec.fromJob(job({'kind': 'interval', 'minutes': 2880}))
            .toSchedule(),
        'every 2d',
      );
    });

    test('reads daily, weekday and named-day expressions', () {
      ScheduleSpec cron(String expr) =>
          ScheduleSpec.fromJob(job({'kind': 'cron', 'expr': expr}));
      expect(cron('30 8 * * *'), isA<DailySpec>());
      expect((cron('0 8 * * 1-5') as WeeklySpec).days, {1, 2, 3, 4, 5});
      expect((cron('0 9 * * 1,4') as WeeklySpec).days, {1, 4});
      expect((cron('0 9 * * 7') as WeeklySpec).days, {0});
    });

    test('keeps an unusual expression as it is', () {
      final spec = ScheduleSpec.fromJob(
        job({'kind': 'cron', 'expr': '*/7 9-17 * * 1-5'}),
      );
      expect(spec, isA<CronSpec>());
      expect(spec.toSchedule(), '*/7 9-17 * * 1-5');
      expect(
        ScheduleSpec.fromJob(job({'kind': 'cron', 'expr': '0 8 1 * *'})),
        isA<CronSpec>(),
      );
    });

    test('reads a one-shot in local time', () {
      final spec = ScheduleSpec.fromJob(
        job({'kind': 'once', 'run_at': '2026-10-01T07:05:00+00:00'}),
      );
      expect(spec, isA<OnceSpec>());
      expect(spec.toSchedule(), '2026-10-01T07:05:00Z');
    });

    test('round-trips what it writes', () {
      for (final spec in [
        const EverySpec(6, EveryUnit.hours),
        const DailySpec(8, 30),
        const WeeklySpec({1, 4}, 9, 0),
      ]) {
        final stored = switch (spec) {
          EverySpec(:final amount, :final unit) => {
            'kind': 'interval',
            'minutes': amount * unit.inMinutes,
          },
          _ => {'kind': 'cron', 'expr': spec.toSchedule()},
        };
        expect(
          ScheduleSpec.fromJob(job(stored)).toSchedule(),
          spec.toSchedule(),
        );
      }
    });
  });
}
