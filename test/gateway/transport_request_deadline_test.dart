import 'dart:async';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_gateway.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';

/// No request span of the transport outlives the request's deadline, whatever
/// went wrong with the socket and however long the app slept meanwhile.
void main() {
  /// Runs [body] under fake time on a wall clock [jump] moves without a timer
  /// firing, as a suspended process sees it.
  void run(
    void Function(
      FakeAsync async,
      FakeGateway gateway,
      HermesGatewayTransport transport,
      RecordingTracer tracer,
      void Function(Duration by) jump,
      DateTime Function() now,
      RecordedEvents events,
    )
    body,
  ) {
    fakeAsync((async) {
      final start = DateTime(2026, 1, 1, 12);
      var jumped = Duration.zero;
      DateTime now() => start.add(async.elapsed + jumped);
      withClock(Clock(now), () {
        final gateway = FakeGateway();
        final tracer = RecordingTracer();
        final events = RecordedEvents();
        final transport = HermesGatewayTransport(
          connect: gateway.connect,
          events: events.call,
          telemetry: ConnectionTelemetry(tracer: tracer).gateway(),
        );
        body(
          async,
          gateway,
          transport,
          tracer,
          (by) => jumped += by,
          now,
          events,
        );
        unawaited(transport.close());
        async.flushMicrotasks();
      });
    });
  }

  RecordingSpan span(RecordingTracer tracer, String method) =>
      tracer.spans.singleWhere((s) => s.name == '$method send');

  test('a slash command nobody answers gives up at the request timeout and '
      'its span says it timed out', () {
    run((async, gateway, transport, tracer, jump, now, events) {
      gateway.silent.add('slash.exec');
      Object? error;
      transport
          .runSlashCommand(command: '/memory pending')
          .then<void>((_) {}, onError: (Object e) => error = e);
      async.flushMicrotasks();
      final sent = now();

      async.elapse(transport.requestTimeout);
      async.flushMicrotasks();

      expect(error, isA<GatewayCallTimedOut>());
      final slash = span(tracer, 'slash.exec');
      expect(slash.ended, isTrue);
      expect(slash.attributes['error.type'], 'GatewayRequestTimeout');
      expect(slash.status?.name, 'error');
      expect(now().difference(sent), transport.requestTimeout);
    });
  });

  test('a slash command in flight while the app slept ends its span at the '
      'request timeout, not when the app came back', () {
    run((async, gateway, transport, tracer, jump, now, events) {
      gateway.silent.add('slash.exec');
      transport
          .runSlashCommand(command: '/memory pending')
          .then<void>((_) {}, onError: (Object _) {});
      async.flushMicrotasks();
      final sent = now();

      jump(const Duration(minutes: 30));
      async.elapse(transport.requestTimeout);
      async.flushMicrotasks();

      final slash = span(tracer, 'slash.exec');
      expect(slash.ended, isTrue);
      expect(slash.endTime, sent.add(transport.requestTimeout));
    });
  });

  test('a request of a transport call with no timeout of its own is '
      'abandoned too, and its span ends', () {
    run((async, gateway, transport, tracer, jump, now, events) {
      gateway.silent.add('clarify.respond');
      Object? error;
      transport
          .answerClarify('req-1', const ['yes'])
          .then<void>((_) {}, onError: (Object e) => error = e);
      async.flushMicrotasks();

      async.elapse(transport.longTimeout);
      async.flushMicrotasks();

      expect(error, isA<GatewayRequestTimeout>());
      final answer = span(tracer, 'clarify.respond');
      expect(answer.ended, isTrue);
      expect(answer.attributes['error.type'], 'GatewayRequestTimeout');
    });
  });

  test('a connector answer nobody confirms is abandoned and its span ends', () {
    run((async, gateway, transport, tracer, jump, now, events) {
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Main',
        'status': 'complete',
      });
      gateway.silent.add('connection.respond');
      transport.send(text: 'First', profile: 'work').listen((_) {});
      async.flushMicrotasks();
      final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
      Object? error;
      transport
          .respondToConnectorOperation(binding, {
            'owner': {'type': 'session', 'session_id': 'rt-1'},
            'op_id': 'operation',
            'profile': 'work',
            'result': {
              'targets': [
                {'name': 'connector', 'status': 'skipped'},
              ],
            },
          }, authorize: () => true)
          .then<void>((_) {}, onError: (Object e) => error = e);
      async.flushMicrotasks();

      async.elapse(transport.requestTimeout);
      async.flushMicrotasks();

      expect(error, isA<GatewayRequestTimeout>());
      expect(span(tracer, 'connection.respond').ended, isTrue);
    });
  });

  test('the control read of a watched session is abandoned at the request '
      'timeout and its span ends', () {
    run((async, gateway, transport, tracer, jump, now, events) {
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Main',
        'status': 'complete',
      });
      gateway.silent.add('session.control.read');
      transport.send(text: 'First').listen((_) {});
      async.flushMicrotasks();
      expect(span(tracer, 'session.control.read').ended, isFalse);

      async.elapse(transport.requestTimeout);
      async.flushMicrotasks();

      final read = span(tracer, 'session.control.read');
      expect(read.ended, isTrue);
      expect(read.attributes['error.type'], 'GatewayRequestTimeout');
    });
  });

  test('an attachment gets the time to upload on top of the long timeout, '
      'and a send it ends is logged as a timeout', () {
    run((async, gateway, transport, tracer, jump, now, events) {
      gateway.silent.add('file.attach');
      transport
          .send(
            text: 'Look',
            attachments: [
              OutgoingAttachment(
                name: 'big.bin',
                kind: AttachmentKind.file,
                read: () async => Uint8List(3 * 1024 * 1024),
              ),
            ],
          )
          .listen((_) {}, onError: (Object _) {});
      async.flushMicrotasks();

      async.elapse(transport.longTimeout + const Duration(seconds: 1));
      async.flushMicrotasks();
      expect(
        span(tracer, 'file.attach').ended,
        isFalse,
        reason: 'the upload counts against nobody',
      );

      async.elapse(const Duration(minutes: 2));
      async.flushMicrotasks();
      expect(span(tracer, 'file.attach').ended, isTrue);
      expect(events.named('gateway.send_failed').single['cause'], 'timeout');
    });
  });

  test('billing verification, a device flow that waits for the user, is not '
      'abandoned at the default deadline', () {
    run((async, gateway, transport, tracer, jump, now, events) {
      gateway.turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'Main',
        'status': 'complete',
      });
      gateway.silent.add('billing.step_up');
      transport.send(text: 'First', profile: 'work').listen((_) {});
      async.flushMicrotasks();
      final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
      Map<String, Object?>? granted;
      Object? error;
      transport
          .stepUpBilling(binding, authorize: () => true)
          .then<void>((r) => granted = r, onError: (Object e) => error = e);
      async.flushMicrotasks();

      async.elapse(transport.longTimeout + const Duration(minutes: 5));
      async.flushMicrotasks();
      expect(error, isNull);
      expect(span(tracer, 'billing.step_up').ended, isFalse);

      gateway.replyTo(gateway.requestOf('billing.step_up'), {'granted': true});
      async.flushMicrotasks();
      expect(granted, {'granted': true});
    });
  });
}
