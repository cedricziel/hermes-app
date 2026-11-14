import 'package:flutter/foundation.dart';

import 'agent_models.dart';
import 'agent_work_result.dart';

/// What an open agent detail knows of its agent from the roster: the row as
/// frames and the list last showed it.
final class AgentView {
  const AgentView({
    required this.state,
    this.goal,
    this.startedAt,
    this.acceptingSteer,
    this.summary,
    this.error,
  });

  final AgentState state;
  final String? goal;
  final DateTime? startedAt;

  /// From the list; null when it never said.
  final bool? acceptingSteer;

  /// The completion summary, or the failed delegation's error.
  final String? summary, error;

  bool get active => state.active;

  @override
  String toString() => 'AgentView($state)';
}

/// What `SubagentDetailController` needs from the app around it, so it holds
/// no roster, connection or lifecycle of its own.
abstract interface class AgentDetailHost {
  /// Fires when the agent's view, the connection, the lock or visibility
  /// changed.
  Listenable get changes;

  /// The agent's row now; null when the roster no longer has it.
  AgentView? get view;

  /// Whether the app has a connection to Hermes.
  bool get online;

  /// Whether the app is in front, unlocked and showing this detail.
  bool get readingAllowed;

  /// Whether App Lock is off. Held output is dropped while it is on.
  bool get unlocked;

  /// Reads the list now and answers the agent's row in it: [WorkOk] with null
  /// when the list no longer has it. Anything but [WorkOk] is a failed read.
  Future<AgentWorkResult<AgentView?>> rereadList();
}
