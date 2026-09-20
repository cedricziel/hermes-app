enum CronJobState { scheduled, paused, completed, error }

/// How a job's last run ended, as far as the list is concerned.
enum CronOutcome { none, ok, failed, deliveryFailed }

/// A scheduled task as `GET /api/cron/jobs` reports it. The routes declare no
/// response schema, so every field is read leniently.
class CronJob {
  const CronJob({
    required this.id,
    required this.name,
    this.prompt = '',
    this.scheduleKind,
    this.scheduleExpr,
    this.scheduleMinutes,
    this.scheduleRunAt,
    this.scheduleDisplay = '',
    this.state = CronJobState.scheduled,
    this.nextRunAt,
    this.lastRunAt,
    this.lastStatus,
    this.lastError,
    this.lastDeliveryError,
    this.deliver,
    this.skills = const [],
    this.model,
    this.provider,
    this.script,
    this.workdir,
    this.contextFrom = const [],
    this.repeatTimes,
    this.repeatCompleted = 0,
    this.profile,
  });

  final String id;
  final String name;
  final String prompt;

  /// The stored schedule: `interval` (minutes), `cron` (expr) or `once`
  /// (run_at).
  final String? scheduleKind;
  final String? scheduleExpr;
  final int? scheduleMinutes;
  final DateTime? scheduleRunAt;
  final String scheduleDisplay;

  final CronJobState state;
  final DateTime? nextRunAt;
  final DateTime? lastRunAt;
  final String? lastStatus;
  final String? lastError;
  final String? lastDeliveryError;
  final String? deliver;
  final List<String> skills;
  final String? model;
  final String? provider;
  final String? script;
  final String? workdir;
  final List<String> contextFrom;
  final int? repeatTimes;
  final int repeatCompleted;
  final String? profile;

  /// Unique across profiles: another profile can hold a job with this id.
  String get key => '${profile ?? ''}/$id';

  bool get isPaused => state == CronJobState.paused;

  CronOutcome get outcome {
    final status = lastStatus;
    if (status == null || status.isEmpty) return CronOutcome.none;
    if (status == 'delivery_failed') return CronOutcome.deliveryFailed;
    if (status != 'ok') return CronOutcome.failed;
    final delivery = lastDeliveryError;
    if (delivery != null && delivery.isNotEmpty) {
      return CronOutcome.deliveryFailed;
    }
    return CronOutcome.ok;
  }

  /// A job to look at first: its last run failed or it is stuck in error.
  bool get isFailing =>
      state == CronJobState.error || outcome == CronOutcome.failed;

  /// When the job runs, in words. The server's own display of a cron job is
  /// its expression, so the common shapes are spelled out here; anything else
  /// falls back to what the server says.
  String get scheduleWords {
    final minutes = scheduleMinutes;
    if (scheduleKind == 'interval' && minutes != null && minutes > 0) {
      String every(int n, String unit) =>
          n == 1 ? 'Every $unit' : 'Every $n ${unit}s';
      if (minutes % 1440 == 0) return every(minutes ~/ 1440, 'day');
      if (minutes % 60 == 0) return every(minutes ~/ 60, 'hour');
      return every(minutes, 'minute');
    }
    final expr = scheduleExpr;
    if (scheduleKind == 'cron' && expr != null) {
      final words = _cronWords(expr);
      if (words != null) return words;
    }
    return scheduleDisplay.isNotEmpty ? scheduleDisplay : expr ?? '';
  }

  /// The name, or the prompt's first words for a job that has none.
  String get title {
    if (name.trim().isNotEmpty) return name.trim();
    final words = prompt.trim().split(RegExp(r'\s+')).take(6).join(' ');
    return words.isEmpty ? 'Untitled task' : words;
  }

