import 'dart:convert';

import 'lenient_read.dart';

/// Names one agent of one chat on one connection. A selection or a
/// confirmation holds the key it started with, so a list that refreshes or
/// reorders never moves it to another agent.
final class AgentKey {
  const AgentKey({
    required this.threadId,
    required this.profile,
    required this.connection,
    required this.subagentId,
  });

  final String threadId;
  final String? profile;

  /// The token of the connection the agent was seen on (compared by
  /// identity).
  final Object connection;
  final String subagentId;

  @override
  bool operator ==(Object other) =>
      other is AgentKey &&
      threadId == other.threadId &&
      profile == other.profile &&
      identical(connection, other.connection) &&
      subagentId == other.subagentId;

  @override
  int get hashCode =>
      Object.hash(threadId, profile, identityHashCode(connection), subagentId);

  @override
  String toString() => 'AgentKey()';
}

enum AgentState {
  starting,
  running,
  finished,
  stopped,
  failed,

  /// A state the app does not know, or an agent that left the list without a
  /// completion: shown as Ended, never as Finished or Failed.
  ended;

  bool get active => this == starting || this == running;
}

/// One row of `subagent.list`.
final class ListedAgent {
  const ListedAgent({
    required this.id,
    required this.state,
    this.parentId,
    this.depth,
    this.goal,
    this.delegationId,
    this.model,
    this.startedAt,
    this.toolCount,
    this.lastTool,
    this.acceptingSteer,
  });

  final String id;
  final String? parentId;
  final int? depth;
  final String? goal;
  final String? delegationId;
  final String? model;

  /// From `started_at`, Unix seconds.
  final DateTime? startedAt;
  final AgentState state;
  final int? toolCount;
  final String? lastTool;
  final bool? acceptingSteer;

  @override
  String toString() => 'ListedAgent($state)';
}

/// A failed background delegation of `subagent.list`.
final class FailedDelegation {
  const FailedDelegation({
    required this.delegationId,
    required this.taskIndex,
    required this.state,
    this.goal,
    this.error,
    this.dispatchedAt,
    this.completedAt,
  });

  final String delegationId;
  final int taskIndex;
  final AgentState state;
  final String? goal;
  final String? error;
  final DateTime? dispatchedAt, completedAt;

  /// The key the roster dedupes against frame rows with.
  String get key => '$delegationId#$taskIndex';

  @override
  String toString() => 'FailedDelegation($state)';
}

final class AgentList {
  const AgentList(this.agents, this.delegations);
  final List<ListedAgent> agents;
  final List<FailedDelegation> delegations;

  @override
  String toString() =>
      'AgentList(agents: ${agents.length}, delegations: ${delegations.length})';
}

/// The most of an agent's output the app holds.
const kAgentTailBytes = 16 * 1024;

final class AgentTail {
  const AgentTail({
    required this.available,
    required this.text,
    required this.truncated,
  });

  final bool available;
  final String text;
  final bool truncated;

  @override
  String toString() => 'AgentTail(available: $available, ${text.length} chars)';
}

enum StopOutcome { stopped, alreadyEnded }

enum SteerOutcome { queued, rejected }

/// Hermes' notices for a note that never reached its agent. The success
/// path appends the first to the completion summary; the failure path
/// appends the second to a failed delegation's error.
const kMissedNoteInSummary =
    '[steer did not land — the subagent finished before it could be delivered';
const kMissedNoteInError = '[steer did not land before the subagent stopped';

/// Whether [summary] carries Hermes' full notice for a note that missed.
bool summaryShowsMissedNote(String? summary) =>
    summary?.contains(kMissedNoteInSummary) ?? false;

/// Whether [error] carries Hermes' full notice for a note that missed.
bool errorShowsMissedNote(String? error) =>
    error?.contains(kMissedNoteInError) ?? false;

AgentState _stateOf(Object? status, AgentState fallback) {
  if (status == null) return fallback;
  return switch (status) {
    'queued' => AgentState.starting,
    'running' => AgentState.running,
    'completed' => AgentState.finished,
    'interrupted' => AgentState.stopped,
    'failed' || 'error' || 'timeout' => AgentState.failed,
    _ => AgentState.ended,
  };
}

