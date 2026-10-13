import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

void main() {
  test('side completions keep their source and never masquerade as the foreground answer', () async {
    final gateway = FakeGateway();
    gateway.turn = (g, sid) {
      g.event('background.complete', 'foreign-runtime', {
        'task_id': 'task',
        'text': 'Foreign',
      });
      g.event('background.complete', sid, {
        'task_id': 'task',
        'text': 'Background',
      });
      g.event('btw.complete', sid, {
        'task_id': 'task',
        'text': 'Side',
        'question': 'Question',
      });
      g.event('btw.complete', sid, {'task_id': '', 'text': 'Malformed'});
      g.event('message.complete', sid, {
        'text': 'Main answer',
        'status': 'complete',
      });
    };
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
    final events = await transport
        .send(text: 'Foreground', profile: 'work')
        .toList();
    final results = events.whereType<SideResultReceived>().toList();
    expect(results.map((event) => event.result.text), ['Background', 'Side']);
    expect(events.whereType<ReplyCompleted>().single.text, 'Main answer');
    final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
    expect(
      results.every((event) => identical(event.connection, binding.connection)),
      isTrue,
    );
    expect(results.map((event) => event.runtimeId), ['rt-1', 'rt-1']);
  });

  test(
    'a queued prompt exposes side answers while it waits for the prior turn',
    () {
      fakeAsync((clock) {
        final gateway = FakeGateway()..submitStatus = 'queued';
        final transport = HermesGatewayTransport(connect: gateway.connect);
        final seen = <ChatEvent>[];
        final subscription = transport.send(text: 'Queued').listen(seen.add);
        clock.flushMicrotasks();
        gateway.event('btw.complete', 'rt-1', {
          'task_id': 'task',
          'text': 'Side while queued',
        });
        clock.flushMicrotasks();
        expect(
          seen.whereType<SideResultReceived>().single.result.text,
          'Side while queued',
        );
        expect(seen.whereType<ReplyCompleted>(), isEmpty);
        expect(seen.whereType<ReplyStarted>(), isEmpty);
        unawaited(subscription.cancel());
        unawaited(transport.close());
        clock.flushMicrotasks();
      });
    },
  );

  test('reconnect replay and concurrent live delivery use the existing sequence ledger', () {
    fakeAsync((clock) {
      final gateway = FakeGateway()
        ..stampSeq = true
        ..sendReady = true;
      gateway.resumeResult = {
        'session_id': 'rt-1',
        'session_key': 'stored-1',
        'running': true,
      };
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('background.complete', sid, {
          'task_id': 'task',
          'text': 'Before drop',
        });
        g.drop();
        g.event('background.complete', sid, {
          'task_id': 'task',
          'text': 'Replayed replacement',
        });
      };
      gateway.beforeEventsAnswer = (g) => g.event('btw.complete', 'rt-1', {
        'task_id': 'task',
        'text': 'Both replay and live',
      });
      final transport = HermesGatewayTransport(
        connect: gateway.connect,
        sleep: (_) async {},
      );
      final seen = <ChatEvent>[];
      final subscription = transport
          .send(text: 'Foreground', profile: 'work')
          .listen(seen.add);
      clock.flushMicrotasks();
      final side = seen.whereType<SideResultReceived>().toList();
      expect(side.map((event) => event.result.text), [
        'Before drop',
        'Replayed replacement',
        'Both replay and live',
      ]);
      expect(identical(side.first.connection, side.last.connection), isFalse);
      expect(seen.whereType<ReplyCompleted>(), isEmpty);
      gateway.event('message.complete', 'rt-1', {
        'text': 'Main',
        'status': 'complete',
      });
      clock.flushMicrotasks();
      expect(seen.whereType<ReplyCompleted>(), hasLength(1));
      unawaited(subscription.cancel());
      unawaited(transport.close());
      clock.flushMicrotasks();
    });
  });
}
