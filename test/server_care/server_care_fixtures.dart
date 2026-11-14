/// Response shapes for the server-care routes. The `recorded*` fixtures at the
/// end of this file are real answers of Hermes d923a5eb (a throwaway
/// install), with only paths, the install id and model ids replaced. Every
/// other fixture here is HAND-MADE from the shapes the design record
/// documents: variants a throwaway backend cannot reach (a running or shared
/// gateway, pressure levels, a git install behind its remote, update
/// receipts, docker or managed installs). Model ids are placeholders.
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

// ---------------------------------------------------------------------------
// Recorded from a throwaway Hermes at d923a5eb (a git install, no gateway ever
// started, an empty HERMES_HOME). The `recorded*` fixtures below are real
// answers with only paths, the install id and the model id replaced. The
// doctor log has no ANSI escapes because the dashboard runs it without a
// terminal.
// ---------------------------------------------------------------------------

/// `GET /api/status` of a fresh install: gateway stopped, `version` is the
/// literal string "unknown" (a git checkout), the config is 50 versions ahead
/// of the empty home.
Map<String, dynamic> recordedStatusGatewayStopped() => {
  'version': 'unknown',
  'release_date': '2026.9.24',
  'config_version': 0,
  'latest_config_version': 50,
  'can_update_hermes': true,
  'gateway_running': false,
  'gateway_state': null,
  'gateway_platforms': {},
  'gateway_exit_reason': null,
  'gateway_updated_at': null,
  'gateway_heartbeat_stale_s': null,
  'gateway_shared_with': null,
  'active_agents': 0,
  'gateway_busy': false,
  'gateway_drainable': false,
  'restart_drain_timeout': 0.0,
  'active_sessions': 0,
  'auth_required': false,
  'auth_providers': [],
  'auth_flows': [],
  'nous_session_valid': 'unknown',
  'install_id': '00000000000000000000000000000000',
  'shared_profile_warning': false,
  'components': {
    'gateway': {'status': 'degraded', 'state': 'stopped'},
    'dashboard': {
      'status': 'ok',
      'recent_unhandled_errors': 0,
      'last_error_at': null,
      'selftest': 'unknown',
    },
    'storage': {'status': 'ok'},
    'platforms': {'status': 'ok', 'configured': 0, 'connected': 0},
  },
  'overall': 'degraded',
  'memory': {
    'pressure': 'unknown',
    'gateway_rss_mb': null,
    'system_total_mb': null,
    'system_available_mb': null,
    'swap_used_mb': null,
    'sampled_at': null,
    'last_boot_unclean': false,
    'last_boot_suspected_oom': false,
    'boot_id': null,
  },
  'disk': {
    'pressure': 'ok',
    'total_mb': 258019,
    'free_mb': 26108,
    'used_percent': 5.1,
  },
  'profiles': ['default'],
  'parked_profiles': [],
  'gateway_mode': 'none',
  'multiplex_standalone_reason': null,
  'hermes_home': '/srv/demo/hermes-home',
  'config_path': '/srv/demo/hermes-home/config.yaml',
  'env_path': '/srv/demo/hermes-home/.env',
  'gateway_pid': null,
  'gateway_health_url': null,
  'gateways': [],
};

/// `GET /api/health`.
Map<String, dynamic> recordedHealth() => {
  'ok': true,
  'version': 'unknown',
  'displayVersion': 'git.d923a5e',
  'commit': 'd923a5eb487a17c0a68801bba9ef0f56c81040a8',
  'auth_required': false,
};

/// `GET /api/hermes/update/check` on a git install whose update source could
/// not be reached (no remote): `behind` null, `can_apply` still true.
Map<String, dynamic> recordedUpdateCheckUnreachable() => {
  'install_method': 'git',
  'current_version': 'git.d923a5e',
  'behind': null,
  'update_available': false,
  'can_apply': true,
  'update_command': 'hermes update',
  'message': "Couldn't reach the update source — try again later.",
};

/// `GET /api/actions/<name>/status` before that action ever ran.
Map<String, dynamic> recordedActionStatusIdle(String name) => {
  'name': name,
  'running': false,
  'exit_code': null,
  'pid': null,
  'lines': <Object>[],
};

