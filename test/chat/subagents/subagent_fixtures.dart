/// Answers of `subagent.list`, `subagent.tail`, `subagent.interrupt` and
/// `subagent.steer`, and the `subagent.complete` frames, recorded from a
/// throwaway Hermes at revision `d923a5eb` (`openrpc/HERMES_REF`).
///
/// The parent's first turn answered with a `delegate_task` call holding two
/// goals (or one), and each child ran `terminal` `sleep 30` before it
/// answered, all on a loopback scripted model, so no paid provider was used.
/// Hostnames, ids, paths, timestamps and model names are invented; the shapes,
/// field names, field order and values (`depth: 0`, `parent_id: null`,
/// statuses, codes, notice texts) are as recorded.
///
/// What the recording showed beyond design.md's first reading:
/// - `depth` is 0 for a child of the chat (design.md's example said 1).
/// - A delegation holds the parent's turn only until it is dispatched: the
///   parent's turn completed while both children still ran, so the children
///   are async and their result reaches the chat later.
/// - `subagent.list` also lists an interrupted child under `delegations`
///   (status `interrupted`, `error: null`), not only failed ones.
/// - `subagent.steer` from a connection that never resumed the session
///   answers `rejected`, not 4001; list, tail and interrupt answer 4001.
/// - A note queued after the child's last tool batch is reported in the
///   completion frame's `summary` with the success-path notice, also when the
///   child then failed with a provider error. The failure-path notice
///   (`before the subagent stopped`) was not reproduced.
library;

/// The Hermes revision the answers were recorded at.
const kSubagentFixturesRevision = 'd923a5eb';

/// Child ids as Hermes mints them: `sa-<task index>-<8 hex>`.
const kAgentApples = 'sa-0-a1b2c3d4';
const kAgentPears = 'sa-1-e5f6a7b8';
const kDelegationId = 'deleg_0a1b2c3d';

const Map<String, Object?> _apples = {
  'subagent_id': kAgentApples,
  'parent_id': null,
  'depth': 0,
  'goal': 'Count the apples in the demo crate',
  'delegation_id': kDelegationId,
  'model': 'scripted',
  'started_at': 1763120000.4264932,
  'status': 'running',
  'tool_count': 1,
  'last_tool': 'terminal',
  'accepting_steer': true,
};

const Map<String, Object?> _pears = {
  'subagent_id': kAgentPears,
  'parent_id': null,
  'depth': 0,
  'goal': 'Count the pears in the demo crate',
  'delegation_id': kDelegationId,
  'model': 'scripted',
  'started_at': 1763120000.42706,
  'status': 'running',
  'tool_count': 1,
  'last_tool': 'terminal',
  'accepting_steer': true,
};

/// `subagent.list` while both children run their `sleep 30`.
const Map<String, Object?> listRunning = {
  'subagents': [_apples, _pears],
  'delegations': <Object?>[],
};

/// `subagent.list` after the pears child was interrupted: it is gone from
/// `subagents` (an ended agent's record is dropped at once).
const Map<String, Object?> listAfterInterrupt = {
  'subagents': [_apples],
  'delegations': <Object?>[],
};

/// `subagent.list` once the interrupted child's delegation was recorded:
/// the interrupted task is a `delegations` row with no error.
const Map<String, Object?> listInterruptedDelegation = {
  'subagents': <Object?>[],
  'delegations': [
    {
      'delegation_id': kDelegationId,
      'task_index': 1,
      'status': 'interrupted',
      'goal': 'Count the pears in the demo crate',
      'error': null,
      'dispatched_at': 1763120000.458547,
      'completed_at': 1763120037.1224678,
    },
  ],
};

/// `subagent.list` after a child failed with a provider error.
const Map<String, Object?> listFailedDelegation = {
  'subagents': <Object?>[],
  'delegations': [
    {
      'delegation_id': 'deleg_4d5e6f70',
      'task_index': 0,
      'status': 'failed',
      'goal': 'Fail on purpose and report',
      'error': 'HTTP 400: model request rejected',
      'dispatched_at': 1763120130.9557052,
      'completed_at': 1763120167.561954,
    },
  ],
};

