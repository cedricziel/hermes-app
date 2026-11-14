import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/agent_work_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

List<Map<String, Object?>> sent(FakeGateway gateway, String method) => [
  for (final request in gateway.requests)
    if (request['method'] == method) request,
];

Map<String, Object?> paramsOf(Map<String, Object?> request) =>
    (request['params'] as Map).cast<String, Object?>();

void main() {
  const timeout = Duration(seconds: 2);

  late FakeGateway gateway;
  late HermesGatewayTransport transport;

  setUp(() {
    gateway = FakeGateway()
      ..turn = (g, sid) => g.event('message.complete', sid, {
        'text': 'ok',
        'status': 'complete',
      });
    transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
  });

  Future<void> attach() => transport.send(text: 'Hi', profile: 'work').toList();

  test('a read sends nothing and returns null when the session is not '
      'attached', () async {
    final answer = await transport.readAttached(
      'stored-1',
      profile: 'work',
      method: 'subagent.list',
      timeout: timeout,
    );
    expect(answer, isNull);
    expect(gateway.requests, isEmpty);
  });

  test('a read of an attached session carries the runtime id the transport '
      'chose, whatever the caller passes', () async {
    gateway.handlers['subagent.list'] = (_) => {
      'subagents': [],
      'delegations': [],
    };
    await attach();
    final answer = await transport.readAttached(
      'stored-1',
      profile: 'work',
      method: 'subagent.list',
      params: {'session_id': 'someone-elses', 'profile': 'work'},
      timeout: timeout,
    );
    expect(answer, {'subagents': [], 'delegations': []});
    final request = paramsOf(sent(gateway, 'subagent.list').single);
    expect(request['session_id'], 'rt-1');
    expect(sent(gateway, 'session.resume'), isEmpty);
  });

  test(
    'an action on an attached session sends once without resuming',
    () async {
      gateway.handlers['subagent.interrupt'] = (_) => {
        'found': true,
        'subagent_id': 'a1',
      };
      await attach();
      final resumes = sent(gateway, 'session.resume').length;
      await transport.act(
        'stored-1',
        profile: 'work',
        method: 'subagent.interrupt',
        params: {'subagent_id': 'a1'},
        timeout: timeout,
      );
      expect(sent(gateway, 'session.resume'), hasLength(resumes));
      final calls = sent(gateway, 'subagent.interrupt');
      expect(calls, hasLength(1));
      expect(paramsOf(calls.single), {
        'subagent_id': 'a1',
        'session_id': 'rt-1',
      });
    },
  );

  test('an action on a session not attached resumes first, then sends '
      'exactly once with the runtime id', () async {
    gateway.handlers['session.resume'] = (_) => {
      'session_id': 'rt-9',
      'stored_session_id': 'stored-1',
    };
    gateway.handlers['subagent.steer'] = (_) => {
      'status': 'queued',
      'subagent_id': 'a1',
      'text': 'x',
    };
    await transport.act(
      'stored-1',
      profile: 'work',
      method: 'subagent.steer',
      params: {'subagent_id': 'a1', 'text': 'x'},
      timeout: timeout,
    );
    final order = [
      for (final request in gateway.requests)
        if (request['method'] == 'session.resume' ||
            request['method'] == 'subagent.steer')
          request['method'],
    ];
    expect(order, ['session.resume', 'subagent.steer']);
    expect(
      paramsOf(sent(gateway, 'session.resume').single)['source'],
      'hermes_app',
    );
    expect(
      paramsOf(sent(gateway, 'subagent.steer').single)['session_id'],
      'rt-9',
    );
  });

  test('an answer that does not come abandons the call and keeps the socket, '
      'and nothing is resent', () async {
    await attach();
    gateway.silent.add('subagent.interrupt');
    await expectLater(
      transport.act(
        'stored-1',
        profile: 'work',
        method: 'subagent.interrupt',
        params: {'subagent_id': 'a1'},
        timeout: const Duration(milliseconds: 50),
      ),
      throwsA(isA<GatewayRequestTimeout>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(sent(gateway, 'subagent.interrupt'), hasLength(1));
    expect(transport.ownedSessionFor('stored-1', profile: 'work'), isNotNull);
    gateway.silent.clear();
    gateway.handlers['subagent.list'] = (_) => {'subagents': []};
    expect(
      await transport.readAttached(
        'stored-1',
        profile: 'work',
        method: 'subagent.list',
        timeout: timeout,
      ),
      {'subagents': []},
    );
  });

  test(
    'a 4001 on a read is thrown as is and leaves the attachment alone',
    () async {
      await attach();
      gateway.handlers['subagent.tail'] = (_) => throw const FakeRpcError(
        4001,
        'session not found or not owned by this transport',
      );
      await expectLater(
        transport.readAttached(
          'stored-1',
          profile: 'work',
          method: 'subagent.tail',
          params: {'subagent_id': 'a1'},
          timeout: timeout,
        ),
        throwsA(isA<GatewayRpcException>().having((e) => e.code, 'code', 4001)),
      );
      expect(transport.ownedSessionFor('stored-1', profile: 'work'), isNotNull);
    },
  );

  test('only the four subagent methods can be called, each as a read or an '
      'action', () async {
    await attach();
    final before = gateway.requests.length;
    for (final method in [
      'process.stop',
      'delegation.pause',
      'subagent.steer',
    ]) {
      expect(
        () => transport.readAttached(
          'stored-1',
          profile: 'work',
          method: method,
          timeout: timeout,
        ),
        throwsArgumentError,
        reason: method,
      );
    }
    for (final method in ['process.stop', 'subagent.list']) {
      expect(
        () => transport.act(
          'stored-1',
          profile: 'work',
          method: method,
          timeout: timeout,
        ),
        throwsArgumentError,
        reason: method,
      );
    }
    expect(gateway.requests, hasLength(before));
  });

  test('a read cut off by the connection closing is not returned', () async {
    await attach();
    gateway.silent.add('subagent.list');
    final read = transport.readAttached(
      'stored-1',
      profile: 'work',
      method: 'subagent.list',
      timeout: timeout,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await transport.close();
    await expectLater(read, throwsA(anything));
  });

  test(
    'after an action resumed the session, a read sees it attached',
    () async {
      gateway.handlers['session.resume'] = (_) => {
        'session_id': 'rt-9',
        'stored_session_id': 'stored-1',
      };
      gateway.handlers['subagent.interrupt'] = (_) => {'found': false};
      gateway.handlers['subagent.list'] = (_) => {'subagents': []};
      await transport.act(
        'stored-1',
        profile: 'work',
        method: 'subagent.interrupt',
        params: {'subagent_id': 'a1'},
        timeout: timeout,
      );
      final list = await transport.readAttached(
        'stored-1',
        profile: 'work',
        method: 'subagent.list',
        timeout: timeout,
      );
      expect(list, {'subagents': []});
      expect(
        paramsOf(sent(gateway, 'subagent.list').single)['session_id'],
        'rt-9',
      );
      // A second action reuses the attachment instead of resuming again.
      await transport.act(
        'stored-1',
        profile: 'work',
        method: 'subagent.interrupt',
        params: {'subagent_id': 'a2'},
        timeout: timeout,
      );
      expect(sent(gateway, 'session.resume'), hasLength(1));
    },
  );

  test('actions started together attach the session once', () async {
    gateway.handlers['subagent.interrupt'] = (_) => {'found': true};
    await Future.wait([
      for (final id in ['a1', 'a2'])
        transport.act(
          'stored-1',
          profile: 'work',
          method: 'subagent.interrupt',
          params: {'subagent_id': id},
          timeout: timeout,
        ),
    ]);
    expect(sent(gateway, 'session.resume'), hasLength(1));
    expect(sent(gateway, 'subagent.interrupt'), hasLength(2));
  });

  test('a resume that is not answered fails as not sent and keeps the '
      'socket; no action goes out', () async {
    await transport.close();
    transport = HermesGatewayTransport(
      connect: gateway.connect,
      requestTimeout: const Duration(milliseconds: 50),
    );
    addTearDown(transport.close);
    gateway.silent.add('session.resume');
    await expectLater(
      transport.act(
        'stored-1',
        profile: 'work',
        method: 'subagent.steer',
        params: {'subagent_id': 'a1', 'text': 'x'},
        timeout: timeout,
      ),
      throwsA(isA<AgentActionNotSent>()),
    );
    expect(sent(gateway, 'subagent.steer'), isEmpty);
    gateway.silent.clear();
    gateway.handlers['subagent.steer'] = (_) => {'status': 'queued'};
    await transport.act(
      'stored-1',
      profile: 'work',
      method: 'subagent.steer',
      params: {'subagent_id': 'a1', 'text': 'x'},
      timeout: timeout,
    );
    // The same socket carried both calls.
    expect(sent(gateway, 'subagent.steer'), hasLength(1));
  });
}
