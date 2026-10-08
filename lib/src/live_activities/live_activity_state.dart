import '../chat/chat_transport.dart';
import '../notifications/attention_policy.dart';

const kWorkingLabel = 'Working';

/// What a chat's Live Activity shows. The labels are the notification bodies,
/// so the Lock Screen never words a state two ways, and none of them carries
/// anything the reply, a command or a question said.
enum ReplyActivityState {
  working(kWorkingLabel),
  approval(kApprovalBody),
  question(kQuestionBody),
  needsYou(kNeedsYouBody),
  ready(kReplyReadyBody),
  failed(kReplyFailedBody);

  const ReplyActivityState(this.label);

  final String label;

  bool get finished => this == ready || this == failed;
}

/// Where [event] takes an activity showing [current]: the next state, the
/// same one when the event changes nothing, or null when the user stopped the
/// reply and the activity goes away.
ReplyActivityState? nextActivityState(
  ReplyActivityState current,
  ChatEvent event,
) {
  if (current.finished) return current;
  return switch (event) {
    ReplyCompleted(stopped: true) => null,
    ReplyCompleted(:final failed) =>
      failed ? ReplyActivityState.failed : ReplyActivityState.ready,
    ApprovalRequested() => ReplyActivityState.approval,
    ClarifyRequested() => ReplyActivityState.question,
    VaultRequested() || UnsupportedRequested() => ReplyActivityState.needsYou,
    InputRequestExpired() ||
    InputRequestsCancelled() ||
    ReplyDelta() ||
    ReplyCheckpoint() ||
    ReasoningUpdated() ||
    ToolPreparing() ||
    ToolStarted() ||
    ToolFinished() => ReplyActivityState.working,
    _ => current,
  };
}
