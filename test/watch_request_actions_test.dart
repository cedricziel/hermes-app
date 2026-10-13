import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/watch/watch_context.dart';
import 'package:hermes_app/src/watch/watch_request_actions.dart';

import 'support/fake_gateway.dart';
import 'support/fake_chat_transport.dart';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late WatchRequestActions actions;
  var allowed = true;
  const scope = WatchContext('context', 4);
  final thread = const WatchThreadId('context', 'work', 'thread').encode();
  Map<Object?, Object?> request(
    String op, [
    Map<String, Object?> extra = const {},
  ]) => {
    'op': op,
    'contextId': 'context',
    'revision': 4,
    'threadId': thread,
    'requestId': 'r',
    'requestEpoch': 0,
    ...extra,
  };

  setUp(() {
    allowed = true;
    gateway = FakeGateway();
    transport = HermesGatewayTransport(connect: gateway.connect);
    gateway.handlers['session.active_list'] = (_) => {
      'sessions': [
        {'session_key': 'thread', 'id': 'runtime', 'status': 'waiting'},
      ],
    };
    gateway.handlers['approval.pending'] = (_) => {
      'approvals': [
        {
          'request_id': 'r',
          'command': 'echo demo',
          'choices': ['once', 'deny'],
        },
      ],
    };
    actions = WatchRequestActions(
      context: () => scope,
      allowed: () => allowed,
      transport: () => HermesGatewayTransport(connect: gateway.connect),
    );
  });
  tearDown(() => transport.close());
  Future<Map<Object?, Object?>> answer(Map<String, Object?> fields) async {
    final details = await actions.handle(request('request_details'));
    return request('request_answer', {
      'fingerprint': details['fingerprint'],
      ...fields,
    });
  }

  test('details require exact identity and fail closed under lock', () async {
    expect(
      (await actions.handle({
        ...request('request_details'),
        'revision': 3,
      }))['error'],
      'context_changed',
    );
    allowed = false;
    expect(
      (await actions.handle(request('request_details')))['error'],
      'locked',
    );
    expect(gateway.requests, isEmpty);
  });

  test('approval validates current full command and offered choice', () async {
    expect(
      (await actions.handle(request('request_details')))['command'],
      'echo demo',
    );
    expect(
      (await actions.handle(
        request('request_answer', {'choice': 'always', 'command': 'echo demo'}),
      ))['error'],
      'unavailable',
    );
    expect(
      (await actions.handle(
        request('request_answer', {'choice': 'once', 'command': 'other'}),
      ))['error'],
      'unavailable',
    );
    expect(gateway.methods, isNot(contains('request.answer')));
    expect(
      (await actions.handle(
        await answer({'choice': 'once', 'command': 'echo demo'}),
      ))['status'],
      'accepted',
    );
    expect(gateway.requestOf('request.answer')['params'], {
      'id': 'r',
      'result': {'choice': 'once'},
      'profile': 'work',
    });
  });

  test('gate is rechecked after current approval lookup', () async {
    gateway.handlers['approval.pending'] = (_) {
      allowed = false;
      return {
        'approvals': [
          {
            'request_id': 'r',
            'command': 'echo demo',
            'choices': ['once'],
          },
        ],
      };
    };
    expect(
      (await actions.handle(
        await answer({'choice': 'once', 'command': 'echo demo'}),
      ))['error'],
      'locked',
    );
    expect(gateway.methods, isNot(contains('request.answer')));
  });

  test(
    'uncertain acknowledgement never automatically sends another answer',
    () async {
      gateway.handlers['request.answer'] = (_) =>
          throw const FakeRpcError(-32000);
      final payload = await answer({'choice': 'deny', 'command': 'echo demo'});
      expect((await actions.handle(payload))['status'], 'uncertain');
      expect((await actions.handle(payload))['status'], 'uncertain');
      expect(
        gateway.methods.where((method) => method == 'request.answer'),
        hasLength(1),
      );
    },
  );

  test(
    'open-ended question encodes qid through shared request answer',
    () async {
      actions.observe(
        scope,
        'work',
        'thread',
        transport,
        const ClarifyRequested(
          ClarifyRequest(
            requestId: 'r',
            questions: [ClarifyQuestion(qid: 'q', question: 'Explain?')],
          ),
        ),
      );
      expect(
        (await actions.handle(
          request('request_answer', {
            'qid': 'q',
            'values': ['  '],
          }),
        ))['error'],
        'unavailable',
      );
      expect(
        (await actions.handle(
          await answer({
            'qid': 'q',
            'values': ['Keep backups'],
          }),
        ))['status'],
        'accepted',
      );
      expect(gateway.requestOf('request.answer')['params'], {
        'id': 'r',
        'result': {
          'answers': {'q': 'Keep backups'},
        },
        'profile': 'work',
      });
      expect(gateway.methods, isNot(contains('prompt.submit')));
    },
  );

  for (final event in <ChatEvent>[
    const ReplyDelta('Resumed'),
    const ToolStarted(name: 'preview'),
  ]) {
    test(
      'continuation ${event.runtimeType} expires only the sole owning request',
      () async {
        const clarify = ClarifyRequested(
          ClarifyRequest(
            requestId: 'r',
            questions: [ClarifyQuestion(qid: 'q', question: 'Continue?')],
          ),
        );
        actions.observe(scope, 'work', 'thread', transport, clarify);
        final payload = await answer({
          'qid': 'q',
          'values': ['Continue'],
        });
        actions.observe(scope, 'work', 'thread', transport, event);
        expect(
          (await actions.handle(request('request_details')))['kind'],
          isNot('question'),
        );
        expect((await actions.handle(payload))['error'], 'unavailable');
        expect(gateway.methods, isNot(contains('request.answer')));
        expect(gateway.methods, isNot(contains('clarify.lock')));
      },
    );
  }

  test(
    'continuation from an old owner preserves the replacement request',
    () async {
      final old = HermesGatewayTransport(connect: gateway.connect);
      const clarify = ClarifyRequested(
        ClarifyRequest(
          requestId: 'r',
          questions: [ClarifyQuestion(qid: 'q', question: 'Continue?')],
        ),
      );
      actions.observe(scope, 'work', 'thread', old, clarify);
      actions.observe(scope, 'work', 'thread', transport, clarify);
      actions.observe(
        scope,
        'work',
        'thread',
        old,
        const ReplyDelta('Old continuation'),
      );
      expect(
        (await actions.handle(request('request_details')))['kind'],
        'question',
      );
      await old.close();
    },
  );

  test(
    'continuation preserves multiple requests on the owning transport',
    () async {
      actions.observe(
        scope,
        'work',
        'thread',
        transport,
        const ClarifyRequested(
          ClarifyRequest(
            requestId: 'r',
            questions: [ClarifyQuestion(qid: 'q', question: 'Continue?')],
          ),
        ),
      );
      actions.observe(
        scope,
        'work',
        'thread',
        transport,
        const ClarifyRequested(
          ClarifyRequest(
            requestId: 'other',
            questions: [
              ClarifyQuestion(qid: 'other-q', question: 'Another question?'),
            ],
          ),
        ),
      );
      actions.observe(
        scope,
        'work',
        'thread',
        transport,
        const ToolPreparing('preview'),
      );
      expect(
        (await actions.handle(request('request_details')))['kind'],
        'question',
      );
    },
  );

  test('late expiry from replaced owner preserves current request', () async {
    final old = HermesGatewayTransport(connect: gateway.connect);
    const event = ClarifyRequested(
      ClarifyRequest(
        requestId: 'r',
        questions: [ClarifyQuestion(qid: 'q', question: 'Current question?')],
      ),
    );
    actions.observe(scope, 'work', 'thread', old, event);
    actions.observe(scope, 'work', 'thread', transport, event);
    actions.observe(
      scope,
      'work',
      'thread',
      old,
      const InputRequestExpired('r'),
    );
    expect(
      (await actions.handle(request('request_details')))['kind'],
      'question',
    );
    await old.close();
  });

  test(
    'accepted batch details retain exact submitted fingerprint proof',
    () async {
      final owner = FakeChatTransport();
      actions.observe(
        scope,
        'work',
        'thread',
        owner,
        const ClarifyRequested(
          ClarifyRequest(
            requestId: 'r',
            batch: true,
            questions: [
              ClarifyQuestion(
                qid: 'q1',
                question: 'First?',
                choices: ['First'],
              ),
              ClarifyQuestion(
                qid: 'q2',
                question: 'Second?',
                choices: ['Second'],
              ),
            ],
          ),
        ),
      );
      final original = await actions.handle(request('request_details'));
      final result = await actions.handle(
        request('request_answer', {
          'fingerprint': original['fingerprint'],
          'qid': 'q1',
          'values': ['First'],
        }),
      );
      expect(result['status'], 'accepted');
      final checked = await actions.handle(request('request_details'));
      expect(checked['accepted'], ['q1']);
      expect(checked['acceptedFingerprints'], {'q1': original['fingerprint']});
      expect(checked['fingerprint'], isNot(original['fingerprint']));
      expect(owner.clarifyAnswers, hasLength(1));
    },
  );

  test('expired details preserve captured request access epoch', () async {
    gateway.handlers['approval.pending'] = (_) => {'approvals': []};
    final result = await actions.handle(request('request_details'));
    expect(result['status'], 'expired');
    expect(result['requestEpoch'], 0);
  });

  test(
    'withdrawal removes question details and drafts are never persisted',
    () async {
      actions.observe(
        scope,
        'work',
        'thread',
        transport,
        const ClarifyRequested(
          ClarifyRequest(
            requestId: 'r',
            batch: true,
            questions: [
              ClarifyQuestion(
                qid: 'q',
                question: 'Pick?',
                choices: ['red', 'blue'],
              ),
            ],
          ),
        ),
      );
      expect(
        (await actions.handle(request('request_details')))['kind'],
        'question',
      );
      actions.observe(
        scope,
        'work',
        'thread',
        transport,
        const InputRequestExpired('r'),
      );
      expect(
        (await actions.handle(request('request_details')))['kind'],
        isNot('question'),
      );
    },
  );
}
