import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/providers/providers_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import 'fake_provider_backend.dart';
import 'providers_screen_rig.dart';

const _settle = ProvidersRig.settle;

/// An auth that can sign out and move to another server.
class _MovingAuth extends CatalogAuth {
  _MovingAuth(FakeProviderBackend backend) : super(server: backend.server);

  HermesConnectionState current = HermesConnectionState.ready;
  String url = 'https://hermes.example.com';

  @override
  HermesConnectionState get state => current;

  @override
  String? get baseUrl => url;

  void move({HermesConnectionState? to, String? server}) {
    if (to != null) current = to;
    if (server != null) url = server;
    notifyListeners();
  }
}

/// Sign-out and a server change close the screen and what is over it, stop
/// following sign-ins without cancelling them, and drop typed keys.
void main() {
  late FakeProviderBackend backend;
  late ProvidersRig rig;
  late _MovingAuth auth;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    backend = FakeProviderBackend();
    rig = ProvidersRig(backend: backend);
    auth = _MovingAuth(backend);
  });
  tearDown(() => auth.dispose());

  Future<void> pump(WidgetTester tester) => rig.pump(
    tester,
    pushed: true,
    providers: [ChangeNotifierProvider<AuthController>.value(value: auth)],
  );

  Future<TextEditingController> typeKey(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('provider-row-openrouter')));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'sk-or-v1-test-aaaa-4f2a');
    await tester.pump();
    return tester.widget<TextField>(find.byType(TextField)).controller!;
  }

  for (final (name, change) in <(String, void Function())>[
    ('signing out', () => auth.move(to: HermesConnectionState.needsLogin)),
    (
      'changing the server',
      () => auth.move(server: 'https://other.example.net'),
    ),
  ]) {
    testWidgets('$name closes the screen and its form and drops the key', (
      tester,
    ) async {
      await pump(tester);
      final typed = await typeKey(tester);
      expect(typed.text, isNotEmpty);

      change();
      await _settle(tester);

      expect(find.byType(ProvidersScreen), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(typed.text, isEmpty);
      expect(backend.server.requestsTo('PUT', '/api/env'), isEmpty);
    });

    testWidgets('$name stops following a sign-in without cancelling it', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('provider-row-nous')));
      await _settle(tester);
      expect(find.textContaining('ABCD'), findsWidgets);
      await tester.pump(const Duration(seconds: 6));
      final polls = backend.server
          .requestsTo('GET', '/api/providers/oauth/nous/poll/s-1')
          .length;
      expect(polls, greaterThan(0));

      change();
      await _settle(tester);
      expect(find.byType(ProvidersScreen), findsNothing);
      await tester.pump(const Duration(seconds: 60));

      expect(
        backend.server
            .requestsTo('GET', '/api/providers/oauth/nous/poll/s-1')
            .length,
        polls,
      );
      expect(
        backend.server.requestsTo(
          'DELETE',
          '/api/providers/oauth/sessions/s-1',
        ),
        isEmpty,
      );
    });
  }

  testWidgets('closing the screen stops a sign-in without cancelling it', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('provider-row-nous')));
    await _settle(tester);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    // The row now waits, with Continue and Stop.
    expect(find.text('Waiting for sign-in…'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await _settle(tester);
    final polls = backend.server
        .requestsTo('GET', '/api/providers/oauth/nous/poll/s-1')
        .length;
    await tester.pump(const Duration(seconds: 60));

    expect(
      backend.server
          .requestsTo('GET', '/api/providers/oauth/nous/poll/s-1')
          .length,
      polls,
    );
    expect(
      backend.server.requestsTo('DELETE', '/api/providers/oauth/sessions/s-1'),
      isEmpty,
    );
  });
}
