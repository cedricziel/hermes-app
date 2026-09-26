/// A job as `GET /api/cron/jobs` reports it.
Map<String, Object?> cronJobRow({
  String id = 'job1',
  String name = 'Morning brief',
  String prompt = 'Say good morning',
  String state = 'scheduled',
  String display = 'Weekdays at 08:00',
  Map<String, Object?>? schedule,
  String? nextRunAt,
  String? lastRunAt,
  String? lastStatus,
  String? lastError,
  String? lastDeliveryError,
  String deliver = 'local',
  List<String> skills = const [],
  String? model,
  String? provider,
  String profile = 'work',
}) => {
  'id': id,
  'name': name,
  'prompt': prompt,
  'state': state,
  'enabled': state != 'paused',
  'schedule_display': display,
  'schedule':
      schedule ?? {'kind': 'cron', 'expr': '0 8 * * 1-5', 'display': display},
  'next_run_at': nextRunAt,
  'last_run_at': lastRunAt,
  'last_status': lastStatus,
  'last_error': lastError,
  'last_delivery_error': lastDeliveryError,
  'deliver': deliver,
  'skills': skills,
  'model': model,
  'provider': provider,
  'repeat': {'times': null, 'completed': 0},
  'profile': profile,
  'profile_name': profile,
};

/// One run session as `GET /api/cron/jobs/{id}/runs` reports it.
Map<String, Object?> cronRunRow({
  required String id,
  required int startedAt,
  int? endedAt,
  bool active = false,
  String profile = 'work',
}) => {
  'id': id,
  'source': 'cron',
  'started_at': startedAt,
  'ended_at': endedAt,
  'is_active': active,
  'profile': profile,
};

const cronDeliveryTargets = {
  'targets': [
    {'id': 'local', 'name': 'Local (save only)', 'home_target_set': true},
  ],
};
