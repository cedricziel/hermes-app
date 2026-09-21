import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:stream_channel/stream_channel.dart';

void main() {
  late StreamChannelController<String> wire;
  late GatewayRpcClient client;
  late List<Map<String, Object?>> sent;

  void serverSends(Map<String, Object?> message) =>
      wire.foreign.sink.add(jsonEncode({'jsonrpc': '2.0', ...message}));

  void serverEvent(
    String type, {
    String sessionId = 's1',
    Map<String, Object?>? payload,
  }) => serverSends({
    'method': 'event',
    'params': {'type': type, 'session_id': sessionId, 'payload': ?payload},
  });

  setUp(() {
    wire = StreamChannelController<String>();
    sent = [];
    wire.foreign.stream.listen(
      (frame) => sent.add(jsonDecode(frame) as Map<String, Object?>),
    );
    client = GatewayRpcClient(wire.local);
  });

  tearDown(() => client.close());

  test(
    'a request goes out as JSON-RPC 2.0 and resolves with the result',
    () async {
      final result = client.request('session.create', {'profile': 'work'});
      await pumpEventQueue();

      expect(sent.last, {
        'jsonrpc': '2.0',
        'id': isA<int>(),
        'method': 'session.create',
        'params': {'profile': 'work'},
      });
      serverSends({
        'id': sent.last['id'],
        'result': {'session_id': 'abc'},
      });

      expect(await result, {'session_id': 'abc'});
    },
  );

  test('responses are matched to their request by id, in any order', () async {
    final first = client.request('a');
    final second = client.request('b');
    await pumpEventQueue();
    final firstId = sent[0]['id'];
    final secondId = sent[1]['id'];
    expect(firstId, isNot(secondId));

    serverSends({
      'id': secondId,
      'result': {'who': 'b'},
    });
    serverSends({
      'id': firstId,
      'result': {'who': 'a'},
    });

    expect(await first, {'who': 'a'});
    expect(await second, {'who': 'b'});
  });

  test(
    'an error response fails the request with its code and message',
    () async {
      final result = client.request('session.resume', {'session_id': 'gone'});
      await pumpEventQueue();

      serverSends({
        'id': sent.last['id'],
        'error': {'code': 4007, 'message': 'session not found'},
      });

      await expectLater(
        result,
        throwsA(
          isA<GatewayRpcException>()
              .having((e) => e.code, 'code', 4007)
              .having((e) => e.message, 'message', 'session not found'),
        ),
      );
    },
  );

  test('events surface with their type, session and payload', () async {
    final events = <GatewayEvent>[];
    client.events.listen(events.add);

    serverEvent('message.delta', payload: {'text': 'Hel'});
    serverEvent('message.start', sessionId: 's2');
    await pumpEventQueue();

    expect(events.map((e) => e.type), ['message.delta', 'message.start']);
    expect(events.map((e) => e.sessionId), ['s1', 's2']);
    expect(events[0].payload, {'text': 'Hel'});
    expect(events[1].payload, isEmpty);
  });

  test(
    'closing the channel fails pending requests and ends the events',
    () async {
      final done = client.events.toList();
      final pending = client.request('prompt.submit');
      final failure = expectLater(
        pending,
        throwsA(isA<GatewayConnectionClosed>()),
      );
      await pumpEventQueue();

      await wire.foreign.sink.close();

      await failure;
      expect(await done, isEmpty);
    },
  );

  test('a request after the channel closed fails at once', () async {
    await wire.foreign.sink.close();
    await pumpEventQueue();

    await expectLater(
      client.request('session.create'),
      throwsA(isA<GatewayConnectionClosed>()),
    );
  });

  test('frames that are not JSON-RPC are ignored', () async {
    final result = client.request('ping');
    await pumpEventQueue();

    wire.foreign.sink.add('not json');
    wire.foreign.sink.add('[1, 2]');
    serverSends({'id': sent.last['id'], 'result': <String, Object?>{}});

    expect(await result, isEmpty);
  });
}
