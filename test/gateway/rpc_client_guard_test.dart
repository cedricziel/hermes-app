import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/recording_tracer.dart';

void main() {
  test(
    'instrumentation retirement prevents sending and ends request span',
    () async {
      final wire = StreamChannelController<String>();
      final frames = <String>[];
      final subscription = wire.foreign.stream.listen(frames.add);
      final tracer = _RetiringTracer();
      final client = GatewayRpcClient(
        wire.local,
        telemetry: gatewayTracer(tracer),
      );
      addTearDown(client.close);
      addTearDown(subscription.cancel);
      await expectLater(
        client.requestGuarded(
          'connection.respond',
          const {},
          authorize: () => tracer.authorized,
        ),
        throwsA(isA<GatewayConnectionClosed>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(tracer.authorized, isFalse);
      expect(frames, isEmpty);
      expect(tracer.spans, isNotEmpty);
      expect(tracer.spans.every((span) => span.ended), isTrue);
    },
  );
  test(
    'already retired ownership never starts instrumentation or sends bytes',
    () async {
      final wire = StreamChannelController<String>();
      final frames = <String>[];
      final subscription = wire.foreign.stream.listen(frames.add);
      final tracer = RecordingTracer();
      final client = GatewayRpcClient(
        wire.local,
        telemetry: gatewayTracer(tracer),
      );
      addTearDown(client.close);
      addTearDown(subscription.cancel);
      await expectLater(
        client.requestGuarded(
          'connection.respond',
          const {},
          authorize: () => false,
        ),
        throwsA(isA<GatewayConnectionClosed>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(frames, isEmpty);
      expect(tracer.spans, isEmpty);
    },
  );
}

class _RetiringTracer extends RecordingTracer {
  bool authorized = true;
  @override
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Map<String, Object?>? attributes,
    SpanContext? parentContext,
    List<SpanLink> links = const [],
  }) {
    if (name == 'connection.respond send') authorized = false;
    return super.startSpan(
      name,
      kind: kind,
      attributes: attributes,
      parentContext: parentContext,
      links: links,
    );
  }
}
