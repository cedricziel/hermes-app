import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/live_activities/live_activity_state.dart';

void main() {
  const working = ReplyActivityState.working;

  test('input requests show what Hermes waits for', () {
    expect(
      nextActivityState(
        working,
        const ApprovalRequested(
          ApprovalRequest(
            requestId: 'a',
            command: 'rm -rf build',
            description: '',
            choices: [],
          ),
        ),
      ),
      ReplyActivityState.approval,
    );
    expect(
      nextActivityState(
        working,
        const ClarifyRequested(ClarifyRequest(requestId: 'c', questions: [])),
      ),
      ReplyActivityState.question,
    );
  });

  test('progress or a withdrawn request returns to working', () {
    const approval = ReplyActivityState.approval;
    for (final event in <ChatEvent>[
      const InputRequestExpired('a'),
      const InputRequestsCancelled([]),
      const ReplyDelta('x'),
      const ToolPreparing('terminal'),
    ]) {
      expect(nextActivityState(approval, event), working, reason: '$event');
    }
  });

  test('streaming leaves a working activity alone', () {
    expect(nextActivityState(working, const ReplyDelta('x')), working);
    expect(nextActivityState(working, const ThreadTitled('T')), working);
  });

  test('a completion finishes it; a stop removes it', () {
    expect(
      nextActivityState(working, const ReplyCompleted('Done')),
      ReplyActivityState.ready,
    );
    expect(
      nextActivityState(working, const ReplyCompleted('', failed: true)),
      ReplyActivityState.failed,
    );
    expect(
      nextActivityState(working, const ReplyCompleted('', stopped: true)),
      isNull,
    );
  });

  test('a finished activity ignores later events', () {
    const ready = ReplyActivityState.ready;
    expect(nextActivityState(ready, const ReplyDelta('x')), ready);
    expect(
      nextActivityState(ready, const ReplyCompleted('', failed: true)),
      ready,
    );
  });

  test('labels never carry what the agent asked', () {
    expect(ReplyActivityState.values.map((s) => s.label), [
      'Working',
      'Waiting for your approval',
      'Has a question for you',
      'Waiting for you in Hermes',
      'Reply ready',
      'Reply failed',
    ]);
  });
}
