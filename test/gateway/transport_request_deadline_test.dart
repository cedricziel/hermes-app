import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_gateway.dart';
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
        final transport = HermesGatewayTransport(
          connect: gateway.connect,
          telemetry: ConnectionTelemetry(tracer: tracer).gateway(),
        );
        body(async, gateway, transport, tracer, (by) => jumped += by, now);
        unawaited(transport.close());
        async.flushMicrotasks();
      });
    });
  }

  RecordingSpan span(RecordingTracer tracer, String method) =>
      tracer.spans.singleWhere((s) => s.name == '$method send');

  test('a slash command nobody answers gives up at the request timeout and '
      'its span says it timed out', () {
    run((async, gateway, transport, tracer, jump, now) {
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
    run((async, gateway, transport, tracer, jump, now) {
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
      expect(slash.endedAt, sent.add(transport.requestTimeout));
    });
  });

  test('a request of a transport call with no timeout of its own is '
      'abandoned too, and its span ends', () {
    run((async, gateway, transport, tracer, jump, now) {
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
}
