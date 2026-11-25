import 'dart:async';

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

  Future<AuthController> pumpGate(
    WidgetTester tester,
    String saved, {
    bool httpsDown = false,
    Future<void>? httpsGate,
  }) async {
    await SharedPreferencesAsync().setString(kSavedServerUrlKey, saved);
    final transport = server.dio();
    addTearDown(transport.close);
    final auth = AuthController(
      tokenStore: MemoryTokenStore(),
      interceptors: [
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (httpsDown && options.uri.scheme == 'https') {
              handler.reject(
                DioException.connectionError(
                  requestOptions: options,
                  reason: 'no https listener',
                ),
                true,
              );
              return;
            }
            if (options.uri.scheme == 'https') await httpsGate;
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

  testWidgets('closing the dialog without a choice is no answer', (
    tester,
  ) async {
    final auth = await pumpGate(tester, _publicHttp);

    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();

    expect(find.text('Keep using http://?'), findsNothing);
    expect(auth.unconfirmedCleartextServer, _publicHttp);
    expect(auth.baseUrl, _publicHttp);
    expect(find.byType(SnackBar), findsNothing);

    // Any later change of the connection state must not reopen it.
    await tester.runAsync(auth.signOut);
    await tester.pumpAndSettle();
    expect(find.text('Keep using http://?'), findsNothing);
  });

  testWidgets('an answer after the connection ended changes nothing', (
    tester,
  ) async {
    final auth = await pumpGate(tester, _publicHttp);

    await tester.runAsync(auth.changeServer);
    await tester.tap(find.text('Use https://'));
    await tester.pumpAndSettle();

    expect(auth.baseUrl, isNull);
    expect(auth.state, HermesConnectionState.needsServerUrl);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('says so when https:// does not answer, and stays on http://', (
    tester,
  ) async {
    final auth = await pumpGate(tester, _publicHttp, httpsDown: true);

    await tester.tap(find.text('Use https://'));
    await waitUntil(
      tester,
      () => auth.unconfirmedCleartextServer == null,
      reason: 'the https probe',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("doesn't answer over https://"), findsOneWidget);
    expect(auth.baseUrl, _publicHttp);
    expect(auth.state, HermesConnectionState.ready);
  });

  testWidgets('shows that https:// is being checked, and stays quiet when the '
      'server changed meanwhile', (tester) async {
    final gate = Completer<void>();
    final auth = await pumpGate(tester, _publicHttp, httpsGate: gate.future);

    await tester.tap(find.text('Use https://'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Checking hermes.example.com over https://'),
      findsOneWidget,
    );

    await tester.runAsync(auth.changeServer);
    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
    expect(auth.baseUrl, isNull);
  });

  for (final answer in ['Keep http://', 'Use https://']) {
    testWidgets('"$answer" after the connection dropped changes nothing', (
      tester,
    ) async {
      final auth = await pumpGate(tester, _publicHttp);
      server.on('GET', '/api/status', {'detail': 'down'}, status: 503);

      await tester.runAsync(() => auth.connect(_publicHttp, automatic: true));
      expect(auth.state, HermesConnectionState.connectionError);
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle();

      expect(auth.unconfirmedCleartextServer, _publicHttp);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        await tester.runAsync(
          () => SharedPreferencesAsync().getStringList(
            kAcceptedCleartextServersKey,
          ),
        ),
        isNull,
      );
    });
  }
}
