import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/models/auth_provider_info.dart';
import 'package:hermes_app/src/models/hermes_status.dart';
import 'package:hermes_app/src/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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

Future<void> _pumpLogin(WidgetTester tester, List<String> authFlows) async {
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
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
}

void main() {
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
}
