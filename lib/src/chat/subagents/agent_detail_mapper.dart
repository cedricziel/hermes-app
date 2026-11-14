import 'package:clock/clock.dart';

import 'roster_row.dart';
import 'subagent_detail_controller.dart';
import 'widgets/agent_detail_view.dart';
import 'widgets/agent_note_field.dart';
import 'widgets/agent_output_view.dart';

/// How long [row] has run: from its start while it runs, its reported
/// duration once it ended.
Duration? agentRunTime(RosterRow row) {
  if (row.active) {
    final started = row.startedAt;
    if (started == null) return null;
    final spent = clock.now().difference(started);
    return spent.isNegative ? Duration.zero : spent;
  }
  return row.duration;
}

/// What the agent's detail shows, from its row and its controller. Nothing
/// here is user-visible text: the widgets turn the states into words.
AgentDetailModel agentDetailModel({
  required RosterRow row,
  required SubagentDetailController? controller,
  required bool readOnly,
}) {
  final base = AgentDetailModel(
    goal: row.goal,
    state: row.state,
    runTime: agentRunTime(row),
    toolCount: row.toolCount ?? 0,
    currentTool: row.lastTool,
    startedByAgent: row.parentId != null,
    delivered: row.summary,
    error: row.error,
  );
  // A failed background delegation has no live agent, and a detail that
  // cannot reach the session (a conversation window) only describes.
  if (row.delegationOnly) return base;
  // A window that holds no session says so and offers no Stop or note.
  if (readOnly) {
    return AgentDetailModel(
      goal: base.goal,
      state: base.state,
      runTime: base.runTime,
      toolCount: base.toolCount,
      currentTool: base.currentTool,
      startedByAgent: base.startedByAgent,
      delivered: base.delivered,
      error: base.error,
      stop: AgentStopStatus.notControllable,
    );
  }
  if (controller == null) return base;

  final tail = controller.tailPhase;
  final output = tail == TailPhase.unsupported
      ? null
      : AgentOutputModel(
          text: controller.tail,
          status: switch (tail) {
            TailPhase.loading => AgentOutputStatus.loading,
            TailPhase.ready => AgentOutputStatus.ready,
            TailPhase.noOutput => AgentOutputStatus.none,
            TailPhase.neverAvailable => AgentOutputStatus.never,
            TailPhase.unsupported => AgentOutputStatus.ready,
          },
          truncated: controller.tailTruncated,
          refreshFailed: controller.refreshFailed,
          paused: controller.paused,
          last: controller.lastOutput,
        );

  final accepting = row.acceptingSteer != false;
  final hasText = controller.note.isNotEmpty;
  final noteHidden = row.active && !accepting && !hasText;
  final note = noteHidden
      ? null
      : AgentNoteModel(
          goal: row.goal,
          text: controller.note,
          length: controller.noteLength,
          status: controller.noteMissed
              ? AgentNoteStatus.missed
              : switch (controller.notePhase) {
                  NotePhase.idle => AgentNoteStatus.idle,
                  NotePhase.sending => AgentNoteStatus.sending,
                  NotePhase.queued => AgentNoteStatus.queued,
                  NotePhase.rejected => AgentNoteStatus.rejected,
                  NotePhase.notControllable => AgentNoteStatus.notControllable,
                  NotePhase.lost => AgentNoteStatus.lost,
                  NotePhase.failed => AgentNoteStatus.failed,
                  NotePhase.unsupported => AgentNoteStatus.unsupported,
                },
          frozen: controller.noteFrozen || (row.active && !accepting),
          canSend: controller.canSendNote,
          sentNotes: controller.sentNotes,
          offline: controller.offline,
        );

  return AgentDetailModel(
    goal: base.goal,
    state: base.state,
    runTime: base.runTime,
    toolCount: base.toolCount,
    currentTool: base.currentTool,
    startedByAgent: base.startedByAgent,
    delivered: base.delivered,
    error: base.error,
    output: output,
    note: note,
    offline: controller.offline,
    stop: switch (controller.stopPhase) {
      // The confirmation is a dialog; behind it the detail is unchanged.
      StopPhase.idle || StopPhase.confirming => AgentStopStatus.idle,
      StopPhase.sending => AgentStopStatus.sending,
      StopPhase.checking => AgentStopStatus.checking,
      StopPhase.stopping => AgentStopStatus.stopping,
      StopPhase.alreadyFinished => AgentStopStatus.alreadyFinished,
      StopPhase.notControllable => AgentStopStatus.notControllable,
      StopPhase.unconfirmed => AgentStopStatus.unconfirmed,
      StopPhase.failed => AgentStopStatus.failed,
      StopPhase.unsupported => AgentStopStatus.unsupported,
      StopPhase.ended => AgentStopStatus.ended,
    },
  );
}
