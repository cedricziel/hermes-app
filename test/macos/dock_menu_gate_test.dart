import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/macos/dock/dock_menu_bridge.dart';
import 'package:hermes_app/src/macos/dock/dock_menu_controller.dart';
import 'package:hermes_app/src/macos/dock/dock_menu_gate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_device_authenticator.dart';
import '../support/fake_dock_menu_bridge.dart';
import '../support/local_dashboard.dart';
import '../support/memory_token_store.dart';

void main() {
  late AuthController auth;
  late AppLockController lock;
  late DockMenuController dock;
  late FakeDeviceAuthenticator authenticator;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    auth = AuthController(devServerUrl: '', tokenStore: MemoryTokenStore());
    authenticator = FakeDeviceAuthenticator();
    lock = AppLockController(authenticator: authenticator);
    dock = DockMenuController(
      bridge: DockMenuBridge(enabled: false),
      unlock: lock.unlock,
    );
    await auth.bootstrap();
    await lock.load();
  });

  tearDown(() {
    dock.dispose();
    lock.dispose();
    auth.dispose();
  });

  Future<void> pump(WidgetTester tester) => tester
      .pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<AppLockController>.value(value: lock),
            ChangeNotifierProvider<DockMenuController?>.value(value: dock),
          ],
          child: const DockMenuGate(child: SizedBox()),
        ),
      )
      .then((_) => tester.pump());

  /// Replaces [auth] with one connected to a local dashboard.
  Future<void> connect(WidgetTester tester) async {
    HttpOverrides.global = null;
    final dashboard = (await tester.runAsync(
      () => LocalDashboard.start({
        '/api/status': {'auth_required': false, 'version': 'test'},
      }),
    ))!;
    addTearDown(dashboard.close);
    auth.dispose();
    auth = AuthController(
      devServerUrl: dashboard.url,
      tokenStore: MemoryTokenStore(),
    );
    await tester.runAsync(auth.bootstrap);
    expect(auth.state, HermesConnectionState.ready);
  }

  testWidgets('is off while the connection is not ready', (tester) async {
    await pump(tester);

    expect(auth.state, isNot(HermesConnectionState.ready));
    expect(dock.state, DockMenuState.off);
  });

  testWidgets('follows the lock once the connection is ready', (tester) async {
    await connect(tester);
    await tester.runAsync(() => lock.setEnabled(true));
    lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
    await pump(tester);

    expect(dock.state, DockMenuState.locked);

    await tester.runAsync(lock.unlock);
    expect(dock.state, DockMenuState.ready);

    lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
    expect(dock.state, DockMenuState.locked);
  });

  testWidgets('a New Chat picked while locked shares the resume prompt and '
      'runs once the menu is ready', (tester) async {
    await connect(tester);
    await tester.runAsync(() => lock.setEnabled(true));
    lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
    final bridge = FakeDockMenuBridge();
    var newChats = 0;
    var stateWhenRun = DockMenuState.off;
    dock.dispose();
    dock = DockMenuController(bridge: bridge, unlock: lock.unlock)
      ..bind(
        Object(),
        open: (id, profile) async => DockOpenResult.inMain,
        newChat: () {
          newChats++;
          stateWhenRun = dock.state;
        },
      );
    await pump(tester);
    expect(dock.state, DockMenuState.locked);
    authenticator.reasons.clear();
    final prompt = Completer<bool>();
    authenticator.answer = prompt.future;

    // The window coming back starts a prompt; the Dock pick joins it.
    lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
    bridge.picks.add(const DockNewChat());
    await tester.pump();
    expect(newChats, 0);

    prompt.complete(true);
    await tester.pump();

    expect(authenticator.reasons, ['Unlock Hermes']);
    expect(newChats, 1);
    expect(stateWhenRun, DockMenuState.ready);
  });

  testWidgets('is off again after the user leaves the server', (tester) async {
    await connect(tester);
    await pump(tester);
    expect(dock.state, DockMenuState.ready);

    await tester.runAsync(auth.changeServer);

    expect(dock.state, DockMenuState.off);
  });

  testWidgets('does nothing without a controller', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DockMenuController?>.value(value: null),
        ],
        child: const DockMenuGate(child: SizedBox()),
      ),
    );

    expect(find.byType(SizedBox), findsOneWidget);
  });
}
