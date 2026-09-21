import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/screens/server_setup_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_token_store.dart';

/// A gated dashboard whose `/api/auth/me` answers 503, so the stored-session
/// check fails without the tokens being rejected. With [statusFails] the
/// `/api/status` probe answers 503 as well.
Future<HttpServer> _startFlakyDashboard({bool statusFails = false}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) {
    final (status, body) = switch (request.uri.path) {
      '/api/status' when statusFails => (503, {'detail': 'unavailable'}),
      '/api/status' => (200, {'auth_required': true}),
      '/api/auth/providers' => (200, {'providers': <Object?>[]}),
      _ => (503, {'detail': 'unavailable'}),
    };
    request.response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body))
      ..close();
  });
  return server;
}

void main() {
  setUp(() {
    // The widget test binding otherwise answers every HTTP request with 400.
    HttpOverrides.global = null;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> pumpSetup(WidgetTester tester, AuthController auth) {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: const MaterialApp(home: ServerSetupScreen()),
      ),
    );
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('starts as http:// on a first launch', (tester) async {
    final auth = AuthController(tokenStore: MemoryTokenStore());
    await tester.runAsync(auth.bootstrap);

    await pumpSetup(tester, auth);

    expect(auth.state, HermesConnectionState.needsServerUrl);
    expect(fieldText(tester), 'http://');
  });

  testWidgets('is prefilled with the saved server after a failed session '
      'check', (tester) async {
    final dashboard = (await tester.runAsync(_startFlakyDashboard))!;
    addTearDown(() => dashboard.close(force: true));
    final url = 'http://127.0.0.1:${dashboard.port}';
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'hermes.server_base_url': url,
        });
    final auth = AuthController(
      tokenStore: MemoryTokenStore(
        const HermesSession(
          accessToken: 'a',
          refreshToken: 'r',
          expiresAt: 0,
          provider: 'oidc',
          userId: 'u1',
        ),
      ),
    );
    await tester.runAsync(auth.bootstrap);

    await pumpSetup(tester, auth);

    expect(auth.state, HermesConnectionState.connectionError);
    expect(fieldText(tester), url);
  });

  Future<void> restoreAndExpectSetupWith(
    WidgetTester tester,
    String url,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({
          'hermes.server_base_url': url,
        });
    final auth = AuthController(tokenStore: MemoryTokenStore());
    await tester.runAsync(auth.bootstrap);

    await pumpSetup(tester, auth);

    expect(auth.state, HermesConnectionState.connectionError);
    expect(fieldText(tester), url);
  }

  testWidgets('is prefilled with the saved server when the status probe '
      'fails', (tester) async {
    final dashboard = (await tester.runAsync(
      () => _startFlakyDashboard(statusFails: true),
    ))!;
    addTearDown(() => dashboard.close(force: true));

    await restoreAndExpectSetupWith(
      tester,
      'http://127.0.0.1:${dashboard.port}',
    );
  });

  testWidgets('is prefilled with the saved server when it is unreachable', (
    tester,
  ) async {
    final closed = (await tester.runAsync(_startFlakyDashboard))!;
    final url = 'http://127.0.0.1:${closed.port}';
    await tester.runAsync(() => closed.close(force: true));

    await restoreAndExpectSetupWith(tester, url);
  });
}
