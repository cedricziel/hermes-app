import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:stream_channel/stream_channel.dart';

void main() {
  late StreamChannelController<String> wire;
  late GatewayRpcClient client;
  late StreamSubscription<String> sent;
  late Completer<int> requested;

  setUp(() {
    wire = StreamChannelController<String>();
    client = GatewayRpcClient(wire.local);
    requested = Completer<int>();
    sent = wire.foreign.stream.listen((frame) {
      final id = (jsonDecode(frame) as Map<String, Object?>)['id'];
      if (id is int && !requested.isCompleted) requested.complete(id);
    });
  });

  tearDown(() async {
    await sent.cancel();
    await client.close();
  });

  Future<int> nextRequestId() => requested.future;

  void answer(Map<String, Object?> frame) =>
      wire.foreign.sink.add(jsonEncode({'jsonrpc': '2.0', ...frame}));

  test('A result that is not an object settles the request as empty', () async {
    final call = client.request('session.active_list', const {});
    final id = await nextRequestId();
    answer({
      'id': id,
      'result': ['not', 'an', 'object'],
    });

    expect(await call.timeout(const Duration(seconds: 1)), isEmpty);
  });

  test(
    'An error whose code is not a number settles the request as an error',
    () async {
      final call = client.request('session.active_list', const {});
      final id = await nextRequestId();
      answer({
        'id': id,
        'error': {'code': 'oops', 'message': 'bad'},
      });

      await expectLater(
        call.timeout(const Duration(seconds: 1)),
        throwsA(
          isA<GatewayRpcException>()
              .having((e) => e.code, 'code', 0)
              .having((e) => e.message, 'message', 'bad'),
        ),
      );
    },
  );

  test('An event whose payload is not an object arrives empty', () async {
    final event = client.events.first;
    answer({
      'method': 'event',
      'params': {'type': 'message.delta', 'session_id': 's1', 'payload': 'x'},
    });

    final seen = await event.timeout(const Duration(seconds: 1));
    expect(seen.type, 'message.delta');
    expect(seen.sessionId, 's1');
    expect(seen.payload, isEmpty);
  });
}
