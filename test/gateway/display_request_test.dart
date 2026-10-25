import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';
import '../support/recording_tracer.dart';

void main() {
  late FakeGateway gateway;
  late int connects;
  late HermesGatewayTransport transport;

  setUp(() {
    gateway = FakeGateway();
    connects = 0;
    transport = HermesGatewayTransport(
      connect: () {
        connects++;
        return gateway.connect();
      },
      requestTimeout: const Duration(milliseconds: 50),
    );
    gateway.handlers['display.status'] = (_) => {'running': true};
  });

  tearDown(() => transport.close());

  group('error data', () {
    test('an error answer keeps its data and reads data.code', () async {
      gateway.handlers['display.lease.acquire'] = (_) =>
          throw const FakeRpcError(5300, 'not the holder', {
            'code': 'viewer_mismatch',
          });

      final error = await transport
          .request('display.lease.acquire')
          .then<GatewayRpcException?>((_) => null)
          .catchError((Object e) => e as GatewayRpcException);

      expect(error, isNotNull);
      expect(error!.code, 5300);
      expect(error.data, {'code': 'viewer_mismatch'});
      expect(error.dataCode, 'viewer_mismatch');
    });

    test(
      'an error without data, or with a code that is no string, has none',
      () {
        expect(const GatewayRpcException(5300, 'x').data, isNull);
        expect(const GatewayRpcException(5300, 'x').dataCode, isNull);
        expect(
          const GatewayRpcException(5300, 'x', {'code': 7}).dataCode,
          isNull,
        );
      },
    );
  });

  group('a request that does not drop the connection on timeout', () {
    test('throws GatewayRequestTimeout and keeps the connection', () async {
      gateway.silent.add('display.thumbnail');

      await expectLater(
        transport.requestKeepingConnection(
          'display.thumbnail',
          const {},
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<GatewayRequestTimeout>()),
      );
      final answer = await transport.request('display.status');

      expect(answer['running'], isTrue);
      expect(connects, 1);
    });

    test('a late answer to the timed-out call is ignored', () async {
      gateway.silent.add('display.thumbnail');
      await expectLater(
        transport.requestKeepingConnection(
          'display.thumbnail',
          const {},
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<GatewayRequestTimeout>()),
      );

      gateway.replyTo(gateway.requestOf('display.thumbnail'), {
        'data_url': null,
      });
      await pumpEventQueue();

      expect((await transport.request('display.status'))['running'], isTrue);
      expect(connects, 1);
    });

    test('the default request still drops the connection on timeout', () async {
      gateway.silent.add('display.thumbnail');

      await expectLater(
        transport.request('display.thumbnail'),
        throwsA(isA<GatewayConnectionClosed>()),
      );
      await gateway.closedByClient;
      await transport.request('display.status');

      expect(connects, 2);
    });
  });

  test('a display call that times out does not cut a reply that is '
      'streaming', () async {
    String? runtime;
    gateway.turn = (g, sid) {
      runtime = sid;
      g.event('message.start', sid);
      g.event('message.delta', sid, {'text': 'Hel'});
    };
    gateway.silent.add('display.thumbnail');
    final events = <ChatEvent>[];
    final done = Completer<void>();
    transport
        .send(text: 'hi')
        .listen(events.add, onDone: done.complete, cancelOnError: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(runtime, isNotNull);

    await expectLater(
      transport.requestKeepingConnection('display.thumbnail', const {
        'profile': 'work',
      }, timeout: const Duration(milliseconds: 20)),
      throwsA(isA<GatewayRequestTimeout>()),
    );
    gateway.event('message.delta', runtime!, {'text': 'lo'});
    gateway.event('message.complete', runtime!, {
      'text': 'Hello',
      'status': 'complete',
    });
    await done.future.timeout(const Duration(seconds: 2));

    expect(events.whereType<ReplyDelta>().map((e) => e.text).join(), 'Hello');
    expect(events.last, isA<ReplyCompleted>());
    expect((events.last as ReplyCompleted).failed, isFalse);
    expect(connects, 1);
  });

  test('a connection that closes during a timed request fails it as closed '
      'and leaves no timer to fire later', () {
    fakeAsync((async) {
      final wire = StreamChannelController<String>();
      final client = GatewayRpcClient(wire.local);
      Object? error;
      client
          .requestWithin(
            'display.thumbnail',
            const {},
            timeout: const Duration(seconds: 10),
          )
          .then<void>((_) {}, onError: (Object e) => error = e);
      async.flushMicrotasks();

      wire.foreign.sink.close();
      async.flushMicrotasks();
      expect(error, isA<GatewayConnectionClosed>());

      async.elapse(const Duration(minutes: 1));
      expect(error, isA<GatewayConnectionClosed>());
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('a request that timed out is abandoned: its span ends and a late '
      'answer is ignored', () async {
    final wire = StreamChannelController<String>();
    final frames = <String>[];
    wire.foreign.stream.listen(frames.add);
    final tracer = RecordingTracer();
    final client = GatewayRpcClient(
      wire.local,
      telemetry: gatewayTracer(tracer),
    );
    addTearDown(client.close);

    await expectLater(
      client.requestWithin(
        'display.thumbnail',
        const {},
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(isA<GatewayRequestTimeout>()),
    );

    expect(tracer.spans, isNotEmpty);
    expect(tracer.spans.every((span) => span.ended), isTrue);
    wire.foreign.sink.add('{"jsonrpc":"2.0","id":1,"result":{}}');
    await pumpEventQueue();
    expect(client.isClosed, isFalse);
  });
}
