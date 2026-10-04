import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/mcp/mcp_command_review_items.dart';
import 'package:hermes_app/src/models/auxiliary_models.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/models/moa_setup.dart';
import 'package:hermes_app/src/plugins/catalog_entry.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';

const runningToolCall = ToolCall(
  name: 'terminal',
  summary: '{"command":"flutter test"}',
  status: ToolCallStatus.running,
);

const finishedToolCall = ToolCall(
  name: 'read_file',
  summary: 'lib/main.dart',
  args: {'path': 'lib/main.dart'},
  result: 'void main() {\n  runApp(const App());\n}',
  reasoning: 'Check how the app starts before changing it.',
  duration: Duration(milliseconds: 420),
);

/// A call that has been running for [seconds], for the live elapsed time.
ToolCall timedToolCall({int seconds = 12}) => ToolCall(
  name: 'terminal',
  summary: 'flutter test',
  args: const {'command': 'flutter test'},
  status: ToolCallStatus.running,
  startedAt: DateTime.now().subtract(Duration(seconds: seconds)),
);

const preparingToolCall = ToolCall(
  name: 'terminal',
  summary: '',
  status: ToolCallStatus.running,
  preparing: true,
);

const cancelledToolCall = ToolCall(
  name: 'terminal',
  summary: 'restic backup /srv',
  status: ToolCallStatus.cancelled,
  duration: Duration(seconds: 74),
);

const approvalToolCall = ToolCall(
  name: 'terminal',
  summary: 'rm -rf build',
  args: {'command': 'rm -rf build'},
  status: ToolCallStatus.running,
);

const terminalToolCall = ToolCall(
  name: 'terminal',
  summary: 'systemctl status backup',
  status: ToolCallStatus.error,
  args: {'command': 'systemctl status backup'},
  result:
      'backup.service - Nightly backup\n   Active: failed (Result: exit-code)',
  resultData: {
    'output': 'backup.service - Nightly backup\n   Active: failed (Result: exit-code)',
    'exit_code': 3,
    'error': null,
  },
  duration: Duration(milliseconds: 180),
);

const webSearchToolCall = ToolCall(
  name: 'web_search',
  summary: 'restic connection reset by peer',
  args: {'query': 'restic connection reset by peer'},
  resultData: {
    'success': true,
    'data': {
      'web': [
        {
          'title': 'Backups fail with "connection reset by peer"',
          'url': 'https://forum.restic.net/t/connection-reset/4512',
          'description':
              'Raising the backend timeout and limiting connections fixed it.',
        },
        {
          'title': 'Tuning restic for flaky links',
          'url': 'https://restic.readthedocs.io/en/stable/tuning.html',
          'description': 'Options for retries, connections and pack size.',
        },
      ],
    },
  },
  duration: Duration(milliseconds: 2300),
);

const todoToolCall = ToolCall(
  name: 'todo_list',
  summary: '',
  resultData: {
    'todos': [
      {'id': '1', 'content': 'Read the backup logs', 'status': 'completed'},
      {'id': '2', 'content': 'Raise the retry cap', 'status': 'in_progress'},
      {'id': '3', 'content': 'Open a PR', 'status': 'pending'},
      {'id': '4', 'content': 'Page the on-call', 'status': 'cancelled'},
    ],
  },
);

const diffToolCall = ToolCall(
  name: 'patch',
  summary: '/etc/backup.timer',
  args: {'path': '/etc/backup.timer'},
  diff:
      'a/etc/backup.timer → b/etc/backup.timer\n'
      '@@ -3,3 +3,3 @@\n'
      ' [Timer]\n'
      '-OnCalendar=*-*-* 02:00\n'
      '+OnCalendar=*-*-* 03:30\n'
      ' Persistent=true',
  duration: Duration(milliseconds: 90),
);

const failedToolCall = ToolCall(
  name: 'web_search',
  summary: '{"query":"flutter widgetbook"}',
  status: ToolCallStatus.error,
  result: 'Request timed out after 30 s',
);

