import 'schedule_models.dart';

enum EveryUnit {
  minutes('m', 'minutes', 1),
  hours('h', 'hours', 60),
  days('d', 'days', 1440);

  const EveryUnit(this.suffix, this.label, this.inMinutes);

  final String suffix;
  final String label;
  final int inMinutes;
}

/// When a job runs, as the picker sees it. [toSchedule] writes the string the
/// server reads; [fromJob] reads a stored schedule back, falling to [CronSpec]
/// for anything the picker cannot show, so opening a job never rewrites it.
sealed class ScheduleSpec {
  const ScheduleSpec();

  /// The schedule string for `POST /api/cron/jobs`.
  String toSchedule();

  /// Why this cannot be saved, or null.
  String? validate(DateTime now);

  /// The next [count] run times after [now], or null when they cannot be
  /// worked out on the phone (a raw expression: the server decides).
  List<DateTime>? nextRuns(DateTime now, int count);

  static ScheduleSpec fromJob(CronJob job) {
    final minutes = job.scheduleMinutes;
    switch (job.scheduleKind) {
      case 'interval' when minutes != null && minutes > 0:
        for (final unit in [EveryUnit.days, EveryUnit.hours]) {
          if (minutes % unit.inMinutes == 0) {
            return EverySpec(minutes ~/ unit.inMinutes, unit);
          }
        }
        return EverySpec(minutes, EveryUnit.minutes);
      case 'once' when job.scheduleRunAt != null:
        return OnceSpec(job.scheduleRunAt!.toLocal());
      case 'cron' when job.scheduleExpr != null:
        return _fromCron(job.scheduleExpr!);
    }
    return CronSpec(job.scheduleExpr ?? job.scheduleDisplay);
  }

  static ScheduleSpec _fromCron(String expr) {
    final fields = expr.trim().split(RegExp(r'\s+'));
    if (fields.length == 5) {
      final [minute, hour, dom, month, dow] = fields;
      final m = int.tryParse(minute);
      final h = int.tryParse(hour);
      if (m != null && h != null && dom == '*' && month == '*') {
        if (m <= 59 && h <= 23) {
          if (dow == '*') return DailySpec(h, m);
          final days = _days(dow);
          if (days != null && days.isNotEmpty) return WeeklySpec(days, h, m);
        }
      }
    }
    return CronSpec(expr.trim());
  }

  /// `1-5`, `0,6`, `1,3-4`: day numbers, Sunday 0 (7 also counts as Sunday).
  static Set<int>? _days(String field) {
    final days = <int>{};
    for (final part in field.split(',')) {
      final range = part.split('-');
      final from = int.tryParse(range.first);
      final to = range.length == 2 ? int.tryParse(range.last) : from;
      if (range.length > 2 || from == null || to == null) return null;
      if (from < 0 || to > 7 || from > to) return null;
      for (var d = from; d <= to; d++) {
        days.add(d % 7);
      }
    }
    return days;
  }
}

class EverySpec extends ScheduleSpec {
  const EverySpec(this.amount, this.unit);

  final int amount;
  final EveryUnit unit;

  @override
  String toSchedule() => 'every $amount${unit.suffix}';

  @override
  String? validate(DateTime now) =>
      amount >= 1 ? null : 'Enter a whole number of one or more';

  @override
  List<DateTime>? nextRuns(DateTime now, int count) => [
    for (var i = 1; i <= count; i++)
      now.add(Duration(minutes: amount * unit.inMinutes * i)),
  ];
}

String _two(int n) => n.toString().padLeft(2, '0');

class DailySpec extends ScheduleSpec {
  const DailySpec(this.hour, this.minute);

  final int hour;
  final int minute;

  @override
  String toSchedule() => '$minute $hour * * *';

  @override
  String? validate(DateTime now) => null;

  @override
  List<DateTime>? nextRuns(DateTime now, int count) =>
      WeeklySpec({0, 1, 2, 3, 4, 5, 6}, hour, minute).nextRuns(now, count);
}

class WeeklySpec extends ScheduleSpec {
  const WeeklySpec(this.days, this.hour, this.minute);

  /// Sunday 0 to Saturday 6.
  final Set<int> days;
  final int hour;
  final int minute;

  @override
  String toSchedule() =>
      '$minute $hour * * ${(days.toList()..sort()).join(',')}';

  @override
  String? validate(DateTime now) =>
      days.isEmpty ? 'Choose at least one day' : null;

  @override
  List<DateTime>? nextRuns(DateTime now, int count) {
    if (days.isEmpty) return const [];
    final runs = <DateTime>[];
    var day = DateTime(now.year, now.month, now.day);
    while (runs.length < count) {
      final at = DateTime(day.year, day.month, day.day, hour, minute);
      if (at.isAfter(now) && days.contains(at.weekday % 7)) runs.add(at);
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return runs;
  }
}

class OnceSpec extends ScheduleSpec {
  const OnceSpec(this.at);

  /// Local time.
  final DateTime at;

  /// ISO 8601 in UTC, so the server does not have to guess the phone's zone.
  @override
  String toSchedule() {
    final u = at.toUtc();
    return '${u.year.toString().padLeft(4, '0')}-${_two(u.month)}-${_two(u.day)}'
        'T${_two(u.hour)}:${_two(u.minute)}:${_two(u.second)}Z';
  }

  @override
  String? validate(DateTime now) =>
      at.isAfter(now) ? null : 'That time is in the past';

  @override
  List<DateTime>? nextRuns(DateTime now, int count) => [at];
}

class CronSpec extends ScheduleSpec {
  const CronSpec(this.text);

  final String text;

  @override
  String toSchedule() => text.trim();

  @override
  String? validate(DateTime now) =>
      text.trim().isEmpty ? 'Enter a schedule' : null;

  @override
  List<DateTime>? nextRuns(DateTime now, int count) => null;
}
