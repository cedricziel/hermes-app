import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/watch/watch_context.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';
import 'package:hermes_app/src/watch/watch_status_source.dart';

import 'support/fake_gateway.dart';
import 'support/fake_hermes_server.dart';

void main() {
  const context = WatchContext('owned', 1);
  late FakeHermesServer server;
  late FakeGateway gateway;
  late WatchRequestHandler handler;
  late int connections;
  late int closedByClient;

  void build(Duration idle) {
    handler = WatchRequestHandler(
      context: () => context,
      repository: () => HermesChatRepository(server.client().raw),
      transport: () => null,
      activeProfile: () async => 'work',
      now: () => DateTime.utc(2026),
      statusSource: WatchStatusSource(
        () => HermesGatewayTransport(
          connect: () async {
            connections++;
            final channel = await gateway.connect();
            unawaited(gateway.closedByClient.then((_) => closedByClient++));
            return channel;
          },
        ),
        idleTimeout: idle,
      ),
    );
  }

  setUp(() {
    server = FakeHermesServer();
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([sessionRow(id: 'stored', title: 'Chat')]),
    );
    gateway = FakeGateway();
    gateway.handlers['session.active_list'] = (_) => {'sessions': []};
    connections = 0;
    closedByClient = 0;
    build(const Duration(minutes: 5));
  });

  Future<void> refresh() async {
    final result = await handler.handle({'op': 'threads', ...context.fields});
    expect(result['ok'], isTrue);
  }

  test('three list refreshes in a row open one gateway connection', () async {
    await refresh();
    await refresh();
    await refresh();
    expect(connections, 1);
  });

  test('sign-out or an owner change closes it; the next refresh opens a '
      'fresh one', () async {
    await refresh();
    handler.invalidateSession();
    await gateway.closedByClient;
    await pumpEventQueue();
    expect(closedByClient, 1);
    await refresh();
    expect(connections, 2);
  });

  test('a dropped connection is replaced on the next refresh', () async {
    await refresh();
    gateway.drop();
    await pumpEventQueue();
    await refresh();
    expect(connections, 2);
  });

  test('an idle connection is closed after the idle timeout', () async {
    build(const Duration(milliseconds: 20));
    await refresh();
    await gateway.closedByClient;
    await refresh();
    expect(connections, 2);
  });
}
