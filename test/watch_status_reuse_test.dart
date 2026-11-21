import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/watch/watch_bridge.dart';
import 'package:hermes_app/src/watch/watch_context.dart';
import 'package:hermes_app/src/watch/watch_request_handler.dart';
import 'package:hermes_app/src/watch/watch_status_source.dart';

import 'support/fake_gateway.dart';
import 'support/fake_hermes_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const context = WatchContext('owned', 1);
  late FakeHermesServer server;
  late FakeGateway gateway;
  late WatchRequestHandler handler;
  late int connections;
  late int closedByClient;

  void build(Duration idle, {Duration budget = const Duration(seconds: 2)}) {
    handler = WatchRequestHandler(
      context: () => context,
      repository: () => HermesChatRepository(server.client().raw),
      transport: () => null,
      activeProfile: () async => 'work',
      now: () => DateTime.utc(2026),
      statusBudget: budget,
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

  // Bounded, so a regression is an assertion rather than a 30 s timeout.
  Future<void> closed() =>
      gateway.closedByClient.timeout(const Duration(seconds: 2));

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
    await closed();
    await pumpEventQueue();
    expect(closedByClient, 1);
    await refresh();
    expect(connections, 2);
  });

  test('a dropped connection is replaced on the next refresh', () async {
    await refresh();
    await refresh();
    gateway.drop();
    await pumpEventQueue();
    await refresh();
    await refresh();
    expect(connections, 2);
  });

  test('an idle connection is closed after the idle timeout', () async {
    build(const Duration(milliseconds: 20));
    await refresh();
    await closed();
    await refresh();
    expect(connections, 2);
  });

  test('a read past the budget closes the connection; the next refresh '
      'opens a new one', () async {
    build(const Duration(minutes: 5), budget: const Duration(milliseconds: 50));
    gateway.silent.add('session.active_list');
    await refresh();
    await closed();
    gateway.silent.clear();
    await refresh();
    expect(connections, 2);
  });

  test('disposing the bridge closes the held connection', () async {
    final bridge = WatchBridge(handler: handler);
    await refresh();
    bridge.dispose();
    await closed();
    expect(closedByClient, 1);
  });
}
