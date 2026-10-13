import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/session_chat_transport.dart';

import '../support/fake_gateway.dart';
import '../support/recording_tracer.dart';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  setUp(() {
    gateway = FakeGateway();
    transport = HermesGatewayTransport(connect: gateway.connect);
    gateway.turn = (g, sid) {
      g.event('message.start', sid);
      g.event('message.complete', sid, {'text': 'Done', 'status': 'complete'});
    };
  });
  tearDown(() => transport.close());
  test('cancellation during prompt instrumentation restores the committed claim without sending bytes', () async {
    await transport.close();
    final atDispatch = Completer<void>();
    late StreamSubscription<ChatEvent> subscription;
    late Future<void> canceled;
    var committed = false;
    var restored = 0;
    final tracer = _SubmitTracer(() {
      expect(committed, isTrue);
      canceled = subscription.cancel();
      atDispatch.complete();
    });
    transport = HermesGatewayTransport(
      connect: gateway.connect,
      telemetry: gatewayTracer(tracer),
    );
    subscription = transport
        .sendQueued(
          profile: 'work',
          threadId: 'stored',
          text: 'retained',
          beforeSubmit: () async {
            committed = true;
          },
          onNotSubmitted: () async {
            restored++;
          },
        )
        .listen((_) {});
    await atDispatch.future.timeout(const Duration(seconds: 5));
    await canceled.timeout(const Duration(seconds: 5));
    await pumpEventQueue();
    expect(gateway.methods, isNot(contains('prompt.submit')));
    expect(restored, 1);
    expect(
      tracer.spans
          .where((span) => span.name == 'prompt.submit send')
          .single
          .ended,
      isTrue,
    );
  });

  test('a prompt RPC failure after bytes are sent never restores its uncertain claim', () async {
    gateway.handlers['prompt.submit'] = (_) => throw const FakeRpcError(5000);
    var restored = 0;
    await expectLater(
      transport
          .sendQueued(
            profile: 'work',
            threadId: 'stored',
            text: 'uncertain',
            beforeSubmit: () async {},
            onNotSubmitted: () async {
              restored++;
            },
          )
          .toList()
          .timeout(const Duration(seconds: 5)),
      throwsA(isA<GatewayRpcException>()),
    );
    expect(
      gateway.methods.where((method) => method == 'prompt.submit'),
      hasLength(1),
    );
    expect(restored, 0);
  });

  test('durable barrier finishes before prompt submission', () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final done = transport
        .sendQueued(
          profile: 'work',
          threadId: 'stored',
          text: 'next',
          beforeSubmit: () async {
            entered.complete();
            await release.future;
          },
        )
        .toList()
        .timeout(const Duration(seconds: 5));
    await entered.future;
    expect(gateway.methods, isNot(contains('prompt.submit')));
    release.complete();
    final events = await done;
    expect(events.whereType<PromptAccepted>().single.status, 'streaming');
    expect(
      gateway.requests
          .where((row) => row['method'] == 'prompt.submit')
          .single['params'],
      containsPair('queued', true),
    );
  });
  for (final (label, profile) in <(String, String?)>[
    ('null', null),
    ('empty', ''),
  ]) {
    test('durable submission refuses $label unresolved profile', () async {
      await expectLater(
        transport
            .sendQueued(
              profile: profile,
              threadId: 'stored',
              text: 'retained',
              beforeSubmit: () async {},
            )
            .toList(),
        throwsA(isA<QueueSubmissionNotStarted>()),
      );
      expect(gateway.methods, isNot(contains('prompt.submit')));
    });
  }

  test('failed barrier never submits a prompt', () async {
    await expectLater(
      transport
          .sendQueued(
            profile: 'work',
            threadId: 'stored',
            text: 'next',
            beforeSubmit: () async => throw StateError('storage unavailable'),
          )
          .toList()
          .timeout(const Duration(seconds: 5)),
      throwsA(
        isA<QueueSubmissionNotStarted>().having(
          (error) => error.cause,
          'cause',
          isA<StateError>(),
        ),
      ),
    );
    expect(gateway.methods, isNot(contains('prompt.submit')));
  });
  for (final status in ['streaming', 'queued', 'redirected', 'steered']) {
    test(
      'successful $status result transfers ownership before reply completion',
      () async {
        gateway.submitStatus = status;
        final events = await transport
            .sendQueued(
              profile: 'work',
              threadId: 'stored',
              text: 'next',
              beforeSubmit: () async {},
            )
            .toList()
            .timeout(const Duration(seconds: 5));
        expect(events.whereType<PromptAccepted>().single.status, status);
      },
    );
  }
  for (final (label, result) in <(String, Map<String, Object?>)>[
    ('missing', {}),
    ('null', {'status': null}),
    ('empty', {'status': ''}),
    ('unknown', {'status': 'accepted'}),
    ('rejected', {'status': 'rejected'}),
    ('malformed', {'status': false}),
  ]) {
    test(
      'RPC result with $label status does not transfer queue ownership',
      () async {
        gateway.handlers['prompt.submit'] = (params) {
          final session = params['session_id'] as String;
          gateway.event('message.start', session);
          gateway.event('message.complete', session, {
            'text': 'Done',
            'status': 'complete',
          });
          return result;
        };
        final events = await transport
            .sendQueued(
              profile: 'work',
              threadId: 'stored',
              text: 'next',
              beforeSubmit: () async {},
            )
            .toList()
            .timeout(const Duration(seconds: 5));
        expect(events.whereType<PromptAccepted>(), isEmpty);
        expect(
          gateway.methods.where((method) => method == 'prompt.submit'),
          hasLength(1),
        );
      },
    );
  }

  for (final (label, result, expectedRow, expectedQueueStatus)
      in <(String, Map<String, Object?>, List<int>, List<String>)>[
        (
          'canonical row and positive status',
          {'status': 'streaming', 'user_row_id': 42},
          [42],
          ['streaming'],
        ),
        (
          'canonical row and unknown status',
          {'status': 'accepted', 'user_row_id': 42},
          [42],
          [],
        ),
        (
          'malformed row and positive status',
          {'status': 'streaming', 'user_row_id': '42'},
          [],
          ['streaming'],
        ),
      ]) {
    test('$label keeps row and queue acceptance proofs distinct', () async {
      gateway.handlers['prompt.submit'] = (params) {
        final session = params['session_id'] as String;
        gateway.event('message.start', session);
        gateway.event('message.complete', session, {
          'text': 'Done',
          'status': 'complete',
        });
        return result;
      };
      final events = await transport
          .sendQueued(
            profile: 'work',
            threadId: 'stored',
            text: 'next',
            beforeSubmit: () async {},
          )
          .toList()
          .timeout(const Duration(seconds: 5));
      expect(
        events.whereType<PromptAcknowledged>().map((event) => event.userRowId),
        expectedRow,
      );
      expect(
        events.whereType<PromptAccepted>().map((event) => event.status),
        expectedQueueStatus,
      );
    });
  }

  test(
    'ordinary sends retain canonical receipt without queue-only event',
    () async {
      gateway.handlers['prompt.submit'] = (params) {
        final session = params['session_id'] as String;
        gateway.event('message.start', session);
        gateway.event('message.complete', session, {
          'text': 'Done',
          'status': 'complete',
        });
        return {'status': 'streaming', 'user_row_id': 42};
      };
      final events = await transport
          .send(threadId: 'stored', text: 'ordinary')
          .toList()
          .timeout(const Duration(seconds: 5));
      expect(events.whereType<PromptAcknowledged>().single.userRowId, 42);
      expect(events.whereType<PromptAccepted>(), isEmpty);
    },
  );

  test(
    'reclaim during the persistence barrier restores without a submit RPC',
    () async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var restored = 0;
      final done = transport
          .sendQueued(
            profile: 'work',
            threadId: 'stored',
            text: 'retained',
            beforeSubmit: () async {
              entered.complete();
              await release.future;
            },
            onNotSubmitted: () async {
              restored++;
            },
          )
          .toList()
          .timeout(const Duration(seconds: 5));
      await entered.future;
      gateway.event('session.reclaimed', '', {
        'session_id': 'rt-2',
        'stored_session_id': 'stored-2',
        'reason': 'Another client took over',
      });
      await pumpEventQueue();
      release.complete();
      final events = await done;
      expect(events.whereType<SessionReclaimed>(), hasLength(1));
      expect(restored, 1);
      expect(gateway.methods, isNot(contains('prompt.submit')));
      expect(events.whereType<PromptAccepted>(), isEmpty);
    },
  );

  test(
    'session wrapper rejects completion of barrier after suspension',
    () async {
      final wrapper = SessionChatTransport(() => transport);
      final entered = Completer<void>();
      final release = Completer<void>();
      final done = wrapper
          .sendQueued(
            profile: 'work',
            threadId: 'stored',
            text: 'next',
            beforeSubmit: () async {
              entered.complete();
              await release.future;
            },
          )
          .toList()
          .timeout(const Duration(seconds: 5));
      final failure = expectLater(
        done,
        throwsA(isA<SessionTransportUnavailable>()),
      );
      await entered.future;
      final closing = wrapper.suspend();
      release.complete();
      await closing;
      await failure;
      expect(gateway.methods, isNot(contains('prompt.submit')));
    },
  );
  test(
    'proven cancellation invokes restoration even when its stream is canceled',
    () async {
      final wrapper = SessionChatTransport(() => transport);
      final entered = Completer<void>();
      final release = Completer<void>();
      var restored = 0;
      final done = wrapper
          .sendQueued(
            profile: 'work',
            threadId: 'stored',
            text: 'next',
            beforeSubmit: () async {
              entered.complete();
              await release.future;
            },
            onNotSubmitted: () async {
              restored++;
            },
          )
          .toList()
          .timeout(const Duration(seconds: 5));
      final failure = expectLater(
        done,
        throwsA(isA<SessionTransportUnavailable>()),
      );
      await entered.future;
      final closing = wrapper.suspend();
      release.complete();
      await closing;
      await failure;
      expect(restored, 1);
      expect(gateway.methods, isNot(contains('prompt.submit')));
    },
  );
}

class _SubmitTracer extends RecordingTracer {
  _SubmitTracer(this.onSubmit);
  final void Function() onSubmit;
  @override
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Map<String, Object?>? attributes,
    SpanContext? parentContext,
    List<SpanLink> links = const [],
  }) {
    if (name == 'prompt.submit send') onSubmit();
    return super.startSpan(
      name,
      kind: kind,
      attributes: attributes,
      parentContext: parentContext,
      links: links,
    );
  }
}
