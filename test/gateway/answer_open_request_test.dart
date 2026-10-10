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
}
