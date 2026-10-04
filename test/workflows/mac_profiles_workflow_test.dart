import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/shell/app_shell.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../widgetbook/catalog_auth.dart';
import '../support/fake_hermes_server.dart';
import '../support/screenshot_recorder.dart';

/// A Mac window's profile scope: the switcher, the Profiles page and the
/// account menu, at a large and a compact window size.
void main() {
  late FakeHermesServer server;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(
            name: 'default',
            isDefault: true,
            description: 'Everyday questions',
          ),
          profileRow(name: 'work', description: 'Day job', skillCount: 12),
        ]),
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

  for (final (name, width) in [('large', 1160.0), ('compact', 680.0)]) {
    testWidgets('$name window: switcher, Profiles page, account menu', (
      tester,
    ) async {
      final shots = ScreenshotRecorder('mac-profiles-$name');
      await shots.start(tester, Size(width, 760));
      final auth = CatalogAuth(server: server, gated: true);
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        shots.frame(
          withAppProviders(
            auth,
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: withScreenshotFont(
                buildHermesLightTheme(platform: TargetPlatform.macOS),
              ),
              home: const AppShell(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (name == 'compact') {
        await tester.tap(
          find.byKey(const Key('mac-sidebar-toggle')).hitTestable().first,
        );
        await tester.pumpAndSettle();
      }
      await shots.capture(tester, 'sidebar');

      await tester.tap(find.byKey(const Key('mac-profile-switcher')));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'profile-menu');
      await tester.tap(find.text('Manage Profiles…'));
      await tester.pumpAndSettle();
      await shots.capture(tester, 'profiles-page');

      if (name == 'compact') {
        await tester.tap(
          find.byKey(const Key('mac-sidebar-toggle')).hitTestable().first,
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('mac-account-footer')).last);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'account-menu');
    });
  }
}
