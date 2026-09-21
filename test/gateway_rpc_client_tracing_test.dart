import 'dart:async';
import 'dart:convert';

import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:stream_channel/stream_channel.dart';

import 'support/recording_tracer.dart';

void main() {
  late RecordingTracer tracer;
  late StreamChannelController<String> wire;
  late GatewayRpcClient client;

  setUp(() {
    tracer = RecordingTracer();
    wire = StreamChannelController<String>();
    wire.foreign.stream.listen((_) {});
    client = GatewayRpcClient(wire.local, telemetry: gatewayTracer(tracer));
  });

  tearDown(() => client.close());

  void send(Map<String, Object?> frame) =>
      wire.foreign.sink.add(jsonEncode({'jsonrpc': '2.0', ...frame}));

  RecordingSpan spanNamed(String name) =>
      tracer.spans.singleWhere((s) => s.name == name);

  test('a request is a producer span until the gateway answers', () async {
    final reply = client.request('session.create', {'secret': 'params'});
    final span = spanNamed('session.create send');
    expect(span.kind, SpanKind.producer);
    expect(span.ended, isFalse);

    send({
      'id': 1,
      'result': {'session_id': 'rt-secret'},
    });
    await reply;

    expect(span.status, StatusCode.ok);
    expect(span.ended, isTrue);
  });

  test('a JSON-RPC error carries its code', () async {
    final reply = client.request('prompt.submit');
    send({
      'id': 1,
      'error': {'code': 4009, 'message': 'session busy'},
    });
    await expectLater(reply, throwsA(isA<GatewayRpcException>()));

    final span = spanNamed('prompt.submit send');
    expect(span.attributes['rpc.jsonrpc.error_code'], 4009);
    expect(span.status, StatusCode.error);
  });

  test('a socket that closes first fails the span', () async {
    final reply = client.request('prompt.submit');
    unawaited(wire.foreign.sink.close());
    await expectLater(reply, throwsA(isA<GatewayConnectionClosed>()));

    expect(
      spanNamed('prompt.submit send').attributes['error.type'],
      'GatewayConnectionClosed',
    );
  });

  test('events are consumer spans, deltas are left out', () async {
    send({
      'method': 'event',
      'params': {'type': 'message.delta', 'session_id': 'rt-secret'},
    });
    send({
      'method': 'event',
      'params': {'type': 'tool.start', 'session_id': 'rt-secret'},
    });
    await pumpEventQueue();

    expect(tracer.spans.map((s) => s.name), ['tool.start receive']);
    expect(spanNamed('tool.start receive').kind, SpanKind.consumer);
  });

  test('no span carries params, results, session ids or text', () async {
    final reply = client.request('prompt.submit', {'text': 'secret text'});
    send({
      'id': 1,
      'result': {'session_id': 'rt-secret'},
    });
    await reply;
    send({
      'method': 'event',
      'params': {
        'type': 'message.complete',
        'session_id': 'rt-secret',
        'payload': {'text': 'secret text'},
      },
    });
    await pumpEventQueue();

    final recorded = [
      for (final span in tracer.spans) ...[
        span.name,
        ...span.attributes.values.map((v) => '$v'),
      ],
    ].join(' ');
    expect(recorded, isNot(contains('secret')));
  });
}