const finishedToolRun = [
  ToolCall(name: 'terminal', summary: '{"command":"journalctl -u backup"}'),
  ToolCall(name: 'read_file', summary: '{"path":"/etc/backup.timer"}'),
  ToolCall(name: 'edit_file', summary: '{"path":"/etc/backup.timer"}'),
];

const runningToolRun = [
  ToolCall(name: 'terminal', summary: '{"command":"journalctl -u backup"}'),
  ToolCall(
    name: 'read_file',
    summary: '{"path":"/etc/backup.timer"}',
    status: ToolCallStatus.running,
  ),
];

const waitingToolRun = [
  ToolCall(name: 'read_file', summary: 'Makefile'),
  approvalToolCall,
];

const cancelledToolRun = [
  ToolCall(
    name: 'terminal',
    summary: 'ping nas-02',
    status: ToolCallStatus.cancelled,
  ),
  ToolCall(name: 'restic_run', summary: '', status: ToolCallStatus.cancelled),
];

const failedToolRun = [
  ToolCall(name: 'terminal', summary: '{"command":"ping nas-02"}'),
  ToolCall(
    name: 'restic_run',
    summary: '',
    status: ToolCallStatus.error,
    result: 'connection reset by peer',
  ),
];

const runningSubagent = Subagent(
  id: 'agent-1',
  goal: 'Add failing tests, then fix the retry double-call',
  status: SubagentStatus.running,
);

/// A child that has been running for [seconds], for the live elapsed time.
Subagent timedSubagent({int seconds = 65}) => Subagent(
  id: 'agent-1',
  goal: 'Add failing tests, then fix the retry double-call',
  status: SubagentStatus.running,
  lastTool: 'terminal',
  lastToolPreview: 'pytest tests/ingest -x',
  startedAt: DateTime.now().subtract(Duration(seconds: seconds)),
);

const completedSubagent = Subagent(
  id: 'agent-1',
  goal: 'Add failing tests, then fix the retry double-call',
  status: SubagentStatus.completed,
  summary:
      'Guard added so an already-scheduled timer is not re-armed; 44 passed.',
  duration: Duration(seconds: 123),
  toolCount: 6,
);

const failedSubagent = Subagent(
  id: 'agent-3',
  goal: 'Micro-bench the ingest hot path',
  status: SubagentStatus.failed,
  summary: 'pytest-benchmark is not installed; no numbers collected.',
  duration: Duration(seconds: 41),
  toolCount: 2,
);

/// A parallel batch: two finished children and one nested child of a child.
const subagentBatch = [
  Subagent(
    id: 'agent-1',
    goal: 'Review the PR #412 diff',
    status: SubagentStatus.completed,
    summary: 'Two comments, both about the retry guard naming.',
    duration: Duration(seconds: 118),
    toolCount: 9,
    index: 0,
    count: 3,
  ),
  Subagent(
    id: 'agent-2',
    goal: 'Update the CHANGELOG and docstrings',
    status: SubagentStatus.completed,
    summary: 'CHANGELOG entry added; three docstrings rewritten.',
    duration: Duration(seconds: 127),
    toolCount: 5,
    index: 1,
    count: 3,
  ),
  Subagent(
    id: 'agent-4',
    goal: 'Verify the docstring examples compile',
    parentId: 'agent-2',
    depth: 1,
    index: 0,
    count: 1,
    status: SubagentStatus.running,
  ),
];

const pendingApproval = ApprovalRequest(
  requestId: 'approval-1',
  command: 'rm -rf build',
  description: 'Delete the build folder',
  choices: ['once', 'session', 'always', 'deny'],
);

final answeredApproval = pendingApproval.answered('once');

final expiredApproval = pendingApproval.withStatus(InputRequestStatus.expired);

const singleChoiceClarify = ClarifyRequest(
  requestId: 'clarify-1',
  questions: [
    ClarifyQuestion(
      qid: '',
      question: 'Which environment should I deploy to?',
      choices: ['Staging', 'Production'],
    ),
  ],
);

const openClarify = ClarifyRequest(
  requestId: 'clarify-2',
  questions: [
    ClarifyQuestion(qid: '', question: 'What should I name the tag?'),
  ],
);