  CronJob copyWith({CronJobState? state, DateTime? nextRunAt}) => CronJob(
    id: id,
    name: name,
    prompt: prompt,
    scheduleKind: scheduleKind,
    scheduleExpr: scheduleExpr,
    scheduleMinutes: scheduleMinutes,
    scheduleRunAt: scheduleRunAt,
    scheduleDisplay: scheduleDisplay,
    state: state ?? this.state,
    nextRunAt: state == CronJobState.paused
        ? null
        : nextRunAt ?? this.nextRunAt,
    lastRunAt: lastRunAt,
    lastStatus: lastStatus,
    lastError: lastError,
    lastDeliveryError: lastDeliveryError,
    deliver: deliver,
    skills: skills,
    model: model,
    provider: provider,
    script: script,
    workdir: workdir,
    contextFrom: contextFrom,
    repeatTimes: repeatTimes,
    repeatCompleted: repeatCompleted,
    profile: profile,
  );

  /// Null for a row without an id.
  static CronJob? fromJson(Object? row) {
    if (row is! Map) return null;
    final id = row['id'];
    if (id is! String || id.isEmpty) return null;
    final schedule = row['schedule'] is Map ? row['schedule'] as Map : const {};
    final repeat = row['repeat'] is Map ? row['repeat'] as Map : const {};
    return CronJob(
      id: id,
      name: _text(row['name']) ?? '',
      prompt: _text(row['prompt']) ?? '',
      scheduleKind: _text(schedule['kind']),
      scheduleExpr: _text(schedule['expr']),
      scheduleMinutes: (schedule['minutes'] as num?)?.toInt(),
      scheduleRunAt: _time(schedule['run_at']),
      scheduleDisplay:
          _text(row['schedule_display']) ?? _text(schedule['display']) ?? '',
      state: switch (row['state']) {
        'paused' => CronJobState.paused,
        'completed' => CronJobState.completed,
        'error' => CronJobState.error,
        _ => CronJobState.scheduled,
      },
      nextRunAt: _time(row['next_run_at']),
      lastRunAt: _time(row['last_run_at']),
      lastStatus: _text(row['last_status']),
      lastError: _text(row['last_error']),
      lastDeliveryError: _text(row['last_delivery_error']),
      deliver: _text(row['deliver']),
      skills: _list(row['skills']),
      model: _text(row['model']),
      provider: _text(row['provider']),
      script: _text(row['script']),
      workdir: _text(row['workdir']),
      contextFrom: _list(row['context_from']),
      repeatTimes: (repeat['times'] as num?)?.toInt(),
      repeatCompleted: (repeat['completed'] as num?)?.toInt() ?? 0,
      profile: _text(row['profile_name']) ?? _text(row['profile']),
    );
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static List<String> _list(Object? value) => value is List
      ? [
          for (final item in value)
            if (item is String && item.trim().isNotEmpty) item.trim(),
        ]
      : const [];

  static DateTime? _time(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _dayNames = [
  'Sundays',
  'Mondays',
  'Tuesdays',
  'Wednesdays',
  'Thursdays',
  'Fridays',
  'Saturdays',
];

/// A five-field expression that fires at one time of day, as words. Null for
/// anything else.
String? _cronWords(String expr) {
  final fields = expr.trim().split(RegExp(r'\s+'));
  if (fields.length != 5) return null;
  final [minute, hour, dom, month, dow] = fields;
  final m = int.tryParse(minute);
  final h = int.tryParse(hour);
  if (m == null || h == null || m > 59 || h > 23) return null;
  if (dom != '*' || month != '*') return null;
  final at = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  if (dow == '*') return 'Daily at $at';
  if (dow == '1-5') return 'Weekdays at $at';
  if (dow == '0,6' || dow == '6,0') return 'Weekends at $at';
  final numbers = [for (final d in dow.split(',')) int.tryParse(d)];
  if (numbers.isEmpty || numbers.any((d) => d == null || d < 0 || d > 7)) {
    return null;
  }
  final days = [for (final d in numbers) d! % 7]..sort();
  if (days.length == 1) return '${_dayNames[days.single]} at $at';
  return '${days.map((d) => _days[d]).join(', ')} at $at';
}

/// One run of a job: an ordinary session named `cron_<job id>_<time>`.
class CronRun {
  const CronRun({
    required this.sessionId,
    required this.startedAt,
    this.endedAt,
    this.isActive = false,
    this.title,
    this.profile,
  });

  final String sessionId;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// Still going: the server saw activity recently and no end.
  final bool isActive;
  final String? title;
  final String? profile;

  Duration? get duration => endedAt?.difference(startedAt);

  static CronRun? fromJson(Object? row) {
    if (row is! Map) return null;
    final id = row['id'];
    if (id is! String || id.isEmpty) return null;
    return CronRun(
      sessionId: id,
      startedAt:
          _epoch(row['started_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: _epoch(row['ended_at']),
      isActive: row['is_active'] == true,
      title: row['title'] is String ? row['title'] as String : null,
      profile: row['profile'] is String ? row['profile'] as String : null,
    );
  }

  static DateTime? _epoch(Object? seconds) => seconds is num
      ? DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round())
      : null;
}

class DeliveryTarget {
  const DeliveryTarget({
    required this.id,
    required this.name,
    this.homeTargetSet = true,
  });

  final String id;
  final String name;

  /// False when the platform has no home channel to deliver to.
  final bool homeTargetSet;

  static DeliveryTarget? fromJson(Object? row) {
    if (row is! Map) return null;
    final id = row['id'];
    if (id is! String || id.isEmpty) return null;
    final name = row['name'];
    return DeliveryTarget(
      id: id,
      name: name is String && name.isNotEmpty ? name : id,
      homeTargetSet: row['home_target_set'] != false,
    );
  }
}

enum ScheduleFilter { all, failing, paused }

/// Failing jobs first, then by soonest next run, then paused and completed.
List<CronJob> sortJobs(Iterable<CronJob> jobs) {
  int rank(CronJob job) {
    if (job.isFailing) return 0;
    if (job.isPaused || job.state == CronJobState.completed) return 2;
    return 1;
  }

  final sorted = jobs.toList();
  sorted.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    final an = a.nextRunAt;
    final bn = b.nextRunAt;
    if (an != null && bn != null) return an.compareTo(bn);
    if (an != null) return -1;
    if (bn != null) return 1;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  });
  return sorted;
}

List<CronJob> filterJobs(Iterable<CronJob> jobs, ScheduleFilter filter) =>
    switch (filter) {
      ScheduleFilter.all => jobs.toList(),
      ScheduleFilter.failing => jobs.where((j) => j.isFailing).toList(),
      ScheduleFilter.paused => jobs.where((j) => j.isPaused).toList(),
    };

/// "in 3 h", "2 h ago", "in 1 h 20 min". Under a minute is "now".
String relativeTime(DateTime time, DateTime now) {
  final diff = time.difference(now);
  final span = diff.abs();
  final text = _span(span);
  if (text == null) return 'now';
  return diff.isNegative ? '$text ago' : 'in $text';
}

String? _span(Duration span) {
  if (span.inMinutes < 1) return null;
  if (span.inHours < 1) return '${span.inMinutes} min';
  if (span.inHours < 6 && span.inMinutes % 60 != 0) {
    return '${span.inHours} h ${span.inMinutes % 60} min';
  }
  if (span.inDays < 1) return '${span.inHours} h';
  return '${span.inDays} d';
}

String formatDuration(Duration span) {
  if (span.inSeconds < 60) return '${span.inSeconds} s';
  if (span.inMinutes < 60) {
    final seconds = span.inSeconds % 60;
    return seconds == 0
        ? '${span.inMinutes} min'
        : '${span.inMinutes} min $seconds s';
  }
  return '${span.inHours} h ${span.inMinutes % 60} min';
}
