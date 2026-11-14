import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

Matcher _failedAt(SendStep step, {Matcher? cause}) => isA<SendFailure>()
    .having((f) => f.step, 'step', step)
    .having((f) => f.cause, 'cause', cause ?? anything);

OutgoingAttachment _image() => OutgoingAttachment(
  name: 'photo.png',
  kind: AttachmentKind.image,
  mimeType: 'image/png',
  read: () async => Uint8List.fromList([1, 2, 3]),
);

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late int submitting;
  late List<String> order;

  void onSubmitting() {
    submitting++;
    order.add('callback');
  }

  void completes(FakeGateway g, String sid) =>
      g.event('message.complete', sid, {'text': 'hi', 'status': 'complete'});

  setUp(() {
    submitting = 0;
    order = [];
    gateway = FakeGateway()..turn = completes;
    transport = HermesGatewayTransport(
      connect: gateway.connect,
      sleep: (_) async {},
    );
  });
  tearDown(() => transport.close());

  Stream<ChatEvent> send({
    String? threadId,
    List<OutgoingAttachment> attachments = const [],
    bool callback = true,
  }) => transport.send(
    threadId: threadId,
    text: 'secret prompt text',
    attachments: attachments,
    queued: true,
    onSubmitting: callback ? onSubmitting : null,
  );

  group('send with onSubmitting', () {
    test(
      'runs the callback once, just before prompt.submit is written',
      () async {
        gateway.handlers['prompt.submit'] = (params) {
          order.add('submit');
          expect(submitting, 1);
          Future<void>(
            () => completes(gateway, params['session_id'] as String),
          );
          return {'status': 'streaming'};
        };
        final events = await send().toList();
        expect(events.whereType<ReplyCompleted>(), hasLength(1));
        expect(submitting, 1);
        expect(order, ['callback', 'submit']);
        expect(transport.promptAccepted, isTrue);
      },
    );

    test('a prompt result with no status is a normal send', () async {
      gateway.handlers['prompt.submit'] = (params) {
        Future<void>(() => completes(gateway, params['session_id'] as String));
        return <String, Object?>{};
      };
      final events = await send().toList();
      expect(events.whereType<PromptAccepted>(), isEmpty);
      expect(events.whereType<ReplyCompleted>(), hasLength(1));
      expect(submitting, 1);
      expect(transport.promptAccepted, isTrue);
    });

    test('a connect error is a connect failure and never calls it', () async {
      var opened = 0;
      transport = HermesGatewayTransport(
        sleep: (_) async {},
        connect: () async {
          opened++;
          throw StateError('network down');
        },
      );
      await expectLater(
        send().toList(),
        throwsA(_failedAt(SendStep.connect, cause: isA<StateError>())),
      );
      expect(opened, greaterThan(0));
      expect(submitting, 0);
      expect(transport.promptAccepted, isFalse);
    });

    test('a resume error is an open failure', () async {
      gateway.handlers['session.resume'] = (_) =>
          throw const FakeRpcError(5000);
      await expectLater(
        send(threadId: 'stored-1').toList(),
        throwsA(_failedAt(SendStep.open, cause: isA<GatewayRpcException>())),
      );
      expect(submitting, 0);
    });

    test('a create error is an open failure', () async {
      gateway.handlers['session.create'] = (_) =>
          throw const FakeRpcError(5000);
      await expectLater(send().toList(), throwsA(_failedAt(SendStep.open)));
      expect(submitting, 0);
    });

    test(
      'a profile that is gone stays a ProfileUnavailableException',
      () async {
        gateway.sessionErrorCode = 4064;
        await expectLater(
          send().toList(),
          throwsA(isA<ProfileUnavailableException>()),
        );
        expect(submitting, 0);
      },
    );

    test('an attach error is an attach failure', () async {
      gateway.handlers['image.attach_bytes'] = (_) =>
          throw const FakeRpcError(5000);
      await expectLater(
        send(attachments: [_image()]).toList(),
        throwsA(_failedAt(SendStep.attach)),
      );
      expect(submitting, 0);
      expect(gateway.methods, isNot(contains('prompt.submit')));
    });

    test(
      'a callback that throws is an attach failure and sends nothing',
      () async {
        await expectLater(
          transport
              .send(
                text: 'x',
                queued: true,
                onSubmitting: () => throw StateError('boom'),
              )
              .toList(),
          throwsA(_failedAt(SendStep.attach)),
        );
        expect(gateway.methods, isNot(contains('prompt.submit')));
        expect(transport.promptAccepted, isFalse);
      },
    );

    test('a rejected prompt.submit is a submit failure', () async {
      gateway.handlers['prompt.submit'] = (_) => throw const FakeRpcError(5000);
      await expectLater(
        send().toList(),
        throwsA(_failedAt(SendStep.submit, cause: isA<GatewayRpcException>())),
      );
      expect(submitting, 1);
    });

    test('a drop after the callback ran is a submit failure', () async {
      gateway.handlers['prompt.submit'] = (_) {
        gateway.drop();
        return {'status': 'streaming'};
      };
      await expectLater(
        send().toList(),
        throwsA(
          _failedAt(SendStep.submit, cause: isA<GatewayConnectionClosed>()),
        ),
      );
      expect(submitting, 1);
      expect(transport.promptAccepted, isFalse);
      expect(gateway.methods.where((m) => m == 'prompt.submit'), hasLength(1));
    });

    test('a timeout waiting for the result is a submit failure', () {
      fakeAsync((async) {
        final gw = FakeGateway()..silent.add('prompt.submit');
        final t = HermesGatewayTransport(connect: gw.connect);
        Object? error;
        t
            .send(text: 'x', queued: true, onSubmitting: onSubmitting)
            .listen((_) {}, onError: (Object e) => error = e);
        async.elapse(const Duration(seconds: 31));
        expect(error, _failedAt(SendStep.submit));
        expect(submitting, 1);
        expect(t.promptAccepted, isFalse);
        unawaited(t.close());
        async.flushMicrotasks();
      });
    });

    test(
      'a failure after the prompt was answered is a reply failure',
      () async {
        var connects = 0;
        transport = HermesGatewayTransport(
          sleep: (_) async {},
          connect: () async {
            if (connects++ > 0) throw StateError('network down');
            return gateway.connect();
          },
        );
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.drop();
        };
        await expectLater(send().toList(), throwsA(_failedAt(SendStep.reply)));
        expect(submitting, 1);
        expect(transport.promptAccepted, isTrue);
      },
    );

    test(
      'a reclaim before attach ends the stream before the callback',
      () async {
        gateway.handlers['session.resume'] = (_) {
          gateway.event('session.reclaimed', '', {
            'session_id': 'rt-1',
            'stored_session_id': 'stored-1',
            'reason': 'x',
          });
          return {'session_id': 'rt-1', 'stored_session_id': 'stored-1'};
        };
        final events = await send(threadId: 'stored-1').toList();
        expect(events.whereType<SessionReclaimed>(), hasLength(1));
        expect(submitting, 0);
        expect(transport.promptAccepted, isFalse);
      },
    );

    test(
      'a reclaim before submit ends the stream before the callback',
      () async {
        gateway.handlers['image.attach_bytes'] = (params) {
          gateway.event('session.reclaimed', '', {
            'session_id': params['session_id'],
            'stored_session_id': 'stored-1',
            'reason': 'x',
          });
          return {'attached': true, 'path': '/tmp/p.png'};
        };
        final events = await send(attachments: [_image()]).toList();
        expect(events.whereType<SessionReclaimed>(), hasLength(1));
        expect(submitting, 0);
        expect(gateway.methods, isNot(contains('prompt.submit')));
      },
    );

    test(
      'a reclaim after submit comes after the callback and the answer',
      () async {
        gateway.turn = (g, sid) {
          g.event('message.start', sid);
          g.event('session.reclaimed', '', {
            'session_id': sid,
            'stored_session_id': 'stored-1',
            'reason': 'x',
          });
        };
        final events = await send().toList();
        expect(events.whereType<SessionReclaimed>(), hasLength(1));
        expect(submitting, 1);
        expect(transport.promptAccepted, isTrue);
      },
    );

    test(
      'a reclaim with prompt.submit then rejected leaves it unacknowledged',
      () async {
        gateway.handlers['prompt.submit'] = (params) {
          gateway.event('session.reclaimed', '', {
            'session_id': params['session_id'],
            'stored_session_id': 'stored-1',
            'reason': 'x',
          });
          throw const FakeRpcError(5000);
        };
        final events = await send().toList();
        expect(events.whereType<SessionReclaimed>(), hasLength(1));
        expect(submitting, 1);
        expect(transport.promptAccepted, isFalse);
      },
    );

    test('no message, step or cause leaks the prompt or server text', () async {
      gateway.handlers['session.create'] = (_) =>
          throw const FakeRpcError(5000, 'server says secret prompt text');
      try {
        await send().toList();
        fail('expected a failure');
      } on SendFailure catch (failure) {
        expect(failure.toString(), isNot(contains('secret')));
        expect(failure.toString(), isNot(contains('5000')));
      }
    });
  });

  group('send without onSubmitting', () {
    test('keeps raw errors, queued or not', () async {
      gateway.handlers['session.create'] = (_) =>
          throw const FakeRpcError(5000);
      await expectLater(
        send(callback: false).toList(),
        throwsA(isA<GatewayRpcException>()),
      );
    });
  });
}
