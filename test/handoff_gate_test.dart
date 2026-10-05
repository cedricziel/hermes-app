import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/handoff/handoff_activity.dart';
import 'package:hermes_app/src/handoff/handoff_bridge.dart';
import 'package:hermes_app/src/handoff/handoff_controller.dart';
import 'package:hermes_app/src/handoff/handoff_gate.dart';
import 'package:hermes_app/src/screens/server_setup_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_device_authenticator.dart';
import 'support/memory_token_store.dart';

void main() {
  late AuthController auth;
  late AppLockController lock;
  late HandoffController handoff;
  const target = HandoffActivity(
    'https://dashboard.example.test',
    'work',
    'saved',
  );
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    auth = AuthController(devServerUrl: '', tokenStore: MemoryTokenStore());
    lock = AppLockController(authenticator: FakeDeviceAuthenticator());
    handoff = HandoffController(HandoffBridge(enabled: false));
    await auth.bootstrap();
    await lock.load();
  });
  tearDown(() {
    handoff.dispose();
    lock.dispose();
    auth.dispose();
  });
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<AppLockController>.value(value: lock),
          ChangeNotifierProvider<HandoffController>.value(value: handoff),
        ],
        child: MaterialApp(
          home: HandoffGate(
            child: Builder(
              builder: (context) => ServerSetupScreen(
                initialUrl: context.watch<HandoffController>().setupUrl,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Connect retains the accepted target and prefills existing setup',
    (tester) async {
      handoff.receive(target.payload);
      await pump(tester);
      await tester.tap(find.text('Connect').last);
      await tester.pumpAndSettle();
      expect(handoff.pending?.threadId, 'saved');
      expect(find.text('https://dashboard.example.test'), findsOneWidget);
      expect(auth.state, HermesConnectionState.needsServerUrl);
    },
  );
  testWidgets('Cancel leaves setup and credentials unchanged', (tester) async {
    handoff.receive(target.payload);
    await pump(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(handoff.pending, isNull);
    expect(auth.userGeneration, 0);
    expect(auth.baseUrl, isNull);
  });
}
