import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

void main() {
  test(
    'process chunks keep their source without becoming foreground completions',
    () async {
      final gateway = FakeGateway();
      gateway.turn = (g, sid) {
        g.event('agent.terminal.output', 'foreign-runtime', {
          'process_id': 'task',
          'chunk': 'Foreign',
        });
        g.event('agent.terminal.output', sid, {
          'process_id': 'task',
          'chunk': 'first',
        });
        g.event('agent.terminal.output', sid, {
          'process_id': 'task',
          'chunk': ' second',
        });
        g.event('agent.terminal.output', sid, {
          'process_id': '',
          'chunk': 'Malformed',
        });
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
      final results = events.whereType<ProcessOutputReceived>().toList();
      expect(results.map((event) => event.update.chunk), ['first', ' second']);
      expect(events.whereType<ReplyCompleted>().single.text, 'Main answer');
      final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
      expect(
        results.every(
          (event) => identical(event.connection, binding.connection),
        ),
        isTrue,
      );
      expect(results.map((event) => event.runtimeId), ['rt-1', 'rt-1']);
    },
  );

  test(
    'a queued prompt exposes process chunks while waiting for the prior turn',
    () {
      fakeAsync((clock) {
        final gateway = FakeGateway()..submitStatus = 'queued';
        final transport = HermesGatewayTransport(connect: gateway.connect);
        final seen = <ChatEvent>[];
        final subscription = transport.send(text: 'Queued').listen(seen.add);
        clock.flushMicrotasks();
        gateway.event('agent.terminal.output', 'rt-1', {
          'process_id': 'task',
          'chunk': 'While queued',
        });
        clock.flushMicrotasks();
        expect(
          seen.whereType<ProcessOutputReceived>().single.update.chunk,
          'While queued',
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
        g.event('agent.terminal.output', sid, {
          'process_id': 'task',
          'chunk': 'Before drop',
        });
        g.drop();
        g.event('agent.terminal.output', sid, {
          'process_id': 'task',
          'chunk': ' then replayed',
        });
      };
      gateway.beforeEventsAnswer = (g) => g.event(
        'agent.terminal.output',
        'rt-1',
        {'process_id': 'task', 'chunk': ' and replay/live'},
      );
      final transport = HermesGatewayTransport(
        connect: gateway.connect,
        sleep: (_) async {},
      );
      final seen = <ChatEvent>[];
      final subscription = transport
          .send(text: 'Foreground', profile: 'work')
          .listen(seen.add);
      clock.flushMicrotasks();
      final chunks = seen.whereType<ProcessOutputReceived>().toList();
      expect(chunks.map((event) => event.update.chunk), [
        'Before drop',
        ' then replayed',
        ' and replay/live',
      ]);
      expect(
        identical(chunks.first.connection, chunks.last.connection),
        isFalse,
      );
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
