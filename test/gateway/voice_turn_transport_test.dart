import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;

  void completes(FakeGateway g, String sid) =>
      g.event('message.complete', sid, {'text': 'hi', 'status': 'complete'});

  Map<String, Object?> submitted() =>
      gateway.requests.firstWhere(
            (r) => r['method'] == 'prompt.submit',
          )['params']
          as Map<String, Object?>;

  setUp(() {
    gateway = FakeGateway()..turn = completes;
    transport = HermesGatewayTransport(
      connect: gateway.connect,
      sleep: (_) async {},
    );
  });
  tearDown(() => transport.close());

  group('voice turn flags in prompt.submit', () {
    test(
      'a voice turn sends voice_turn and, when asked, interrupted',
      () async {
        await transport
            .send(
              text: 'hi',
              threadId: 'stored-1',
              voiceTurn: true,
              interrupted: true,
            )
            .toList();
        expect(submitted()['voice_turn'], isTrue);
        expect(submitted()['interrupted'], isTrue);
      },
    );

    test(
      'a voice turn that is not interrupting carries no interrupted',
      () async {
        await transport
            .send(text: 'hi', threadId: 'stored-1', voiceTurn: true)
            .toList();
        expect(submitted()['voice_turn'], isTrue);
        expect(submitted(), isNot(contains('interrupted')));
      },
    );

    test(
      'a typed send carries neither flag, even when asked for interrupted',
      () async {
        await transport
            .send(text: 'hi', threadId: 'stored-1', interrupted: true)
            .toList();
        expect(submitted(), isNot(contains('voice_turn')));
        expect(submitted(), isNot(contains('interrupted')));
      },
    );

    test('a voice turn never carries queued', () async {
      await transport
          .send(text: 'hi', threadId: 'stored-1', voiceTurn: true, queued: true)
          .toList();
      expect(submitted(), isNot(contains('queued')));
    });
  });

  group('what Hermes answers a voice turn', () {
    for (final status in ['queued', 'steered', 'redirected']) {
      test('$status is reported to the sender', () async {
        gateway.handlers['prompt.submit'] = (_) => {'status': status};
        final accepted = await transport
            .send(text: 'hi', threadId: 'stored-1', voiceTurn: true)
            .firstWhere((e) => e is PromptAccepted);
        expect((accepted as PromptAccepted).status, status);
      });
    }

    test('a streaming answer is reported too', () async {
      gateway.handlers['prompt.submit'] = (params) {
        Future<void>(() => completes(gateway, params['session_id'] as String));
        return {'status': 'streaming'};
      };
      final events = await transport
          .send(text: 'hi', threadId: 'stored-1', voiceTurn: true)
          .toList();
      expect(events.whereType<PromptAccepted>().single.status, 'streaming');
    });

    test('voice_stopped ends the send with no reply', () async {
      gateway.handlers['prompt.submit'] = (_) => {'voice_stopped': true};
      final events = await transport
          .send(text: 'stop', threadId: 'stored-1', voiceTurn: true)
          .toList();
      expect(
        events.whereType<PromptAccepted>().single.status,
        PromptAccepted.voiceStopped,
      );
      expect(events.whereType<ReplyCompleted>(), isEmpty);
      expect(transport.promptAccepted, isTrue);
    });

    test('voice_stopped answers a typed prompt the same way', () async {
      gateway.handlers['prompt.submit'] = (_) => {'voice_stopped': true};
      final events = await transport
          .send(text: 'stop', threadId: 'stored-1')
          .toList();
      expect(
        events.whereType<PromptAccepted>().single.status,
        PromptAccepted.voiceStopped,
      );
    });
  });

  group('authorize', () {
    test('End during session.resume sends no prompt.submit', () async {
      var wanted = true;
      var submitting = 0;
      gateway.handlers['session.resume'] = (_) {
        wanted = false;
        return {'session_id': 'rt-1', 'stored_session_id': 'stored-1'};
      };
      await expectLater(
        transport
            .send(
              text: 'hi',
              threadId: 'stored-1',
              voiceTurn: true,
              authorize: () => wanted,
              onSubmitting: () => submitting++,
            )
            .toList(),
        throwsA(isA<PromptNotSent>()),
      );
      expect(gateway.methods, isNot(contains('prompt.submit')));
      expect(submitting, 0);
      expect(transport.promptAccepted, isFalse);
    });

    test('the request itself is guarded as it is written', () async {
      var asked = 0;
      await expectLater(
        transport
            .send(
              text: 'hi',
              threadId: 'stored-1',
              voiceTurn: true,
              authorize: () => ++asked < 2,
            )
            .toList(),
        throwsA(isA<PromptNotSent>()),
      );
      expect(gateway.methods, isNot(contains('prompt.submit')));
    });

    test('a wanted turn is sent and the callback runs first', () async {
      final order = <String>[];
      gateway.handlers['prompt.submit'] = (params) {
        order.add('submit');
        Future<void>(() => completes(gateway, params['session_id'] as String));
        return {'status': 'streaming'};
      };
      await transport
          .send(
            text: 'hi',
            threadId: 'stored-1',
            voiceTurn: true,
            authorize: () => true,
            onSubmitting: () => order.add('callback'),
          )
          .toList();
      expect(order, ['callback', 'submit']);
    });
  });
}
