/// Response shapes for the server-care routes, written from the shapes the
/// design record documents for Hermes d923a5eb (0.22.2). They are NOT
/// recordings: `hermes` was not available when they were written, and the
/// contract checks in `test/real_backend_contract_test.dart` are what compare
/// them with a live backend. Model ids are placeholders.
library;

/// `YYYY-MM-DD` of [days] before [now].
String _daysBack(DateTime now, int days) {
  final d = now.subtract(Duration(days: days));
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Unix seconds [days] (and a half) before [now].
int _secondsBack(DateTime now, int days) =>
    now.subtract(Duration(days: days, hours: 12)).millisecondsSinceEpoch ~/
    1000;

/// The release date is fixed unless a test gives its own clock, because tests
/// assert it by value.
final _fixedNow = DateTime(2026, 11, 14, 12);

Map<String, dynamic> statusHealthy({DateTime? now}) => {
  'version': '0.22.2',
  'release_date': _daysBack(now ?? _fixedNow, 12),
  'config_version': 31,
  'latest_config_version': 31,
  'can_update_hermes': true,
  'gateway_running': true,
  'gateway_state': 'running',
  'gateway_platforms': {
    'telegram': {'state': 'connected'},
  },
  'gateway_heartbeat_stale_s': null,
  'gateway_shared_with': ['default', 'work'],
  'active_agents': 1,
  'components': {
    'gateway': {'status': 'ok', 'state': 'running'},
    'storage': {'status': 'ok'},
    'platforms': {'status': 'ok', 'configured': 1, 'connected': 1},
  },
  'overall': 'ok',
  'memory': {
    'pressure': 'ok',
    'gateway_rss_mb': 410,
    'last_boot_suspected_oom': false,
  },
  'disk': {'pressure': 'ok', 'free_mb': 52000, 'used_percent': 38.0},
  'profiles': ['default', 'work'],
};

/// A server from before `components`, `memory` and `disk`.
Map<String, dynamic> statusOld() => {
  'version': '0.20.0',
  'gateway_running': true,
  'gateway_state': 'running',
  'profiles': ['default'],
};

/// The commits are 2 and 5 days (and a half) old at [now], so the Update page
/// reads "2 days ago" on any date.
Map<String, dynamic> updateCheckBehind({DateTime? now}) => {
  'install_method': 'git',
  'current_version': '0.22.2',
  'behind': 2,
  'update_available': true,
  'can_apply': true,
  'update_command': 'hermes update',
  'message': null,
  'commits': [
    {
      'sha': '1a2b3c4',
      'summary': 'Fix a thing',
      'author': 'Ada',
      'at': _secondsBack(now ?? DateTime.now(), 2),
    },
    {
      'sha': '5d6e7f8',
      'summary': 'Add another',
      'author': 'Bo',
      'at': _secondsBack(now ?? DateTime.now(), 5),
    },
    {'summary': 'no sha'},
    'junk',
  ],
};

Map<String, dynamic> updateCheckDocker() => {
  'install_method': 'docker',
  'current_version': '0.22.2',
  'behind': null,
  'update_available': false,
  'can_apply': false,
  'update_command': 'docker compose pull && docker compose up -d',
  'message': "Couldn't reach the update source — try again later.",
};

Map<String, dynamic> updateCheckManaged() => {
  'install_method': 'managed-runtime',
  'update_command': '',
  'message':
      'Hermes updates are managed outside this dashboard in containerized '
      'environments.',
};

Map<String, dynamic> updateStarted() => {
  'ok': true,
  'pid': 12345,
  'name': 'hermes-update',
  'action_id': 'a' * 32,
};

Map<String, dynamic> updateRefused() => {
  'ok': false,
  'pid': null,
  'name': 'hermes-update',
  'error': 'docker_update_unsupported',
  'message': 'Update the container image instead.',
  'update_command': 'docker compose pull',
};

Map<String, dynamic> receiptSuccess({String actionId = 'a'}) => {
  'receipt': {'anything': 'full'},
  'summary': {
    'outcome': 'success',
    'started_at': '2026-11-14T09:00:00Z',
    'finished_at': '2026-11-14T09:03:00Z',
    'action_id': actionId * 32,
    'pre_sha': 'd923a5e',
    'post_sha': '0a1b2c3',
    'post_version': '0.23.0',
    'followups': <Object>[],
    'user_action': null,
  },
};

Map<String, dynamic> receiptPartial() => {
  'summary': {
    'outcome': 'partial',
    'action_id': 'b' * 32,
    'post_version': '0.23.0',
    'followups': [
      {'step': 'restart', 'reason': 'Restart the dashboard by hand.'},
    ],
    'user_action': {
      'step': 'migrate',
      'reason': "Run 'hermes config migrate'.",
    },
  },
};

Map<String, dynamic> actionStatusAfterTwoRuns() => {
  'name': 'doctor',
  'running': false,
  'exit_code': 1,
  'pid': 4321,
  'lines': [
    '=== doctor started 2026-11-14 08:00:00 ===',
    'old run line',
    '=== doctor started 2026-11-14 09:00:00 ===',
    ...doctorProblems,
  ],
};

const doctorProblems = [
  '\x1B[1m◆ Configuration\x1B[0m',
  '  ✓ config.yaml found',
  "  ⚠ Config version 30 is behind 31  run 'hermes config migrate'",
  '    → Older keys still work',
  '◆ Messaging',
  '  ✗ Telegram token rejected (401)',
  '  something unexpected',
  '────────────────────────────────────────────────────────────',
  '  Found 2 issue(s) to address:',
  '',
  "  1. Re-run 'hermes setup telegram'",
  '  2. Migrate the config',
];

const doctorAllPassed = [
  '=== doctor started 2026-11-14 09:00:00 ===',
  '◆ Configuration',
  '  ✓ config.yaml found',
  'All checks passed! 🎉',
];

const logsErrors = [
  '2026-11-14 09:12:03,114 ERROR [sess_ab12] gateway.run: Telegram failed',
  'Traceback (most recent call last):',
  '  File "x.py", line 1, in <module>',
  'ValueError: boom',
  '2026-11-14 09:12:04,001 WARNING agent.loop: retrying',
];

/// Two days of use, the newest 2 days before [today]. The default is the day
/// the controller and repository tests inject, so their expectations hold;
/// a test that reads the real clock passes `today: DateTime.now()`.
Map<String, dynamic> usage30({DateTime? today}) => {
  'daily': [
    {
      'day': _daysBack(today ?? DateTime(2026, 11, 14), 2),
      'input_tokens': 812000,
      'output_tokens': 64000,
      'cache_read_tokens': 410000,
      'reasoning_tokens': 12000,
      'estimated_cost': 1.2,
      'actual_cost': 0,
      'sessions': 9,
      'api_calls': 41,
    },
    {
      'day': _daysBack(today ?? DateTime(2026, 11, 14), 4),
      'input_tokens': 1000,
      'output_tokens': 500,
      'sessions': 1,
    },
    {'day': 'not a date', 'input_tokens': 5},
  ],
  'by_model': [
    {
      'model': '<small model>',
      'input_tokens': 10,
      'output_tokens': 5,
      'sessions': 1,
    },
    {
      'model': '<model id>',
      'input_tokens': 790000,
      'output_tokens': 60000,
      'estimated_cost': 1.16,
      'sessions': 8,
      'api_calls': 38,
    },
    {'input_tokens': 1},
  ],
  'by_task': <Object>[],
  'totals': {
    'total_input': 813000,
    'total_output': 64500,
    'total_cache_read': 410000,
    'total_reasoning': 12000,
    'total_estimated_cost': 1.2,
    'total_actual_cost': 0.9,
    'total_sessions': 10,
    'total_api_calls': 41,
  },
  'period_days': 30,
};