const batchClarify = ClarifyRequest(
  requestId: 'clarify-3',
  batch: true,
  questions: [
    ClarifyQuestion(
      qid: 'targets',
      question: 'Which platforms?',
      choices: ['iOS', 'Android', 'macOS'],
      multiSelect: true,
    ),
    ClarifyQuestion(qid: 'notes', question: 'Anything to add to the notes?'),
  ],
);

final answeredClarify = singleChoiceClarify.answeredWith({
  '': ['Staging'],
});

const plainTask = KanbanTask(
  id: 't_1a2b3c',
  title: 'Write the release notes',
  status: 'todo',
);

const busyTask = KanbanTask(
  id: 't_4d5e6f',
  title: 'Migrate the settings screen to the new layout',
  status: 'running',
  assignee: 'researcher',
  priority: 2,
  tenant: 'mobile',
  commentCount: 3,
  progressDone: 2,
  progressTotal: 5,
  warningCount: 1,
  warningSeverity: 'medium',
);

final _now = DateTime.now();

const secretRequest = UnsupportedRequest(
  requestId: 'unsupported-1',
  kind: UnsupportedKind.secret,
);

final skippedSecretRequest = secretRequest.withStatus(
  InputRequestStatus.answered,
);

final expiredSecretRequest = secretRequest.withStatus(
  InputRequestStatus.expired,
);

const sudoRequest = UnsupportedRequest(
  requestId: 'unsupported-2',
  kind: UnsupportedKind.sudo,
);

const reasoningText =
    'The user wants the build folder gone. It is generated output, so '
    'deleting it is safe, but I should ask before running rm.';

final nightlyJob = CronJob(
  id: 'job-1',
  name: 'Nightly backup summary',
  scheduleKind: 'cron',
  scheduleExpr: '0 3 * * *',
  nextRunAt: _now.add(const Duration(hours: 9)),
  lastRunAt: _now.subtract(const Duration(hours: 15)),
  lastStatus: 'ok',
  deliver: 'telegram',
);

final failingJob = CronJob(
  id: 'job-2',
  name: 'Check the status page',
  scheduleKind: 'interval',
  scheduleMinutes: 30,
  nextRunAt: _now.add(const Duration(minutes: 12)),
  lastRunAt: _now.subtract(const Duration(minutes: 18)),
  lastStatus: 'error',
  lastError: 'Request timed out',
  profile: 'work',
);

final blockedJob = CronJob(
  id: 'job-5',
  name: 'Morning inbox digest',
  scheduleKind: 'cron',
  scheduleExpr: '0 7 * * *',
  nextRunAt: _now.add(const Duration(hours: 19)),
  lastRunAt: _now.subtract(const Duration(hours: 5)),
  lastStatus: 'blocked_config',
  lastError:
      "attached skill 'mail-tools' is not ready: "
      'missing credential file mail_token.json',
  skills: ['mail-tools'],
);

final pausedJob = CronJob(
  id: 'job-3',
  name: 'Weekly digest',
  scheduleKind: 'cron',
  scheduleExpr: '0 9 * * 1',
  state: CronJobState.paused,
);

final neverRunJob = CronJob(
  id: 'job-4',
  name: '',
  prompt: 'Remind me to water the plants',
  scheduleKind: 'interval',
  scheduleMinutes: 1440,
  nextRunAt: _now.add(const Duration(hours: 20)),
);

const catalogEntry = CatalogEntry(
  name: 'browser-tools',
  description: 'Drive a headless browser: open pages, click, read the result.',
  maintainer: 'Nous Research',
  tier: CatalogTier.official,
  requiresHermes: '>=0.20',
  platforms: ['macos', 'linux'],
  docsUrl: 'https://example.com/browser-tools',
  commit: 'a1b2c3d',
  providesTools: ['browser_open', 'browser_click', 'browser_read'],
  providesHooks: ['on_session_end'],
  requiresEnv: ['BROWSER_PATH'],
);

const installedCatalogEntry = CatalogEntry(
  name: 'notes-sync',
  description: 'Keeps a folder of notes in step with the agent memory.',
  maintainer: 'A community author',
  commit: '9f8e7d6',
  installed: true,
  updateAvailable: true,
  providesTools: ['notes_search'],
);

