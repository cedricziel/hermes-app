import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/session_chat_transport.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_gateway.dart';
import '../support/recording_tracer.dart';

void main() {
  test('reconnect ring never restores an old billing code but keeps current parked verification', () {
    fakeAsync((async) {
      final gateway = FakeGateway()
        ..stampSeq = true
        ..sendReady = true;
      gateway.resumeResult = {'session_id': 'rt-1', 'running': true};
      gateway.turn = (g, sid) {
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'Main'});
        g.drop();
        g.event('billing.step_up.verification', sid, {
          'verification_url': 'https://billing.invalid/old',
          'user_code': 'OLD-CODE',
        });
      };
      gateway.beforeEventsAnswer = (g) =>
          g.event('billing.step_up.verification', 'rt-1', {
            'verification_url': 'https://billing.invalid/current',
            'user_code': 'FRESH-CODE',
          });
      final exported = <Map<String, Object?>>[];
      final transport = HermesGatewayTransport(
        connect: gateway.connect,
        events: (name, [attributes = const {}]) {
          if (attributes['feature'] == 'billing_verification') {
            exported.add(attributes);
            throw StateError('Telemetry unavailable');
          }
        },
      );
      final seen = <ChatEvent>[];
      final subscription = transport
          .send(text: 'Main', profile: 'work')
          .listen(seen.add);
      async.flushMicrotasks();
      expect(gateway.methods, contains('session.events.since'));
      expect(
        seen.whereType<BillingVerificationReceived>().map(
          (event) => event.details.userCode,
        ),
        ['FRESH-CODE'],
      );
      gateway.event('message.complete', 'rt-1', {
        'text': 'Done',
        'status': 'complete',
      });
      async.flushMicrotasks();
      expect(seen.whereType<ReplyCompleted>().single.text, 'Done');
      expect(exported, [
        {'feature': 'billing_verification', 'outcome': 'discarded_replay'},
      ]);
      expect(exported.toString(), isNot(contains('OLD-CODE')));
      expect(exported.toString(), isNot(contains('billing.invalid')));
      unawaited(subscription.cancel());
      unawaited(transport.close());
      async.flushMicrotasks();
    });
  });
  test('session wrapper retirement inside the request span blocks bytes before delegate closure completes', () async {
    final gateway = FakeGateway();
    gateway.turn = (g, sid) => g.event('message.complete', sid, {
      'text': 'Main',
      'status': 'complete',
    });
    late SessionChatTransport guarded;
    final tracer = _RetiringTracer(
      retireAuthorization: false,
      onRequest: () => unawaited(guarded.suspend()),
    );
    guarded = SessionChatTransport(
      () => HermesGatewayTransport(
        connect: gateway.connect,
        telemetry: gatewayTracer(tracer),
      ),
    );
    addTearDown(guarded.close);
    await guarded.send(text: 'First', profile: 'work').toList();
    final binding = guarded.ownedSessionFor('stored-1', profile: 'work')!;
    await expectLater(
      guarded.stepUpBilling(binding, authorize: () => true),
      throwsA(isA<SessionTransportUnavailable>()),
    );
    expect(tracer.authorized, isTrue);
    expect(gateway.methods, isNot(contains('billing.step_up')));
    expect(guarded.ownedSessionFor('stored-1', profile: 'work'), isNull);
  });
  test('billing uses confirmed runtime and explicit profile without optional-call connection dropping', () async {
    final gateway = FakeGateway()..silent.add('billing.step_up');
    gateway.turn = (g, sid) => g.event('message.complete', sid, {
      'text': 'Main',
      'status': 'complete',
    });
    final transport = HermesGatewayTransport(
      connect: gateway.connect,
      requestTimeout: const Duration(milliseconds: 5),
    );
    addTearDown(transport.close);
    await transport.send(text: 'First', profile: 'work').toList();
    final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
    var finished = false;
    final future = transport
        .stepUpBilling(binding, authorize: () => true)
        .then(
          (result) {
            finished = true;
            return result;
          },
          onError: (Object error) {
            finished = true;
            return <String, Object?>{};
          },
        );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(finished, isFalse);
    expect(gateway.methods, contains('billing.step_up'));
    expect(gateway.requestOf('billing.step_up')['params'], {
      'session_id': 'rt-1',
      'profile': 'work',
    });
    await expectLater(
      transport.stepUpBilling(binding, authorize: () => true),
      throwsStateError,
    );
    expect(
      gateway.requests.where((row) => row['method'] == 'billing.step_up'),
      hasLength(1),
    );
    gateway.replyTo(gateway.requestOf('billing.step_up'), {
      'ok': true,
      'granted': true,
    });
    expect(await future, {'ok': true, 'granted': true});
    expect(transport.ownedSessionFor('stored-1', profile: 'work'), binding);
  });
  test('billing authorization revoked by request telemetry emits no mutation bytes', () async {
    final gateway = FakeGateway();
    gateway.turn = (g, sid) => g.event('message.complete', sid, {
      'text': 'Main',
      'status': 'complete',
    });
    final tracer = _RetiringTracer();
    final transport = HermesGatewayTransport(
      connect: gateway.connect,
      telemetry: gatewayTracer(tracer),
    );
    addTearDown(transport.close);
    await transport.send(text: 'First', profile: 'work').toList();
    final binding = transport.ownedSessionFor('stored-1', profile: 'work')!;
    await expectLater(
      transport.stepUpBilling(binding, authorize: () => tracer.authorized),
      throwsA(isA<Object>()),
    );
    expect(tracer.authorized, isFalse);
    expect(gateway.methods, isNot(contains('billing.step_up')));
    expect(transport.ownedSessionFor('stored-1', profile: 'work'), binding);
  });
}

class _RetiringTracer extends RecordingTracer {
  _RetiringTracer({this.retireAuthorization = true, this.onRequest});
  final bool retireAuthorization;
  final void Function()? onRequest;
  bool authorized = true;
  @override
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Map<String, Object?>? attributes,
    SpanContext? parentContext,
    List<SpanLink> links = const [],
  }) {
    if (name == 'billing.step_up send') {
      if (retireAuthorization) authorized = false;
      onRequest?.call();
    }
    return super.startSpan(
      name,
      kind: kind,
      attributes: attributes,
      parentContext: parentContext,
      links: links,
    );
  }
}