/// `subagent.list` of a session with no agents and no failed delegations.
const Map<String, Object?> listEmpty = {
  'subagents': <Object?>[],
  'delegations': <Object?>[],
};

/// `subagent.tail` while the child runs: the header and the lines so far.
const Map<String, Object?> tailRunning = {
  'subagent_id': kAgentApples,
  'available': true,
  'text':
      '=== Hermes subagent live transcript ===\n'
      'delegation: $kDelegationId   task: 0\n'
      'goal: Count the apples in the demo crate\n'
      'started: 2025-11-14 12:00:00\n'
      '(append-only; streams while the subagent runs — tail -f me)\n'
      '========================================\n'
      '12:00:00 user     | kickoff: Count the apples in the demo crate\n'
      '12:00:00 start    | Count the apples in the demo crate\n'
      '12:00:00 tool     | -> terminal(sleep 30)\n',
  'truncated': false,
};

/// `subagent.tail` once the tool batch ended: a `result` line follows.
const Map<String, Object?> tailAfterToolBatch = {
  'subagent_id': 'sa-0-9c8d7e6f',
  'available': true,
  'text':
      '=== Hermes subagent live transcript ===\n'
      'delegation: deleg_5e6f7a8b   task: 0\n'
      'goal: Count the quinces\n'
      'started: 2025-11-14 12:10:00\n'
      '(append-only; streams while the subagent runs — tail -f me)\n'
      '========================================\n'
      '12:10:00 user     | kickoff: Count the quinces\n'
      '12:10:00 start    | Count the quinces\n'
      '12:10:00 tool     | -> terminal(sleep 30)\n'
      '12:10:30 result   | terminal ok 30.1s: '
      '{"output": "", "exit_code": 0, "error": null}\n',
  'truncated': false,
};

/// `subagent.tail` after the child ended (its record is gone), for an
/// unknown id, and for a child this connection does not control.
const Map<String, Object?> tailUnavailable = {
  'subagent_id': kAgentPears,
  'available': false,
  'text': '',
  'truncated': false,
};

/// `subagent.tail` of a child that ran seventy quick tool calls: Hermes
/// returns the last 16,384 bytes (here all ASCII, so characters) and sets
/// `truncated`, so the text starts in the middle of a line.
Map<String, Object?> tailTruncatedAnswer() {
  final lines = StringBuffer();
  for (var n = 0; n < 70; n++) {
    lines
      ..write('12:20:00 tool     | -> terminal(echo line $n ${'x' * 200})\n')
      ..write(
        '12:20:00 result   | terminal ok 0.1s: '
        '{"output": "line $n ${'x' * 200}\\n", "exit_code": 0, "error": null}\n',
      );
  }
  final all = lines.toString();
  return {
    'subagent_id': 'sa-0-0b1c2d3e',
    'available': true,
    'text': all.substring(all.length - 16384),
    'truncated': true,
  };
}

/// `subagent.interrupt` of a running child, and of an unknown or ended one.
const Map<String, Object?> interruptFound = {
  'found': true,
  'subagent_id': kAgentPears,
};
const Map<String, Object?> interruptNotFound = {
  'found': false,
  'subagent_id': kAgentPears,
};

/// `subagent.steer` of a running child, and of an unknown or ended one, and
/// from a connection that never resumed the session.
const Map<String, Object?> steerQueued = {
  'status': 'queued',
  'subagent_id': kAgentApples,
  'text': 'Use the small crate.',
};
const Map<String, Object?> steerRejected = {
  'status': 'rejected',
  'subagent_id': kAgentPears,
  'text': 'late',
};

/// Error answers: `{code, message}` as `error` of the JSON-RPC response.
const Map<String, Object?> errorNotOwned = {
  'code': 4001,
  'message': 'session not found or not owned by this transport',
};
const Map<String, Object?> errorNoSubagentId = {
  'code': 4000,
  'message': 'subagent_id required',
};
const Map<String, Object?> errorBlankNote = {
  'code': 4002,
  'message': 'text is required',
};

