import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/breakpoints.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import '../support/fake_hermes_server.dart';

/// The Mac main window cannot be resized below [kMacMainWindowMinSize], and
/// the home shell must lay out there without an overflow.
void main() {
  late FakeHermesServer server;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([profileRow(name: 'default', isDefault: true)]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'd1', title: 'Plan the release', pinned: true),
          sessionRow(id: 'd2', title: 'Fix the flaky login test'),
        ]),
      )
      ..on('GET', '/api/mcp/servers', mcpServerListBody([]));
  });

  for (final (name, size) in [
    ('minimum', kMacMainWindowMinSize),
    ('default', const Size(1100, 760)),
  ]) {
    testWidgets('home shell at the $name window size has no overflow', (
      tester,
    ) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final auth = CatalogAuth(server: server, gated: true);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        withAppProviders(
          auth,
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
            home: const AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  test('the default window is wide, the minimum is not', () {
    expect(1100, greaterThanOrEqualTo(kWideLayoutBreakpoint));
    expect(kMacMainWindowMinSize.width, lessThan(kWideLayoutBreakpoint));
  });
}
