import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/verified_session_owner.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_device_authenticator.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_session_auth.dart';
import 'support/pump_chat.dart';

void main() {
  late FakeSessionAuth auth;
  late FakeChatTransport transport;
  late FakeHermesServer server;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    auth = FakeSessionAuth();
    transport = FakeChatTransport();
    server = FakeHermesServer()
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on('GET', '/api/profiles', profileListBody([profileRow(name: 'work')]))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored', title: 'Synthetic')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored/messages',
        messageListBody('stored', []),
      );
  });
  tearDown(() => auth.dispose());
  Future<void> mount(WidgetTester tester, {AppLockController? lock}) async {
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: transport,
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        if (lock != null)
          ChangeNotifierProvider<AppLockController>.value(value: lock),
      ],
    );
    await openThread(tester, 'Synthetic');
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(composerField, text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
  }

  testWidgets(
    'mounted chat stops stale events and retains typed input through expiry',
    (tester) async {
      await mount(tester);
      await send(tester, 'first');
      final interrupted = transport.sends.single;
      interrupted.emit(const ReplyDelta('Visible before expiry'));
      await tester.pump();
      auth.expire();
      interrupted.emit(const ReplyDelta('stale protected output'));
      await tester.pump();
      await send(tester, 'kept while expired');
      expect(transport.sends, hasLength(1));
      expect(find.textContaining('stale protected output'), findsNothing);
      expect(
        tester.widget<EditableText>(composerField).controller.text,
        'kept while expired',
      );
      auth.recover();
      await tester.pumpAndSettle();
      await send(tester, 'verified prompt');
      expect(transport.sends, hasLength(2));
      expect(transport.sends.last.profile, 'work');
      expect(transport.sends.last.text, 'verified prompt');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets(
    'a mounted old-owner chat cannot send after another owner signs in',
    (tester) async {
      await mount(tester);
      auth.expire();
      auth.recover(
        const VerifiedSessionOwner(
          server: 'https://queue.test',
          user: 'other',
          organization: '',
          provider: 'oidc',
        ),
      );
      await tester.pump();
      await send(tester, 'old owner draft');
      expect(transport.sends, isEmpty);
      expect(
        tester.widget<EditableText>(composerField).controller.text,
        'old owner draft',
      );
    },
  );

  testWidgets('app lock leaves existing reply activity running', (
    tester,
  ) async {
    final lock = AppLockController(authenticator: FakeDeviceAuthenticator());
    addTearDown(lock.dispose);
    await mount(tester, lock: lock);
    await lock.load();
    await send(tester, 'first');
    await lock.setEnabled(true);
    lock.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(lock.covered, true);
    transport.sends.single.emit(const ReplyDelta('continues under lock'));
    await tester.pump();
    expect(find.textContaining('continues under lock'), findsOneWidget);
    expect(transport.sends, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });
}
