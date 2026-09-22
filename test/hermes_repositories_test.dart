import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/bots/bots_screen.dart';

import 'support/fake_hermes_server.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('forAuth is null while signed out', () {
    expect(HermesRepositories.forAuth(AuthController(), null), isNull);
  });

  testWidgets('a screen with no injected repository reads the provided one', (
    tester,
  ) async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/messaging/platforms',
        platformListBody([platformRow(id: 'telegram', name: 'Telegram')]),
      );
    await tester.pumpWidget(
      Provider<HermesRepositories?>.value(
        value: HermesRepositories(server.client()),
        child: const MaterialApp(home: BotsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Telegram'), findsOneWidget);
  });

  testWidgets('maybeOf is null with neither provider nor sign-in', (
    tester,
  ) async {
    HermesRepositories? found;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(),
        child: Builder(
          builder: (context) {
            found = HermesRepositories.maybeOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found, isNull);
  });
}