/// `GET /api/hermes/update/receipt` before any update ran (HTTP 404).
const recordedReceiptNone = {
  'detail': 'No update receipt found (no `hermes update` run recorded).',
};

/// `GET /api/logs?file=errors`: the first lines of the real file; every
/// line ends in a newline.
const recordedLogsErrors = [
  '2026-11-14 18:25:18,220 WARNING hermes_cli.post_update: config migration skipped: This config predates version 12 (~2 years old) and can no longer be auto-migrated. Back up /srv/demo/hermes-home/config.yaml and run `hermes setup` to regenerate, or manually set _config_version: 12 after reviewing the changelog.\n',
  '2026-11-14 18:25:55,902 WARNING agent.auxiliary_unavailable: Auxiliary Nous client unavailable: Nous Portal runtime credentials unavailable: Hermes is not logged into Nous Portal. Run `hermes model` to re-authenticate. (code: nous_auth_missing)\n',
  '2026-11-14 18:25:55,902 WARNING agent.auxiliary_client: Auxiliary Nous client unavailable: no Nous authentication found (run: hermes auth).\n',
  '2026-11-14 18:25:55,903 WARNING agent.auxiliary_client: resolve_provider_client: nous requested but Nous Portal not configured (run: hermes auth)\n',
];

/// `GET /api/logs?file=agent`: the first lines of the real file.
const recordedLogsAgent = [
  '2026-11-14 18:25:18,218 INFO hermes_cli.boot_bootstrap: home maintenance: code changed to d923a5eb487a, running steps\n',
  '2026-11-14 18:25:18,220 WARNING hermes_cli.post_update: config migration skipped: This config predates version 12 (~2 years old) and can no longer be auto-migrated. Back up /srv/demo/hermes-home/config.yaml and run `hermes setup` to regenerate, or manually set _config_version: 12 after reviewing the changelog.\n',
  "2026-11-14 18:25:18,713 INFO hermes_cli.plugins: Plugin 'browser-browser-use' registered browser provider: browser-use\n",
  "2026-11-14 18:25:18,715 INFO hermes_cli.plugins: Plugin 'browser-browserbase' registered browser provider: browserbase\n",
  "2026-11-14 18:25:18,717 INFO hermes_cli.plugins: Plugin 'browser-firecrawl' registered browser provider: firecrawl\n",
];

/// `GET /api/analytics/usage?days=7` with no history: the totals are null,
/// not 0, and `skills` and `tools` come with it.
Map<String, dynamic> recordedUsageEmpty() => {
  'daily': [],
  'by_model': [],
  'by_task': [],
  'totals': {
    'total_input': null,
    'total_output': null,
    'total_cache_read': null,
    'total_reasoning': null,
    'total_estimated_cost': 0,
    'total_actual_cost': 0,
    'total_sessions': 0,
    'total_api_calls': null,
  },
  'period_days': 7,
  'skills': {
    'summary': {
      'total_skill_loads': 0,
      'total_skill_edits': 0,
      'total_skill_actions': 0,
      'distinct_skills_used': 0,
    },
    'top_skills': [],
  },
  'tools': [],
};

/// The same route after one scripted-model turn with one tool call.
Map<String, dynamic> recordedUsageOneTurn() => {
  'daily': [
    {
      'day': '2026-11-14',
      'input_tokens': 20,
      'output_tokens': 20,
      'cache_read_tokens': 0,
      'reasoning_tokens': 0,
      'estimated_cost': 0.0,
      'actual_cost': 0,
      'sessions': 1,
      'api_calls': 2,
    },
  ],
  'by_model': [
    {
      'model': '<model id>',
      'input_tokens': 30,
      'output_tokens': 30,
      'estimated_cost': 0,
      'sessions': 1,
      'api_calls': 3,
      'aux_tasks': [
        {
          'task': 'title_generation',
          'input_tokens': 10,
          'output_tokens': 10,
          'estimated_cost': 0,
          'api_calls': 1,
        },
      ],
    },
  ],
  'by_task': [
    {
      'task': 'title_generation',
      'input_tokens': 10,
      'output_tokens': 10,
      'estimated_cost': 0,
      'api_calls': 1,
      'models': ['<model id>'],
    },
  ],
  'totals': {
    'total_input': 20,
    'total_output': 20,
    'total_cache_read': 0,
    'total_reasoning': 0,
    'total_estimated_cost': 0.0,
    'total_actual_cost': 0,
    'total_sessions': 1,
    'total_api_calls': 2,
  },
  'period_days': 7,
  'skills': {
    'summary': {
      'total_skill_loads': 0,
      'total_skill_edits': 0,
      'total_skill_actions': 0,
      'distinct_skills_used': 0,
    },
    'top_skills': [],
  },
  'tools': [
    {'tool': 'terminal', 'count': 1, 'percentage': 100.0},
  ],
};

