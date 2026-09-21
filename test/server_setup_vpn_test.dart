import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/screens/server_setup_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_network_signals.dart';
import 'support/memory_token_store.dart';

const _tailnetUrl = 'http://hermes-nowhere.tailtest.ts.net:9119';

void main() {
  late FakeNetworkSignals signals;

  setUp(() {
    // The widget test binding otherwise answers every HTTP request with 400.
    HttpOverrides.global = null;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    signals = FakeNetworkSignals();
  });

  tearDown(() => signals.close());

  Future<AuthController> pumpSetup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = AuthController(
      tokenStore: MemoryTokenStore(),
      networkSignals: signals,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: const MaterialApp(home: ServerSetupScreen()),
      ),
    );
    return auth;
  }

  Future<void> connectTo(
    WidgetTester tester,
    AuthController auth,
    String url,
  ) async {
    await tester.runAsync(() => auth.connect(url));
    await tester.pump();
  }

  testWidgets('shows the note about reaching a dashboard over a VPN', (
    tester,
  ) async {
    await pumpSetup(tester);

    expect(find.textContaining('Tailscale or WireGuard'), findsOneWidget);
    expect(find.textContaining('tailscale serve'), findsOneWidget);
    expect(find.text('Read the VPN setup guide'), findsOneWidget);
  });

  testWidgets('asks about the VPN after a tailnet host cannot be reached', (
    tester,
  ) async {
    final auth = await pumpSetup(tester);

    await connectTo(tester, auth, _tailnetUrl);

    expect(find.text('Could not reach $_tailnetUrl'), findsOneWidget);
    expect(find.text('Is your VPN connected?'), findsOneWidget);
  });

  testWidgets('says no VPN is active where the platform reports it', (
    tester,
  ) async {
    signals.vpnActive = false;
    final auth = await pumpSetup(tester);

    await connectTo(tester, auth, _tailnetUrl);

    expect(find.textContaining('No VPN is active on this device'), findsOne);
  });

  testWidgets('says a VPN is active but the server did not answer', (
    tester,
  ) async {
    signals.vpnActive = true;
    final auth = await pumpSetup(tester);

    await connectTo(tester, auth, _tailnetUrl);

    expect(find.textContaining('A VPN is active, but the server'), findsOne);
  });

  testWidgets('shows no hint for a public host', (tester) async {
    final closed = await tester.runAsync(
      () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    final url = 'http://127.0.0.1:${closed!.port}';
    await tester.runAsync(() => closed.close(force: true));
    final auth = await pumpSetup(tester);

    await connectTo(tester, auth, url);

    expect(find.text('Could not reach $url'), findsOneWidget);
    expect(find.textContaining('VPN is'), findsNothing);
    expect(find.text('Is your VPN connected?'), findsNothing);
  });

  testWidgets('attempts the connection when no VPN is active', (tester) async {
    signals.vpnActive = false;
    final auth = await pumpSetup(tester);

    await connectTo(tester, auth, _tailnetUrl);

    expect(auth.lastFailure, isNotNull);
  });
}
