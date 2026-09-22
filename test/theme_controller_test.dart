import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_device_authenticator.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('follows the system until a choice is made', () async {
    final controller = ThemeController();
    await controller.load();

    expect(controller.mode, ThemeMode.system);
  });

  test('keeps the chosen mode across launches', () async {
    await ThemeController().setMode(ThemeMode.dark);

    final relaunched = ThemeController();
    await relaunched.load();

    expect(relaunched.mode, ThemeMode.dark);
  });

  test('going back to system is remembered too', () async {
    final controller = ThemeController();
    await controller.setMode(ThemeMode.light);
    await controller.setMode(ThemeMode.system);

    final relaunched = ThemeController();
    await relaunched.load();

    expect(relaunched.mode, ThemeMode.system);
  });

  test('ignores a saved value it does not know', () async {
    await SharedPreferencesAsync().setString('hermes.theme_mode', 'sepia');

    final controller = ThemeController();
    await controller.load();

    expect(controller.mode, ThemeMode.system);
  });

  test('notifies listeners only when the mode changes', () async {
    final controller = ThemeController();
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setMode(ThemeMode.dark);
    await controller.setMode(ThemeMode.dark);

    expect(notified, 1);
  });

  test('a pick made while the saved value is loading wins', () async {
    await ThemeController().setMode(ThemeMode.dark);

    final controller = ThemeController();
    final loading = controller.load();
    await controller.setMode(ThemeMode.light);
    await loading;

    expect(controller.mode, ThemeMode.light);
  });

  test('choosing system while loading beats a saved choice', () async {
    await ThemeController().setMode(ThemeMode.dark);

    final controller = ThemeController();
    final loading = controller.load();
    await controller.setMode(ThemeMode.system);
    await loading;

    expect(controller.mode, ThemeMode.system);
    final relaunched = ThemeController();
    await relaunched.load();
    expect(relaunched.mode, ThemeMode.system);
  });

  test('quick successive picks leave the last one saved', () async {
    final controller = ThemeController();
    unawaited(controller.setMode(ThemeMode.dark));
    unawaited(controller.setMode(ThemeMode.light));
    await controller.setMode(ThemeMode.system);
    unawaited(controller.setMode(ThemeMode.dark));
    await controller.setMode(ThemeMode.light);

    final relaunched = ThemeController();
    await relaunched.load();
    expect(relaunched.mode, ThemeMode.light);
  });

  testWidgets('HermesApp follows the controller', (tester) async {
    final theme = ThemeController();
    final appLock = AppLockController(authenticator: FakeDeviceAuthenticator());
    addTearDown(appLock.dispose);
    await tester.runAsync(appLock.load);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: appLock),
        ],
        child: const HermesApp(),
      ),
    );
    ThemeMode? shown() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode;
    expect(shown(), ThemeMode.system);

    await theme.setMode(ThemeMode.dark);
    await tester.pump();

    expect(shown(), ThemeMode.dark);
  });
}
