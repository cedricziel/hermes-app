import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/models/hermes_session.dart';

import '../support/fake_hermes_server.dart';
import '../support/local_dashboard.dart';
import '../support/memory_token_store.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// First launch to first chat: the whole app against a gated dashboard, with
/// a screenshot at every screen the user passes through.
void main() {
  late LocalDashboard dashboard;
  late Completer<HermesSession> browser;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    browser = Completer();
    dashboard = await LocalDashboard.start({
      '/api/status': {
        'auth_required': true,
        'auth_flows': ['native_pkce'],
        'version': '0.14.0',
      },
      '/api/auth/providers': {
        'providers': [
          {'name': 'oidc', 'display_name': 'Company SSO'},
        ],
      },
      '/api/auth/me': {
        'user_id': 'u1',
        'email': 'ada@example.com',
        'display_name': 'Ada Lovelace',
        'org_id': 'acme',
        'provider': 'oidc',
      },
      '/api/sessions': sessionListBody([
        sessionRow(id: 's1', title: 'Backup failure', lastActive: 1780000600),
        sessionRow(id: 's2', title: 'Release notes', lastActive: 1780000100),
      ]),
      '/api/dashboard/plugins': [
        {'name': 'kanban'},
      ],
    });
  });

  tearDown(() => dashboard.close());

  AuthController newAuth() => AuthController(
    tokenStore: MemoryTokenStore(),
    login: (baseUrl, {provider, httpClient, cancelled}) => browser.future,
  );

  Future<void> connect(WidgetTester tester, String url) async {
    await tester.enterText(find.byType(TextFormField), url);
    await tester.tap(find.text('Connect'));
    await tester.pump();
  }

  testWidgets('phone: setup, sign-in and first chat', (tester) async {
    final shots = ScreenshotRecorder('onboarding-phone');
    final auth = newAuth();
    await pumpWorkflowApp(tester, shots, auth: auth);

    await shots.capture(tester, 'splash');

    await tester.runAsync(auth.bootstrap);
    await tester.pumpAndSettle();
    expect(find.text('Connect to Hermes'), findsOneWidget);
    await shots.capture(tester, 'setup-empty');

    await connect(tester, 'http://127.0.0.1:1');
    await pumpUntilFound(tester, find.textContaining('Could not reach'));
    await shots.capture(tester, 'setup-unreachable');

    await connect(tester, dashboard.url);
    await pumpUntilFound(tester, find.text('Sign in with Company SSO'));
    await shots.capture(tester, 'login');

    await tester.tap(find.text('Sign in with Company SSO'));
    await tester.pump();
    await pumpUntilFound(tester, find.text('Continue in your browser…'));
    await shots.capture(tester, 'login-waiting-for-browser');

    browser.complete(
      HermesSession(
        accessToken: 'a',
        refreshToken: 'r',
        expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
        provider: 'oidc',
        userId: 'u1',
      ),
    );
    await pumpUntilFound(tester, find.textContaining('Hermes Agent'));
    await shots.capture(tester, 'chat-welcome');
    expect(auth.state, HermesConnectionState.ready);
    await letSocketsIdle(tester);
  });
}
