import '../chat_models.dart';
import 'agent_detail_host.dart';
import 'agent_models.dart';

/// One agent of a chat as the roster shows it, from frames, the list, or both.
final class AgentRow {
  AgentRow({
    required this.id,
    required this.order,
    this.goal = '',
    this.parentId,
    this.state = AgentState.running,
  });

  final String id;

  /// When the roster first saw the row, for a stable order among rows with no
  /// start time.
  final int order;
  String goal;
  String? parentId;
  AgentState state;
  DateTime? startedAt;
  int? toolCount;
  String? lastTool, lastToolPreview;

  /// A completion summary, or a failed delegation's error.
  String? summary, error;
  Duration? duration;
  bool? acceptingSteer;

  /// The delegation this agent belongs to (from the list) and its place in
  /// the batch (from frames).
  String? delegationId;
  int? taskIndex;

  /// The sequence of the newest frame that touched this row; a list read that
  /// started before it does not overwrite what the frame said.
  int frameSeq = 0;

  /// Whether a completion frame ended it.
  bool completedByFrame = false;

  /// A failed background delegation, which has no live agent behind it.
  bool delegationOnly = false;

  bool get active => state.active;

  AgentView toView() => AgentView(
    state: state,
    goal: goal,
    startedAt: startedAt,
    acceptingSteer: acceptingSteer,
    summary: summary,
    error: error,
  );

  @override
  String toString() => 'AgentRow($state)';
}

/// A row placed in the panel: how deep it is drawn under its parent.
final class PlacedAgent {
  const PlacedAgent(this.row, this.level);
  final AgentRow row;

  /// 0 at the top of its section, at most 2.
  final int level;
}

/// The panel's two lists: running and starting agents under Now, ended ones
/// and failed background delegations under This session.
final class AgentSections {
  const AgentSections({
    required this.now,
    required this.session,
    required this.hiddenEnded,
  });
  final List<PlacedAgent> now, session;

  /// Ended agents beyond the 20 newest, which are not shown.
  final int hiddenEnded;

  bool get isEmpty => now.isEmpty && session.isEmpty;

  @override
  String toString() =>
      'AgentSections(now: ${now.length}, session: ${session.length}, '
      'hidden: $hiddenEnded)';
}

AgentState stateOfFrame(SubagentStatus status) => switch (status) {
  SubagentStatus.running => AgentState.running,
  SubagentStatus.completed => AgentState.finished,
  SubagentStatus.failed => AgentState.failed,
  SubagentStatus.interrupted => AgentState.stopped,
};
