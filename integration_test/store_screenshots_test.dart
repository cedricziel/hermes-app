import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/main.dart' as app;
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

const _shotPort = String.fromEnvironment('SHOT_PORT');

/// `light` or `dark` sets the app's own theme; empty follows the system, which
/// is what the simulators are set to.
const _shotTheme = String.fromEnvironment('SHOT_THEME');

/// Walks the real app through the screens shown on the store listing and in
/// the README. It needs a Hermes dashboard seeded by
/// `scripts/seed_demo_sessions.py`, passed as `--dart-define=HERMES_SERVER_URL`,
/// and a driver that decides where each screenshot goes
/// (`test_driver/integration_test.dart`). `scripts/store-screenshots.sh` runs it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int seconds = 2]) async {
    for (var i = 0; i < seconds * 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('store screenshots', (tester) async {
    // A tap that misses would otherwise leave the same screen in every image.
    WidgetController.hitTestWarningShouldBeFatal = true;
    await app.main();
    await settle(tester, 4);
    if (_shotTheme.isNotEmpty) {
      final context = tester.element(find.byType(MaterialApp));
      await Provider.of<ThemeController>(
        context,
        listen: false,
      ).setMode(ThemeMode.values.byName(_shotTheme));
      await settle(tester);
    }

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final wide = width >= 900;

    Future<void> openThreads() async {
      if (wide) return;
      await tester.tap(find.byIcon(Icons.menu).first);
      await settle(tester);
    }

    // The driver answers once the screen has been captured.
    Future<void> shot(String name) async {
      await settle(tester);
      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$_shotPort/shot?name=$name'),
        );
        final response = await request.close();
        expect(response.statusCode, 200, reason: 'screenshot $name');
      } finally {
        client.close();
      }
    }

    await openThreads();
    await tester.tap(find.byKey(const ValueKey('thread-demo-backup-failure')));
    await settle(tester, 3);
    await shot('chat');

    await openThreads();
    if (!wide) await shot('threads');

    await tester.tap(find.text('New chat'));
    await settle(tester);
    await shot('welcome');
  });
}