const pdfAttachment = ChatAttachment(
  name: 'quarterly-report.pdf',
  kind: AttachmentKind.file,
  remotePath: '/home/hermes/uploads/quarterly-report.pdf',
  size: 482113,
);

const relativeAttachment = ChatAttachment(
  name: 'notes.txt',
  kind: AttachmentKind.file,
  remotePath: 'attachments/notes.txt',
);

const npxServer = McpCommandReviewItem(
  name: 'filesystem',
  command: 'npx',
  args: ['-y', '@modelcontextprotocol/server-filesystem', '/srv/projects'],
);

const envServer = McpCommandReviewItem(
  name: 'search',
  command: '/usr/local/bin/search-mcp',
  args: ['--port', '0'],
  cwd: '/srv/tools',
  envNames: ['SEARCH_API_KEY', 'SEARCH_REGION'],
);

const modelOptions = ModelOptions(
  current: ModelChoice('anthropic', 'claude-opus-4'),
  providers: [
    ModelProviderOption(
      id: 'anthropic',
      label: 'Anthropic',
      models: [
        ModelOption(id: 'claude-opus-4', canDisableReasoning: true),
        ModelOption(id: 'claude-sonnet-4-5', canDisableReasoning: true),
        ModelOption(id: 'claude-haiku-4-5', reasoning: false),
      ],
    ),
    ModelProviderOption(
      id: 'openrouter',
      label: 'OpenRouter',
      models: [
        ModelOption(id: 'openai/gpt-5.1'),
        ModelOption(
          id: 'meta-llama/llama-4-maverick-17b-128e-instruct-long-context',
          reasoning: false,
        ),
      ],
    ),
  ],
);

const helperModels = AuxiliaryModels(
  main: ModelChoice('anthropic', 'claude-opus-4'),
  slots: [
    AuxiliarySlot(
      task: 'vision',
      choice: ModelChoice('anthropic', 'claude-haiku-4-5'),
    ),
    AuxiliarySlot(task: 'compression'),
    AuxiliarySlot(task: 'skills_hub'),
    AuxiliarySlot(task: 'approval'),
    AuxiliarySlot(task: 'mcp'),
    AuxiliarySlot(
      task: 'title_generation',
      choice: ModelChoice(
        'openrouter',
        'meta-llama/llama-4-maverick-17b-128e-instruct-long-context',
      ),
    ),
    AuxiliarySlot(
      task: 'review',
      choice: ModelChoice('anthropic', 'claude-sonnet-4-5', effort: 'high'),
    ),
    AuxiliarySlot(task: 'triage_specifier'),
    AuxiliarySlot(task: 'kanban_decomposer'),
    AuxiliarySlot(task: 'profile_describer'),
    AuxiliarySlot(task: 'curator', choice: ModelChoice('openrouter', '')),
  ],
);

/// A mixture of agents whose default preset is [preset], as Hermes reports it.
MoaSetup helperMoa({
  String preset = 'default',
  bool advisorOff = false,
  bool privacyFilter = false,
}) => MoaSetup.fromJson({
  if (privacyFilter) 'privacy_filter': 'display',
  'default_preset': preset,
  'active_preset': '',
  'presets': {
    preset: {
      'reference_models': [
        {'provider': 'anthropic', 'model': 'claude-sonnet-4-5'},
        {
          'provider': 'openrouter',
          'model': 'openai/gpt-5.1',
          'reasoning_effort': 'high',
          'enabled': !advisorOff,
        },
      ],
      'aggregator': {'provider': 'anthropic', 'model': 'claude-opus-4'},
    },
  },
})!;

/// The Kanban plugin's list: configured providers only, no capabilities and
/// no current model.
const kanbanModelOptions = ModelOptions(
  providers: [
    ModelProviderOption(
      id: 'anthropic',
      label: 'Anthropic',
      models: [
        ModelOption(id: 'claude-opus-4'),
        ModelOption(id: 'claude-haiku-4-5'),
      ],
    ),
    ModelProviderOption(
      id: 'openrouter',
      label: 'OpenRouter',
      models: [ModelOption(id: 'openai/gpt-5.1')],
    ),
  ],
);

