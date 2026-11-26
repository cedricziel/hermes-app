import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app/providers/app_lock_providers.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/tool_image_loader.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/windows/window_tool_image_loader.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/telemetry/telemetry_config.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_device_authenticator.dart';

void main() {
  testWidgets('a window gets a loader of its own', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [windowToolImageLoaderProvider()],
        child: const SizedBox(),
      ),
    );

    expect(
      tester.element(find.byType(SizedBox)).read<ToolImageLoader?>(),
      isNotNull,
    );
  });

  test('both window entry points provide it', () {
    for (final path in const [
      'lib/src/windows/conversation_window_app.dart',
      'lib/src/quick_panel/quick_panel_app.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('windowToolImageLoaderProvider()'),
        reason: path,
      );
    }
  });

  test('the app\'s provider list has the loader', () async {
    final telemetry = await Telemetry.initialize(
      const TelemetryConfig(
        otlpEndpoint: '',
        otlpHeaders: {},
        serviceName: 'test',
        serviceVersion: '',
        deploymentEnvironment: 'test',
      ),
    );

    expect(
      appLockProviders(telemetry).whereType<Provider<ToolImageLoader?>>(),
      hasLength(1),
    );
  });

  testWidgets('the app\'s loader clears when the app locks and on sign-out', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    late AppLockController lock;
    await tester.runAsync(() async {
      lock = AppLockController(authenticator: FakeDeviceAuthenticator());
      await lock.load();
      await lock.setEnabled(true);
    });
    addTearDown(lock.dispose);
    final auth = AuthController();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppLockController>.value(value: lock),
          ChangeNotifierProvider<AuthController>.value(value: auth),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.none),
          toolImageLoaderProvider(),
        ],
        child: const SizedBox(),
      ),
    );
    final loader = tester
        .element(find.byType(SizedBox))
        .read<ToolImageLoader?>()!;
    var cleared = 0;
    loader.changes.addListener(() => cleared++);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(cleared, 1);

    await tester.runAsync(auth.signOut);
    expect(cleared, 2);
  });
}