/// The log of `POST /api/ops/doctor` followed to its end (exit code 1), every
/// line as the status route returned it.
const recordedDoctorLines = [
  '',
  '=== doctor started 2026-11-14 18:25:52 ===',
  '',
  '┌─────────────────────────────────────────────────────────┐',
  '│                 🩺 Hermes Doctor                        │',
  '└─────────────────────────────────────────────────────────┘',
  '',
  '◆ Security Advisories',
  '  ✓ No active security advisories',
  '',
  '◆ MCP Server Security',
  '  ✓ No suspicious MCP stdio commands',
  '',
  '◆ Python Environment',
  '  ✓ Python 3.14.6',
  '  ✓ SQLite 3.53.1',
  '    → SQLite source id: 2026-05-05 10:34:17 c88b22011a54b4f6fbd149e9f8e4…',
  '    → state.db: WAL journal mode (268.0 KB)',
  '  ✓ Runtime venv staged (/srv/demo/hermes-agent/.venv) (active in this process)',
  '',
  '◆ SSL / CA Certificates',
  '  ✓ TLS platform trust store configured; default SSL context available',
  '',
  '◆ Required Packages',
  '  ✓ OpenAI SDK',
  '  ✓ Rich (terminal UI)',
  '  ✓ python-dotenv',
  '  ✓ ruamel.yaml',
  '  ✓ HTTPX',
  '  ✓ Croniter (cron expressions) (optional)',
  '  ⚠ python-telegram-bot (optional, not installed)',
  '  ⚠ discord.py (optional, not installed)',
  '  ✓ Dashboard web surface (imports cleanly)',
  '',
  '◆ Configuration Files',
  '  ✗ /srv/demo/hermes-home/.env file missing',
  "    → Run 'hermes setup' to create one",
  '  ✓ /srv/demo/hermes-home/config.yaml exists',
  '  ⚠ Config version outdated (v0 → v50) (new settings available)',
  '  ✓ No deprecated config keys or env vars',
  '',
  '◆ xAI Model Retirement (May 15, 2026)',
  '  ✓ No retired xAI models in config',
  '',
  '◆ Session Reset (timers removed Sep 7, 2026)',
  '  ✓ No idle/daily session_reset policy configured',
  '',
  '◆ Auth Providers',
  '  ⚠ Nous Portal auth (not logged in)',
  '  ⚠ OpenAI Codex auth (not logged in)',
  '    → No Codex credentials stored. Run `hermes auth add openai-codex --type oauth` to authenticate.',
  '    → codex CLI not installed (optional — only required to import tokens from an existing Codex CLI login)',
  '  ⚠ MiniMax OAuth (not logged in)',
  '  ⚠ xAI OAuth (not logged in)',
  '    → No xAI OAuth credentials stored. Select xAI Grok OAuth (SuperGrok / Premium+) in `hermes model`.',
  '',
  '◆ Directory Structure',
  '  ✓ /srv/demo/hermes-home directory exists',
  '  ✓ /srv/demo/hermes-home/cron/ exists',
  '  ✓ /srv/demo/hermes-home/sessions/ exists',
  '  ✓ /srv/demo/hermes-home/logs/ exists',
  '  ✓ /srv/demo/hermes-home/skills/ exists',
  '  ✓ /srv/demo/hermes-home/memories/ exists',
  '  ✓ /srv/demo/hermes-home/cache/scratch/ is the scratch dir (TMPDIR; 0 B, entries pruned after 24h idle)',
  '  ✓ /srv/demo/hermes-home/SOUL.md exists (persona configured)',
  '  ✓ /srv/demo/hermes-home/memories/ directory exists',
  '    → MEMORY.md not created yet (will be created when the agent first writes a memory)',
  '    → USER.md not created yet (will be created when the agent first writes a memory)',
  '  ✓ /srv/demo/hermes-home/state.db exists (0 sessions)',
  '    → state.db logical size 268.0 KB, 67 pages, 0 free, WAL 0 B',
  '    → 0 messages, 0 sessions, journal_mode=wal, 1 process(es) holding the DB open',
  '    → FTS tables: messages_fts, messages_fts_trigram',
  '  ✓ /srv/demo/hermes-home/cron/ store is writable',
  '',
  '◆ Command Installation',
  '  ✓ Hermes entry point exists (/srv/demo/hermes-agent/.venv/bin/hermes)',
  '  ✗ ~/.local/bin/hermes not found (hermes command may not work outside the venv)',
  '',
  '◆ External Tools',
  '  ✓ git',
  '  ✓ ripgrep (rg) (faster file search)',
  '  ✓ Docker (optional)',
  '  ⚠ Node.js not found (optional; PM agent-browser is a native executable)',
  '  ⚠ agent-browser not installed (run: hermes pm install agent-browser)',
  '',
  '◆ API Connectivity',
  '  Running 44 connectivity checks in parallel…',
  '                                                                      ',
  '  ⚠ OpenRouter API (not configured)',
  '',
  '◆ Tool Availability',
  '  ✓ browser',
  '  ✓ browser-use',
  '  ✓ catalog',
  '  ✓ clarify',
  '  ✓ code_execution',
  '  ✓ connections',
  '  ✓ cronjob',
  '  ✓ delegation',
  '  ✓ desktop_ui',
  '  ✓ file',
  '  ✓ memory',
  '  ✓ onboarding',
  '  ✓ project',
  '  ✓ session_search',
  '  ✓ skills',
  '  ✓ terminal',
  '  ✓ todo',
  '  ✓ tts',
  '  ✓ kanban (runtime-gated; loaded only for dispatcher-spawned workers)',
  '  ✓ web search (keenable)',
  '  ✓ web extract (keenable)',
  '  ⚠ a2a (system dependency not met)',
  '  ⚠ browser-cdp (system dependency not met)',
  '  ⚠ computer_use (system dependency not met)',
  '  ⚠ discord (missing DISCORD_BOT_TOKEN)',
  '  ⚠ discord_admin (missing DISCORD_BOT_TOKEN)',
  '  ⚠ feishu_doc (system dependency not met)',
  '  ⚠ feishu_drive (system dependency not met)',
  '  ⚠ hermes-yuanbao (system dependency not met)',
  "  ⚠ image_gen (image generation unavailable — check the provider selection and its key or SDK with 'hermes tools')",
  '  ⚠ video (system dependency not met)',
  '  ⚠ video_gen (system dependency not met)',
  '  ⚠ vision (system dependency not met)',
  '  ⚠ x_search (missing XAI_API_KEY)',
  '',
  '◆ Skills Hub',
  '  ⚠ Skills Hub directory not initialized (run: hermes skills list)',
  '  ⚠ No GITHUB_TOKEN (60 req/hr rate limit — set in /srv/demo/hermes-home/.env for better rates)',
  '',
  '◆ Memory Provider',
  '  ✓ Built-in memory active (no external provider configured — this is fine)',
  '',
  '◆ NeMo Relay Plugins',
  '  ✓ No Relay plugin files found',
  '',
  '────────────────────────────────────────────────────────────',
  '  Found 4 issue(s) to address:',
  '',
  "  1. Run 'hermes setup' to create .env",
  "  2. Run 'hermes doctor --fix' or 'hermes setup' to migrate config",
  "  3. Missing ~/.local/bin/hermes symlink — run 'hermes doctor --fix'",
  "  4. Run 'hermes setup' to configure missing API keys for full tool access",
  '',
  "  Tip: run 'hermes doctor --fix' to auto-fix what's possible.",
  '',
];
