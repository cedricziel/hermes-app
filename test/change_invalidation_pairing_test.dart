import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/messaging/hermes_messaging_repository.dart';
import 'package:hermes_app/src/messaging/telegram_pairing_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_change_feed.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_session_auth.dart';

void main() {
  const start = '/api/messaging/telegram/onboarding/start';
  const status = '/api/messaging/telegram/onboarding/p1';
  late FakeHermesServer server;
  late FakeChangeFeed feed;
  late FakeSessionAuth auth;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('POST', start, telegramPairingStartBody())
      ..on('GET', status, {'status': 'waiting'})
      ..on('DELETE', status, {'ok': true});
    feed = FakeChangeFeed();
    auth = FakeSessionAuth();
  });
  tearDown(() async {
    auth.dispose();
    await feed.close();
  });
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump();
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp(
          home: TelegramPairingScreen(
            repository: HermesMessagingRepository(
              server.client().raw,
              profile: 'work',
            ),
            changeSource: feed,
            pollInterval: const Duration(days: 1),
            launchLink: (_) async => true,
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  testWidgets(
    'only the active known pairing is read and claimed drafts survive later hints',
    (tester) async {
      final started = Completer<FakeResponse>();
      server.onRequest('POST', start, (_) => started.future);
      await open(tester);
      feed.hint('pairing.changed');
      await settle(tester);
      expect(server.requestsTo('GET', status), isEmpty);
      server.on('GET', status, {
        'status': 'ready',
        'bot_username': 'SyntheticBot',
        'owner_user_id': '1234',
      });
      started.complete((status: 200, body: telegramPairingStartBody()));
      await settle(tester);
      expect(server.requestsTo('GET', status), hasLength(1));
      expect(find.text('1234'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '5678');
      feed.hint('pairing.changed');
      await settle(tester);
      expect(server.requestsTo('GET', status), hasLength(1));
      expect(find.text('5678'), findsOneWidget);
      await close(tester);
    },
  );
  testWidgets(
    'a retired physical connection cannot claim the current pairing',
    (tester) async {
      await open(tester);
      final before = feed.current!;
      feed.current = Object();
      server.on('GET', status, {'status': 'ready', 'owner_user_id': '1234'});
      feed.hint('pairing.changed', connection: before);
      await settle(tester);
      expect(server.requestsTo('GET', status), isEmpty);
      expect(find.byType(TextFormField), findsNothing);
      await close(tester);
    },
  );
}
