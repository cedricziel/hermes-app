import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/models/auth_provider_info.dart';
import 'package:hermes_app/src/models/hermes_status.dart';
import 'package:hermes_app/src/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/accessibility.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._status);

  final HermesStatus _status;

  @override
  HermesConnectionState get state => HermesConnectionState.needsLogin;

  @override
  String? get baseUrl => 'http://hermes.test:9119';

  @override
  HermesStatus? get status => _status;

  @override
  List<AuthProviderInfo> get providers => const [
    AuthProviderInfo(
      name: 'oidc',
      displayName: 'Acme SSO',
      supportsPassword: false,
    ),
  ];
}

Future<void> _pumpLogin(
  WidgetTester tester,
  List<String> authFlows, [
  TargetPlatform? platform,
]) async {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthController>(
      create: (_) => _FakeAuthController(
        HermesStatus(
          authRequired: true,
          authProviders: const ['oidc'],
          authFlows: authFlows,
        ),
      ),
      child: MaterialApp(
        theme: ThemeData(platform: platform),
        home: const LoginScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('uses a 44pt bar on iOS and the Material bar elsewhere', (
    tester,
  ) async {
    await _pumpLogin(tester, const ['native_pkce'], TargetPlatform.iOS);
    expect(tester.getSize(find.byType(AppBar)).height, 44);

    await _pumpLogin(tester, const ['native_pkce'], TargetPlatform.android);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(AppBar)).height, 56);
  });

  testWidgets('scrolls instead of overflowing on a short screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _pumpLogin(tester, const ['native_pkce']);

    expect(tester.takeException(), isNull);
  });

  testWidgets('offers providers when the server supports native_pkce', (
    tester,
  ) async {
    await _pumpLogin(tester, const ['native_pkce']);

    expect(find.text('Sign in with Acme SSO'), findsOneWidget);
  });

  testWidgets('explains instead of offering providers when native_pkce is '
      'missing from the advertised flows', (tester) async {
    await _pumpLogin(tester, const ['cookie']);

    expect(find.text('Sign in with Acme SSO'), findsNothing);
    expect(find.textContaining("doesn't support app sign-in"), findsOneWidget);
  });

  testWidgets('still offers providers when the server advertises no flows', (
    tester,
  ) async {
    await _pumpLogin(tester, const []);

    expect(find.text('Sign in with Acme SSO'), findsOneWidget);
  });

  testWidgets('offers a way to report a bug', (tester) async {
    await _pumpLogin(tester, const ['native_pkce']);

    expect(find.text('Report a bug'), findsOneWidget);
  });

  testWidgets('screen readers get Change server by name', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpLogin(tester, const ['native_pkce']);

    expect(
      tester.getSemantics(find.byIcon(Icons.dns_outlined)),
      namedButton('Change server'),
    );
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