/// Reads a `subagent.list` answer; null when its rows are not a list.
/// Rows without an id are skipped, and a row that is not a map is too.
AgentList? parseAgentList(Map<String, Object?> result) {
  final rows = result['subagents'], delegations = result['delegations'];
  // An answer without its agents is not an empty list: reading it as one
  // would end every running row.
  if (rows is! List) return null;
  if (delegations != null && delegations is! List) return null;
  final agents = <ListedAgent>[];
  for (final row in rows as List? ?? const []) {
    if (row is! Map) continue;
    final id = readString(row['subagent_id']);
    if (id == null) continue;
    agents.add(
      ListedAgent(
        id: id,
        parentId: readString(row['parent_id']),
        depth: readInt(row['depth']),
        goal: readString(row['goal']),
        delegationId: readString(row['delegation_id']),
        model: readString(row['model']),
        startedAt: readSeconds(row['started_at']),
        // A listed agent without a status is a live one; the list holds only
        // those and the failed delegations.
        state: _stateOf(row['status'], AgentState.running),
        toolCount: readInt(row['tool_count']),
        lastTool: readString(row['last_tool']),
        acceptingSteer: readBool(row['accepting_steer']),
      ),
    );
  }
  final failed = <FailedDelegation>[];
  for (final row in delegations as List? ?? const []) {
    if (row is! Map) continue;
    final id = readString(row['delegation_id']);
    final index = readInt(row['task_index']);
    if (id == null || index == null) continue;
    failed.add(
      FailedDelegation(
        delegationId: id,
        taskIndex: index,
        state: _stateOf(row['status'], AgentState.failed),
        goal: readString(row['goal']),
        error: readString(row['error']),
        dispatchedAt: readSeconds(row['dispatched_at']),
        completedAt: readSeconds(row['completed_at']),
      ),
    );
  }
  return AgentList(List.unmodifiable(agents), List.unmodifiable(failed));
}

/// Reads a `subagent.tail` answer; null when it has no `available` flag or
/// its text is not a string. The text is cut to its last [kAgentTailBytes]
/// bytes at a character boundary, and when it was cut (here or by Hermes) its
/// partial first line is dropped.
AgentTail? parseAgentTail(Map<String, Object?> result) {
  final available = readBool(result['available']);
  final text = result['text'];
  if (available == null || (text != null && text is! String)) return null;
  var shown = text as String? ?? '';
  var truncated = readBool(result['truncated']) ?? false;
  final bytes = utf8.encode(shown);
  if (bytes.length > kAgentTailBytes) {
    var start = bytes.length - kAgentTailBytes;
    // A continuation byte (10xxxxxx) belongs to a character that began before.
    while (start < bytes.length && (bytes[start] & 0xC0) == 0x80) {
      start++;
    }
    shown = utf8.decode(bytes.sublist(start), allowMalformed: true);
    truncated = true;
  }
  if (truncated && shown.isNotEmpty) {
    final newline = shown.indexOf('\n');
    shown = newline < 0 ? '' : shown.substring(newline + 1);
  }
  return AgentTail(available: available, text: shown, truncated: truncated);
}

/// Reads a `subagent.interrupt` answer; null when `found` is not a bool.
StopOutcome? parseStopOutcome(Map<String, Object?> result) =>
    switch (readBool(result['found'])) {
      true => StopOutcome.stopped,
      false => StopOutcome.alreadyEnded,
      null => null,
    };

/// Reads a `subagent.steer` answer; null for any status but the two known.
SteerOutcome? parseSteerOutcome(Map<String, Object?> result) =>
    switch (result['status']) {
      'queued' => SteerOutcome.queued,
      'rejected' => SteerOutcome.rejected,
      _ => null,
    };

/// The longest note the app sends, counted on the trimmed text. Hermes sets
/// no limit of its own.
const kMaxNoteLength = 4000;
