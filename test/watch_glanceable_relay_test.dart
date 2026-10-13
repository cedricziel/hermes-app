import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/watch/watch_context.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_gateway.dart';

void main() {
  const context = WatchContext('owned', 1);
  late FakeHermesServer server;
  late FakeGateway gateway;
  late WatchRequestHandler handler;
  setUp(() {
    server = FakeHermesServer();
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([
        sessionRow(id: 'stored', title: 'Chat'),
        sessionRow(id: 'unknown', title: 'Other'),
      ]),
    );
    gateway = FakeGateway();
    handler = WatchRequestHandler(
      context: () => context,
      repository: () => HermesChatRepository(server.client().raw),
      transport: () => null,
      activeProfile: () async => 'work',
      now: () => DateTime.utc(2026),
      statusTransport: () =>
          HermesGatewayTransport(connect: () async => gateway.channel),
    );
  });
  test(
    'fresh profile and status correlate stored keys rather than live IDs',
    () async {
      gateway.handlers['session.active_list'] = (_) => {
        'sessions': [
          {'id': 'live', 'session_key': 'stored', 'status': 'running'},
          {'id': 'unknown', 'status': 'running'},
        ],
      };
      final result = await handler.handle({'op': 'threads', ...context.fields});
      final rows = (result['threads'] as List).cast<Map<String, Object?>>();
      expect(result['activeProfile'], 'work');
      expect(
        result['fetchedAt'],
        DateTime.utc(2026).millisecondsSinceEpoch ~/ 1000,
      );
      expect(rows.first['status'], 'running');
      expect(rows.last.containsKey('status'), isFalse);
      expect(gateway.requestOf('session.active_list')['params'], {
        'profile': 'work',
      });
    },
  );
  test(
    'unsupported optional status preserves readable chats and unknown status',
    () async {
      gateway.unknownMethods.add('session.active_list');
      final result = await handler.handle({'op': 'threads', ...context.fields});
      final rows = (result['threads'] as List).cast<Map<String, Object?>>();
      expect(result['ok'], isTrue);
      expect(rows, hasLength(2));
      expect(rows.first.containsKey('status'), isFalse);
      expect(rows.last.containsKey('status'), isFalse);
    },
  );
}
