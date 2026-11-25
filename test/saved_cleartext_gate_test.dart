import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/screens/saved_cleartext_gate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_hermes_server.dart';
import 'support/memory_token_store.dart';
import 'support/test_localizations.dart';
import 'support/wait_until.dart';

const _publicHttp = 'http://hermes.example.com';

void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on('GET', '/api/status', {'auth_required': false});
  });

  Future<AuthController> pumpGate(WidgetTester tester, String saved) async {
    await SharedPreferencesAsync().setString(kSavedServerUrlKey, saved);
    final transport = server.dio();
    addTearDown(transport.close);
    final auth = AuthController(
      tokenStore: MemoryTokenStore(),
      interceptors: [
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            try {
              handler.resolve(await transport.fetch<dynamic>(options), true);
            } on DioException catch (error) {
              handler.reject(error, true);
            }
          },
        ),
      ],
    );
    addTearDown(auth.dispose);
    await tester.runAsync(auth.bootstrap);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          home: const SavedCleartextGate(child: Scaffold(body: Text('home'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('asks once, and keeping http:// is remembered', (tester) async {
    final auth = await pumpGate(tester, _publicHttp);

    expect(find.text('Keep using http://?'), findsOneWidget);
    expect(find.textContaining('hermes.example.com is not'), findsOneWidget);

    await tester.tap(find.text('Keep http://'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {});

    expect(find.text('Keep using http://?'), findsNothing);
    expect(auth.unconfirmedCleartextServer, isNull);
    expect(
      await tester.runAsync(
        () => SharedPreferencesAsync().getStringList(
          kAcceptedCleartextServersKey,
        ),
      ),
      [_publicHttp],
    );
  });

  testWidgets('choosing https:// reconnects to the https address', (
    tester,
  ) async {
    final auth = await pumpGate(tester, _publicHttp);

    await tester.tap(find.text('Use https://'));
    await waitUntil(
      tester,
      () => auth.baseUrl == 'https://hermes.example.com',
      reason: 'the https reconnect',
    );
    await tester.pumpAndSettle();

    expect(auth.baseUrl, 'https://hermes.example.com');
    expect(find.text('Keep using http://?'), findsNothing);
  });

  testWidgets('does not ask about a local or encrypted server', (tester) async {
    await pumpGate(tester, 'http://192.168.1.20:9119');

    expect(find.text('Keep using http://?'), findsNothing);
  });

  testWidgets('does not ask while the server is unreachable', (tester) async {
    server.on('GET', '/api/status', {'detail': 'down'}, status: 503);
    final auth = await pumpGate(tester, _publicHttp);

    expect(auth.state, HermesConnectionState.connectionError);
    expect(auth.unconfirmedCleartextServer, _publicHttp);
    expect(find.text('Keep using http://?'), findsNothing);
  });
}
