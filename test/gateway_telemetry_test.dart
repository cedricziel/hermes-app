import 'dart:async';
import 'dart:convert';

import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/telemetry/gateway_telemetry.dart';

import 'support/recording_tracer.dart';

/// A socket whose server end is listened to, so closing the client's end
/// completes.
StreamChannelController<String> _wire() {
  final wire = StreamChannelController<String>();
  wire.foreign.stream.listen((_) {});
  return wire;
}

void main() {
  late RecordingTracer tracer;
  late GatewayTelemetry telemetry;
  late StreamChannelController<String> wire;
  late GatewayRpcClient client;

  setUp(() {
    tracer = RecordingTracer();
    telemetry = GatewayTelemetry(tracer);
    wire = _wire();
    client = GatewayRpcClient(wire.local, telemetry: telemetry);
  });

  tearDown(() => client.close());

  void answer(int id, Object result) => wire.foreign.sink.add(
    jsonEncode({'jsonrpc': '2.0', 'id': id, 'result': result}),
  );

  void event(String type) => wire.foreign.sink.add(
    jsonEncode({
      'jsonrpc': '2.0',
      'method': 'event',
      'params': {
        'type': type,
        'session_id': 'rt-secret',
        'payload': {'text': 'secret text'},
      },
    }),
  );

  Future<void> connected() =>
      telemetry.connecting(() async => wire.local, route: '/api/ws');

  RecordingSpan spanNamed(String name) =>
      tracer.spans.singleWhere((s) => s.name == name);

  group('the connection', () {
    test('is an HTTP client span for the upgrade', () async {
      await connected();

      final span = spanNamed('HTTP GET');
      expect(span.kind, SpanKind.client);
      expect(span.attributes, {
        'http.method': 'GET',
        'http.route': '/api/ws',
        'http.status_code': 101,
      });
      expect(span.status, StatusCode.ok);
      expect(span.ended, isTrue);
    });

    test('records a failed upgrade by error type and rethrows', () async {
      await expectLater(
        telemetry.connecting<void>(() async => throw StateError('nope')),
        throwsStateError,
      );

      final span = spanNamed('HTTP GET');
      expect(span.attributes['error.type'], 'StateError');
      expect(span.status, StatusCode.error);
      expect(span.ended, isTrue);
    });
  });

  group('a request', () {
    test('is a producer span, open until answered, linked to the '
        'connection', () async {
      await connected();
      final connection = spanNamed('HTTP GET');

      final reply = client.request('session.create', {'secret': 'params'});
      final span = spanNamed('session.create send');
      expect(span.kind, SpanKind.producer);
      expect(span.ended, isFalse);
      expect(span.links.single.context, connection.spanContext);
      expect(span.attributes, {
        'messaging.system': 'hermes.gateway',
        'messaging.operation.type': 'send',
        'messaging.destination.name': 'session.create',
        'messaging.message.id': '1',
        'rpc.system': 'jsonrpc',
        'rpc.jsonrpc.version': '2.0',
        'rpc.method': 'session.create',
      });

      answer(1, {'session_id': 'rt-secret'});
      await reply;

      expect(span.status, StatusCode.ok);
      expect(span.ended, isTrue);
    });

    test('a JSON-RPC error carries its code', () async {
      final reply = client.request('prompt.submit');
      wire.foreign.sink.add(
        jsonEncode({
          'id': 1,
          'error': {'code': 4009, 'message': 'session busy'},
        }),
      );
      await expectLater(reply, throwsA(isA<GatewayRpcException>()));

      final span = spanNamed('prompt.submit send');
      expect(span.attributes['rpc.jsonrpc.error_code'], 4009);
      expect(span.status, StatusCode.error);
      expect(span.ended, isTrue);
    });

    test('a socket that closes first fails the span by error type', () async {
      final reply = client.request('prompt.submit');
      unawaited(wire.foreign.sink.close());
      await expectLater(reply, throwsA(isA<GatewayConnectionClosed>()));

      final span = spanNamed('prompt.submit send');
      expect(span.attributes['error.type'], 'GatewayConnectionClosed');
      expect(span.status, StatusCode.error);
      expect(span.ended, isTrue);
    });
  });

  group('server events', () {
    test('are instant consumer spans linked to the connection', () async {
      await connected();

      event('tool.start');
      await pumpEventQueue();

      final span = spanNamed('tool.start receive');
      expect(span.kind, SpanKind.consumer);
      expect(span.ended, isTrue);
      expect(span.links.single.context, spanNamed('HTTP GET').spanContext);
      expect(span.attributes['messaging.operation.type'], 'receive');
    });

    test('leave out the per-chunk deltas', () async {
      event('message.delta');
      event('message.delta');
      await pumpEventQueue();

      expect(tracer.spans, isEmpty);
    });

    test('name an unfamiliar type "other"', () async {
      event('something.new');
      await pumpEventQueue();

      expect(
        spanNamed('other receive').attributes['messaging.destination.name'],
        'other',
      );
    });
  });

  test(
    'no span carries params, results, session ids or message text',
    () async {
      await connected();
      final reply = client.request('prompt.submit', {'text': 'secret text'});
      answer(1, {'session_id': 'rt-secret'});
      await reply;
      event('message.complete');
      await pumpEventQueue();

      final recorded = [
        for (final span in tracer.spans) ...[
          span.name,
          ...span.attributes.values.map((v) => '$v'),
        ],
      ].join(' ');
      expect(recorded, isNot(contains('secret')));
      expect(recorded, isNot(contains('rt-')));
    },
  );

  test('a broken tracer never breaks a request', () async {
    final broken = GatewayTelemetry(ThrowingTracer());
    final other = _wire();
    final brokenClient = GatewayRpcClient(other.local, telemetry: broken);
    addTearDown(brokenClient.close);

    final reply = brokenClient.request('session.create');
    other.foreign.sink.add(
      jsonEncode({
        'id': 1,
        'result': {'ok': true},
      }),
    );

    expect(await reply, {'ok': true});
    await broken.connecting(() async => 1);
  });

  test(
    'without a tracer nothing is recorded and requests still work',
    () async {
      final quiet = GatewayTelemetry();
      final other = _wire();
      final quietClient = GatewayRpcClient(other.local, telemetry: quiet);
      addTearDown(quietClient.close);

      final reply = quietClient.request('session.create');
      other.foreign.sink.add(
        jsonEncode({
          'id': 1,
          'result': {'ok': true},
        }),
      );

      expect(await reply, {'ok': true});
      expect(await quiet.connecting(() async => 7), 7);
    },
  );
}
