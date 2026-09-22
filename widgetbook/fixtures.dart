import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/mcp/mcp_command_review_items.dart';
import 'package:hermes_app/src/plugins/catalog_entry.dart';
import 'package:hermes_app/src/schedules/schedule_models.dart';

const runningToolCall = ToolCall(
  name: 'terminal',
  summary: '{"command":"flutter test"}',
  status: ToolCallStatus.running,
);

const finishedToolCall = ToolCall(
  name: 'read_file',
  summary: '{"path":"lib/main.dart"}',
  result: 'void main() {\n  runApp(const App());\n}',
  reasoning: 'Check how the app starts before changing it.',
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

const failedToolRun = [
  ToolCall(name: 'terminal', summary: '{"command":"ping nas-02"}'),
  ToolCall(
    name: 'restic_run',
    summary: '',
    status: ToolCallStatus.error,
    result: 'connection reset by peer',
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
