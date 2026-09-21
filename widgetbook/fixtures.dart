import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';

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
