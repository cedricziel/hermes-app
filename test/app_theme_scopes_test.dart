import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:hermes_app/src/app.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/settings/theme_controller.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_device_authenticator.dart';
import 'support/screenshot_recorder.dart';
import 'support/workflow_app.dart';

/// `HermesApp` and the workflow tests' `pumpScreen` must draw third-party
/// widgets with the same theme. `gpt_markdown` reads `material_ui`'s theme from
/// [AppThemeScopes]; without it a dark screenshot shows near-black headings
/// the app never draws.
void main() {
  Color headingColor(WidgetTester tester) {
    final span = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(GptMarkdown),
            matching: find.byType(RichText),
          ),
        )
        .map((r) => r.text)
        .first;
    Color? found;
    span.visitChildren((s) {
      if (s is TextSpan && s.style?.color != null) found ??= s.style!.color;
      return found == null;
    });
    return found ?? (span.style?.color ?? Colors.transparent);
  }

  testWidgets('HermesApp mounts AppThemeScopes above its home', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final appLock = AppLockController(authenticator: FakeDeviceAuthenticator());
    addTearDown(appLock.dispose);
    await tester.runAsync(appLock.load);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()..bootstrap()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider.value(value: appLock),
        ],
        child: const HermesApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.text('Connect to Hermes'),
        matching: find.byType(AppThemeScopes),
      ),
      findsOneWidget,
    );
  });

  testWidgets('pumpScreen mounts AppThemeScopes above its home', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      ScreenshotRecorder('theme-scopes'),
      const Scaffold(body: Text('home')),
    );

    expect(
      find.ancestor(
        of: find.text('home'),
        matching: find.byType(AppThemeScopes),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'a dark pumpScreen draws markdown headings readable on the surface',
    (tester) async {
      await pumpScreen(
        tester,
        ScreenshotRecorder('theme-scopes'),
        const Scaffold(body: GptMarkdown('# Heading')),
        brightness: Brightness.dark,
      );

      final surface = Theme.of(tester.element(find.byType(GptMarkdown)))
          .colorScheme
          .surface;
      final color = headingColor(tester);
      // The light fallback is near black; the app draws a light heading.
      expect(color.computeLuminance(), greaterThan(surface.computeLuminance()));
      expect(
        (color.computeLuminance() + 0.05) / (surface.computeLuminance() + 0.05),
        greaterThan(7),
      );
    },
  );
}
