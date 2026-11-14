/// Answers of `process.list` and `process.kill`.
///
/// The `recorded*` constants are answers recorded from a throwaway Hermes at
/// revision `d923a5eb` (a background `terminal` call on a loopback scripted
/// model; paths, ids and timestamps are invented, shapes and values are as
/// recorded). The older constants below them are built from design.md's
/// shapes and the openrpc schemas and stay for the tests that use them;
/// they differ from the recording in `termination_source` (the real value
/// is `process.kill`), in `killAlreadyExited` (the real answer for a program
/// an earlier kill stopped keeps `completion_reason: killed` and its negative
/// code) and in the row fields `owner_task_id`, `started_at` (an ISO string)
/// and `cwd`, which the app ignores. `killNotFound` and `killError` were not
/// reproduced: the gateway answers an unknown id with 4044 before the
/// registry could report `not_found`.
library;

/// A running program, as design.md's row example.
const Map<String, Object?> runningRow = {
  'session_id': 'proc_ab12',
  'command': 'npm test',
  'cwd': '/repo',
  'pid': 4242,
  'status': 'running',
  'uptime_seconds': 42,
  'output_preview': '…',
  'output_tail': 'PASS src/a.test.js\n',
  'exit_code': null,
};

/// A program stopped by `process.kill`: `exited`, `completion_reason:
/// killed` and the negative signal code (process_registry 2243-2253).
const Map<String, Object?> killedRow = {
  'session_id': 'proc_k1',
  'command': 'npm run dev',
  'cwd': '/repo',
  'pid': 4300,
  'status': 'exited',
  'uptime_seconds': 310,
  'output_preview': '',
  'output_tail': 'ready on :3000\n',
  'exit_code': -15,
  'exited_at': 1763120310.25,
  'completion_reason': 'killed',
};

/// A program that exited on its own with a code.
const Map<String, Object?> exitedRow = {
  'session_id': 'proc_e1',
  'command': 'make build',
  'status': 'exited',
  'uptime_seconds': 12,
  'output_tail': 'error: missing file\n',
  'exit_code': 2,
  'exited_at': 1763120020,
};

/// `process.list {session_id}` with the three rows.
const Map<String, Object?> processListAnswer = {
  'processes': [runningRow, killedRow, exitedRow],
};

/// `process.kill` answers, one per `ProcessKillStatus`.
const Map<String, Object?> killKilled = {
  'status': 'killed',
  'session_id': 'proc_ab12',
  'command': 'npm test',
  'exit_code': -15,
  'completion_reason': 'killed',
  'termination_source': 'user',
  'output': 'PASS src/a.test.js\n',
};

const Map<String, Object?> killAlreadyExited = {
  'status': 'already_exited',
  'session_id': 'proc_ab12',
  'command': 'npm test',
  'exit_code': 0,
  'completion_reason': 'exited',
  'output': 'done\n',
};

const Map<String, Object?> killNotFound = {
  'status': 'not_found',
  'error': 'no such process',
};

const Map<String, Object?> killError = {
  'status': 'error',
  'session_id': 'proc_ab12',
  'error': 'permission denied',
};

/// Error codes the methods answer with (design.md).
const kNoSuchProcess = 4044;
const kSessionNotOwned = 4001;
const kAgentStillStarting = 5032;
const kListBodyError = 5010;

// ---- Recorded at Hermes d923a5eb ---------------------------------------

/// `process.list` with one running program.
const Map<String, Object?> recordedListRunning = {
  'processes': [
    {
      'session_id': 'proc_0a1b2c3d4e5f',
      'command': 'echo ready on demo port; sleep 300',
      'cwd': '/srv/demo/work',
      'pid': 4242,
      'owner_task_id': '20251114_120000_a1b2c3',
      'started_at': '2025-11-14T12:00:00',
      'uptime_seconds': 2,
      'status': 'running',
      'output_preview': 'ready on demo port\n',
      'output_tail': 'ready on demo port\n',
    },
  ],
};

/// `process.kill` of that program: `killed`, with the completion-sized tail.
const Map<String, Object?> recordedKillKilled = {
  'status': 'killed',
  'session_id': 'proc_0a1b2c3d4e5f',
  'completion_reason': 'killed',
  'termination_source': 'process.kill',
  'output': 'ready on demo port\n',
};

/// `process.list` after the kill: the program is `exited`, `completion_reason`
/// `killed`, with the negative signal code (`status` has no `killed` word).
const Map<String, Object?> recordedListKilled = {
  'processes': [
    {
      'session_id': 'proc_0a1b2c3d4e5f',
      'command': 'echo ready on demo port; sleep 300',
      'cwd': '/srv/demo/work',
      'pid': 4242,
      'owner_task_id': '20251114_120000_a1b2c3',
      'started_at': '2025-11-14T12:00:00',
      'uptime_seconds': 3,
      'status': 'exited',
      'output_preview': 'ready on demo port\n',
      'exit_code': -15,
      'exited_at': 1763121601.9234262,
      'completion_reason': 'killed',
      'output_tail': 'ready on demo port\n',
    },
  ],
};

/// `process.kill` of a program that already ended (here, one an earlier kill
/// stopped): `already_exited` with its code, reason and last output.
const Map<String, Object?> recordedKillAlreadyExited = {
  'status': 'already_exited',
  'command': 'echo ready on demo port; sleep 300',
  'exit_code': -15,
  'completion_reason': 'killed',
  'termination_source': 'process.kill',
  'output': 'ready on demo port\n',
};

/// JSON-RPC `error` answers, `{code, message}`.
const Map<String, Object?> recordedErrorNoSuchProcess = {
  'code': 4044,
  'message': 'no such process: proc_000000000000',
};
const Map<String, Object?> recordedErrorNoProcessId = {
  'code': 4012,
  'message': 'process_id required',
};
const Map<String, Object?> recordedErrorUnknownSession = {
  'code': 4001,
  'message': 'session not found',
};

/// `process.list` and `process.kill` of a session whose agent could not be
/// built (a profile with an unknown provider): 5032 at once, not after a
/// 30 s wait. Hermes' message carries the configuration error text; this one
/// is a placeholder.
const Map<String, Object?> recordedErrorAgentFailed = {
  'code': 5032,
  'message': 'agent initialization failed',
};

/// A method the server does not have (an older Hermes without
/// `process.kill`): JSON-RPC -32601. Recorded for an unknown method name; the
/// text names `process.kill` here.
const Map<String, Object?> recordedErrorMethodNotFound = {
  'code': -32601,
  'message':
      'unknown method: process.kill — the client and the Hermes backend are '
      'out of sync (different versions); run `hermes update` and restart both',
};
