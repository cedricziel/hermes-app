import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/gateway_connection_transport.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/messaging_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/fake_gateway.dart';
import 'support/fake_session_auth.dart';

class _Feed implements GatewayConnectionTransport {
  final frames = StreamController<GatewayConnectionEvent>.broadcast(sync: true);
  Object? current = Object();
  @override
  Stream<GatewayConnectionEvent> get connectionEvents => frames.stream;
  @override
  Object? get gatewayConnection => current;
  @override
  bool ownsGatewayConnection(Object connection) =>
      identical(connection, current);
  void hint() => frames.add(
    GatewayConnectionEvent.received(
      current!,
      const GatewayEvent(type: 'platforms.changed', sessionId: '', payload: {}),
    ),
  );
}

void main() {
  late FakeHermesServer server;
  late FakeSessionAuth auth;
  late _Feed feed;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    auth = FakeSessionAuth();
    feed = _Feed();
    server.on(
      'GET',
      '/api/messaging/platforms',
      platformListBody([
        platformRow(
          id: 'discord',
          name: 'Discord',
          configured: true,
          envVars: [
            envVarRow(key: 'DISCORD_ALLOWED_USERS', prompt: 'Allowed users'),
          ],
        ),
      ]),
      query: {'profile': 'work'},
    );
  });
  tearDown(() async {
    auth.dispose();
    await feed.frames.close();
  });
  Future<void> open(
    WidgetTester tester, [
    GatewayConnectionTransport? source,
  ]) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp(
          home: MessagingScreen(
            repository: HermesMessagingRepository(
              server.client().raw,
              profile: 'work',
            ),
            changeSource: source ?? feed,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int getReads() => server.requestsTo('GET', '/api/messaging/platforms').length;

  testWidgets(
    'an empty-runtime actual gateway broadcast refreshes the generated-client list',
    (tester) async {
      late FakeGateway gateway;
      late HermesGatewayTransport transport;
      await tester.runAsync(() async {
        gateway = FakeGateway();
        gateway.turn = (server, session) => server.event(
          'message.complete',
          session,
          {'text': 'Main answer', 'status': 'complete'},
        );
        transport = HermesGatewayTransport(connect: gateway.connect);
        await transport
            .send(text: 'Synthetic prompt', profile: 'work')
            .toList()
            .timeout(const Duration(seconds: 5));
      });
      addTearDown(transport.close);
      final requests = gateway.requests.length;
      await open(tester, transport);
      expect(getReads(), 1);
      server.on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([
          platformRow(
            id: 'discord',
            name: 'Externally renamed',
            configured: true,
          ),
        ]),
        query: {'profile': 'work'},
      );
      expect(transport.gatewayConnection, isNotNull);
      await tester.runAsync(() async {
        gateway.event('platforms.changed', '', {});
        await pumpEventQueue();
      });
      await tester.pumpAndSettle();
      expect(getReads(), 2);
      expect(find.text('Externally renamed'), findsOneWidget);
      expect(gateway.requests, hasLength(requests));
    },
  );

  testWidgets(
    'a covered setup form retains its draft and consumes the dirty hint on return',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Discord'));
      await tester.pumpAndSettle();
      expect(find.text('Save'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'Synthetic unsaved draft',
      );
      feed.hint();
      await tester.pumpAndSettle();
      expect(getReads(), 1);
      expect(find.text('Synthetic unsaved draft'), findsOneWidget);
      final context = tester.element(find.text('Save'));
      Navigator.of(context).pop(false);
      await tester.pumpAndSettle();
      expect(getReads(), 2);
      expect(find.text('Discord'), findsOneWidget);
    },
  );

  testWidgets(
    'expiry suppresses automatic reads until the same verified owner returns',
    (tester) async {
      await open(tester);
      auth.expire();
      feed.hint();
      await tester.pumpAndSettle();
      expect(getReads(), 1);
      auth.recover();
      feed.hint();
      await tester.pumpAndSettle();
      expect(getReads(), 2);
    },
  );
}
