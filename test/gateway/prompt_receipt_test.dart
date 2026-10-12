import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  setUp(() {
    gateway = FakeGateway();
    gateway.turn = (g, sid) => g.event('message.complete', sid, {
      'text': 'reply',
      'status': 'complete',
    });
    transport = HermesGatewayTransport(connect: () async => gateway.channel);
  });
  tearDown(() => transport.close());
  test(
    'optional accepted row receipt preserves its integer backend type',
    () async {
      gateway.handlers['prompt.submit'] = (params) {
        unawaited(
          Future<void>(
            () => gateway.event(
              'message.complete',
              params['session_id'] as String,
              {'text': 'reply', 'status': 'complete'},
            ),
          ),
        );
        return {'status': 'accepted', 'user_row_id': 42};
      };
      final events = await transport.send(text: 'text').toList();
      expect(events.whereType<PromptAcknowledged>().single.userRowId, 42);
    },
  );
  test(
    'missing optional receipt leaves ordinary completion supported',
    () async {
      final events = await transport.send(text: 'text').toList();
      expect(events.whereType<PromptAcknowledged>(), isEmpty);
      expect(events.whereType<ReplyCompleted>(), hasLength(1));
    },
  );
}