final threads = [
  ChatThread(
    id: 'thread-1',
    title: 'Plan the release',
    updatedAt: _now.subtract(const Duration(minutes: 4)),
    remote: true,
    pinned: true,
    messages: [
      ChatMessage(
        id: 'm1',
        role: ChatRole.assistant,
        content: 'The changelog is ready for review.',
        createdAt: _now,
      ),
    ],
  ),
  ChatThread(
    id: 'thread-2',
    title: 'Fix the flaky login test',
    updatedAt: _now.subtract(const Duration(hours: 3)),
    remote: true,
    messages: [
      ChatMessage(
        id: 'm2',
        role: ChatRole.assistant,
        content: 'Looking at it now',
        createdAt: _now,
        status: MessageStatus.streaming,
      ),
    ],
  ),
  ChatThread(
    id: 'thread-3',
    title: 'Summarise the weekly report',
    updatedAt: _now.subtract(const Duration(days: 2)),
  ),
];

/// Hits of an all-profiles search: one from another profile.
final allProfileHits = [
  ...searchHits,
  ThreadSearchHit(
    id: 'thread-work',
    title: 'Office NAS',
    snippet: const [
      (text: 'Rotate the ', match: false),
      (text: 'backup', match: true),
      (text: ' drives every Friday.', match: false),
    ],
    updatedAt: _now.subtract(const Duration(days: 1)),
    profile: 'work',
  ),
];

/// Threads for every section of the Mac sidebar.
final macThreads = [
  ...threads,
  ChatThread(
    id: 'thread-4',
    title: 'Compare the backup providers for the photo library',
    updatedAt: _now.subtract(const Duration(days: 12)),
    remote: true,
  ),
  ChatThread(
    id: 'thread-5',
    title: 'Draft the onboarding email',
    updatedAt: _now.subtract(const Duration(days: 75)),
    remote: true,
  ),
];

final searchHits = [
  ThreadSearchHit(
    id: 'thread-2',
    title: 'Fix the flaky login test',
    snippet: const [
      (text: '…the ', match: false),
      (text: 'backup', match: true),
      (
        text: ' job ran while the login test seeded its users, so the ',
        match: false,
      ),
      (text: 'backup', match: true),
      (text: ' lock timed out…', match: false),
    ],
    updatedAt: _now.subtract(const Duration(hours: 3)),
  ),
  ThreadSearchHit(
    id: 'thread-old',
    title: 'Nightly backup to the NAS',
    snippet: const [
      (text: 'Set up a nightly ', match: false),
      (text: 'backup', match: true),
      (text: ' of the notes folder.', match: false),
    ],
    updatedAt: _now.subtract(const Duration(days: 40)),
  ),
  ThreadSearchHit(
    id: 'thread-id',
    title: 'Untitled chat',
    snippet: const [(text: 'Session ID: 20260930_backup', match: false)],
    updatedAt: _now.subtract(const Duration(days: 3)),
  ),
];

final deliveryFailedJob = CronJob(
  id: 'job-6',
  name: 'Send the weekly report',
  prompt: 'Summarise this week and send it to the team channel',
  scheduleKind: 'cron',
  scheduleExpr: '0 17 * * 5',
  nextRunAt: _now.add(const Duration(days: 3)),
  lastRunAt: _now.subtract(const Duration(days: 4)),
  lastStatus: 'delivery_failed',
  lastDeliveryError: 'Telegram answered 403: bot was blocked by the user',
  deliver: 'telegram',
  profile: 'home',
);

final cronRuns = [
  for (final (hours, minutes) in [(2, 3), (26, 2), (50, 4)])
    CronRun(
      sessionId: 'run-$hours',
      startedAt: _now.subtract(Duration(hours: hours)),
      endedAt: _now.subtract(Duration(hours: hours, minutes: -minutes)),
    ),
  CronRun(
    sessionId: 'run-unfinished',
    startedAt: _now.subtract(const Duration(hours: 74)),
  ),
];
