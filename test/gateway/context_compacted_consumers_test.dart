import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_reply.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/live_activities/live_activity_state.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';

import '../support/fake_gateway.dart';

/// `status.update {kind: compacted}` becomes [ContextCompacted]. Nothing that
/// reads the event stream may take it for progress, an answer, the opening
/// of a reply or a request.
void main() {
  const compacted = ContextCompacted(runtimeId: 'rt-1');

  test('is neither a turn beginning nor a turn opening', () {
    expect(beginsTurn(compacted), isFalse);
    expect(opensTurn(compacted), isFalse);
  });

  test('changes nothing of a reply', () {
    final reply = ChatMessage(
      id: 'r',
      role: ChatRole.assistant,
      content: 'So far',
      createdAt: DateTime.utc(2030),
      status: MessageStatus.streaming,
    );
    applyReplyEvent(reply, compacted);
    expect(reply.content, 'So far');
    expect(reply.status, MessageStatus.streaming);
    expect(reply.activity, isNull);
  });

  test('moves no Live Activity or watch state', () {
    for (final state in ReplyActivityState.values) {
      expect(nextActivityState(state, compacted), state);
    }
  });

  test('raises no notification', () {
    expect(
      attentionFor(
        event: compacted,
        thread: ChatThread(id: 't', title: 'T', updatedAt: DateTime.utc(2030)),
        appFocused: false,
        selectedThreadId: null,
        enabled: true,
      ),
      isNull,
    );
  });

  test('passes through a send without ending or advancing it', () async {
    final gateway = FakeGateway();
    gateway.turn = (g, sid) {
      g.event('status.update', sid, {'kind': 'compressing', 'text': 'x'});
      g.event('status.update', sid, {'kind': 'compacted', 'text': 'Done'});
      g.event('message.delta', sid, {'text': 'Answer'});
      g.event('message.complete', sid, {
        'text': 'Answer',
        'status': 'complete',
      });
    };
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
    final events = await transport.send(text: 'Test', profile: 'work').toList();
    final at = events.indexWhere((e) => e is ContextCompacted);
    expect(at, isNonNegative);
    expect(events.whereType<ContextCompacted>().single.runtimeId, isNotEmpty);
    // The reply goes on after it and ends on its own completion.
    expect(events.skip(at).whereType<ReplyDelta>(), isNotEmpty);
    expect(events.whereType<ReplyCompleted>().single.text, 'Answer');
    expect(
      events.whereType<ReplyStatus>().map((e) => e.kind),
      contains(ReplyStatusKind.compressing),
    );
    expect(events.whereType<SessionWaitUpdated>(), isEmpty);
  });
}