/// The `subagent.complete` payload of a child that finished, with the
/// notice Hermes appends when a note queued after the last tool batch never
/// landed (the success-path form).
const Map<String, Object?> completeWithMissedNote = {
  'goal': 'Count the quinces',
  'task_count': 1,
  'task_index': 0,
  'subagent_id': 'sa-0-9c8d7e6f',
  'child_session_id': '20251114_121000_aaaaaa',
  'delegation_id': 'deleg_5e6f7a8b',
  'depth': 0,
  'model': 'scripted',
  'tool_count': 1,
  'toolsets': ['file', 'terminal', 'web'],
  'input_tokens': 20,
  'output_tokens': 20,
  'reasoning_tokens': 0,
  'api_calls': 2,
  'output_tail': [
    {
      'tool': 'terminal',
      'preview': '{"output": "", "exit_code": 0, "error": null}',
      'is_error': false,
    },
  ],
  'text':
      'Child finished its task.\n\n'
      '[steer did not land — the subagent finished before it could be '
      'delivered: Check the lid too.]',
  'status': 'completed',
  'summary':
      'Child finished its task.\n\n'
      '[steer did not land — the subagent finished before it could be '
      'delivered: Check the lid too.]',
  'duration_seconds': 36.33,
};

/// A child that finished normally (no note pending).
const Map<String, Object?> completeFinished = {
  'goal': 'Count the apples in the demo crate',
  'task_count': 2,
  'task_index': 0,
  'subagent_id': kAgentApples,
  'child_session_id': '20251114_120000_bbbbbb',
  'delegation_id': kDelegationId,
  'depth': 0,
  'model': 'scripted',
  'tool_count': 1,
  'toolsets': ['file', 'terminal', 'web'],
  'input_tokens': 20,
  'output_tokens': 20,
  'reasoning_tokens': 0,
  'api_calls': 2,
  'text': 'Child finished its task.',
  'status': 'completed',
  'summary': 'Child finished its task.',
  'duration_seconds': 36.4,
};

/// A child stopped by `subagent.interrupt`: `interrupted`, with no `summary`
/// and no `text` (the interrupted tool printed `[Command interrupted]`).
const Map<String, Object?> completeInterrupted = {
  'goal': 'Count the pears in the demo crate',
  'task_count': 2,
  'task_index': 1,
  'subagent_id': kAgentPears,
  'child_session_id': '20251114_120000_cccccc',
  'delegation_id': kDelegationId,
  'depth': 0,
  'model': 'scripted',
  'tool_count': 1,
  'toolsets': ['file', 'terminal', 'web'],
  'input_tokens': 10,
  'output_tokens': 10,
  'reasoning_tokens': 0,
  'api_calls': 1,
  'output_tail': [
    {
      'tool': 'terminal',
      'preview': '{"output": "[Command interrupted]", "exit_code": 130, "error": null}',
      'is_error': false,
    },
  ],
  'status': 'interrupted',
  'duration_seconds': 0.39,
};

/// A child that failed with a provider error after a note was queued: the
/// frame is `failed`, its `summary` holds the provider text and the
/// success-path notice, and the failed delegation's `error` (in
/// [listFailedDelegation]) holds only the provider text.
const Map<String, Object?> completeFailedWithMissedNote = {
  'goal': 'Fail on purpose and report',
  'task_count': 1,
  'task_index': 0,
  'subagent_id': 'sa-0-3a4b5c6d',
  'child_session_id': '20251114_121500_dddddd',
  'delegation_id': 'deleg_4d5e6f70',
  'depth': 0,
  'model': 'scripted',
  'tool_count': 1,
  'toolsets': ['file', 'terminal', 'web'],
  'input_tokens': 10,
  'output_tokens': 10,
  'reasoning_tokens': 0,
  'api_calls': 2,
  'text':
      'The model provider rejected this request, so the model did not answer.',
  'status': 'failed',
  'summary':
      'The model provider rejected this request, so the model did not '
      'answer.\n\nProvider said: HTTP 400: model request rejected\n\n'
      '[steer did not land — the subagent finished before it could be '
      'delivered: Check the lid too.]',
  'duration_seconds': 36.27,
};
