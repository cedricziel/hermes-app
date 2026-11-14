/// Answers of `process.list` and `process.kill`.
///
/// NOT recorded from a backend: `hermes` was not available where these were
/// written. They are built from the shapes design.md records under "Server
/// surface verified" (Hermes `d923a5eb`, read in `tui_gateway/methods_tools.py`,
/// `server.py` `_session_processes` and `tools/process_registry.py`) and from
/// the `ProcessEntry`, `ProcessListResult`, `ProcessKillResult` and
/// `ProcessKillStatus` schemas in `openrpc/hermes-gateway.openrpc.json`.
/// Task 6.1 still asks for answers recorded from `scripts/dev-backend.sh`.
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
