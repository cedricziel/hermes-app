import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;

  setUp(() {
    gateway = FakeGateway();
    transport = HermesGatewayTransport(connect: () async => gateway.channel);
  });

  tearDown(() => transport.close());

  test('answers an approval it never saw by its id', () async {
    final accepted = await transport.answerOpenRequest(
      'r1',
      const ApprovalChoiceAnswer('always'),
      profile: 'work',
    );

    expect(accepted, isTrue);
    expect(gateway.requestOf('request.answer')['params'], {
      'id': 'r1',
      'result': {'choice': 'always'},
      'profile': 'work',
    });
  });

  test('answers the one question of a clarify request', () async {
    await transport.answerOpenRequest(
      'r2',
      const QuestionAnswer(questionId: 'q1', values: ['dev']),
    );

    expect(gateway.requestOf('request.answer')['params'], {
      'id': 'r2',
      'result': {
        'answers': {'q1': 'dev'},
      },
    });
  });

  test('sends a multi-select answer as a JSON list', () async {
    await transport.answerOpenRequest(
      'r2',
      const QuestionAnswer(
        questionId: 'q1',
        values: ['a and b'],
        multiSelect: true,
      ),
    );

    expect(gateway.requestOf('request.answer')['params'], {
      'id': 'r2',
      'result': {
        'answers': {'q1': '["a and b"]'},
      },
    });
  });

  test('reports a request that is gone as not accepted', () async {
    gateway.answerStatus = 'expired';

    expect(
      await transport.answerOpenRequest(
        'r1',
        const ApprovalChoiceAnswer('once'),
      ),
      isFalse,
    );
  });

  group('a request raised as an event frame', () {
    test(
      'an approval falls back to approval.respond on the resumed chat',
      () async {
        gateway.answerStatus = 'expired';

        final accepted = await transport.answerOpenRequest(
          'r1',
          const ApprovalChoiceAnswer('once'),
          threadId: 's1',
          profile: 'work',
        );

        expect(accepted, isTrue);
        expect(
          gateway.requestOf('session.resume')['params'],
          containsPair('session_id', 's1'),
        );
        expect(gateway.requestOf('approval.respond')['params'], {
          'session_id': 'rt-2',
          'request_id': 'r1',
          'choice': 'once',
        });
      },
    );

    test('a question without an id is answered with clarify.respond', () async {
      final accepted = await transport.answerOpenRequest(
        'r2',
        const QuestionAnswer(questionId: '', values: ['dev']),
        threadId: 's1',
      );

      expect(accepted, isTrue);
      expect(gateway.methods, isNot(contains('request.answer')));
      expect(gateway.requestOf('clarify.respond')['params'], {
        'request_id': 'r2',
        'answer': 'dev',
      });
    });

    test('an approval gone either way is not accepted', () async {
      gateway
        ..answerStatus = 'expired'
        ..approvalsResolved = 0;

      expect(
        await transport.answerOpenRequest(
          'r1',
          const ApprovalChoiceAnswer('once'),
          threadId: 's1',
        ),
        isFalse,
      );
    });

    test('nothing more is tried without the chat', () async {
      gateway.answerStatus = 'expired';

      await transport.answerOpenRequest(
        'r1',
        const ApprovalChoiceAnswer('once'),
      );

      expect(gateway.methods, isNot(contains('approval.respond')));
    });
  });
}
