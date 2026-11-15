import 'dart:io';

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
/// Inherited widgets the app's chrome adds that say nothing about how a child
/// draws: focus scopes, the ticker mode of a hidden route, the desktop
/// navigation history and the menu bar's registry.
const _notTheme = {
  '_FocusInheritedScope',
  '_EffectiveTickerMode',
  'DesktopNavigationHistoryScope',
  '_RegistryScope',
};

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

  /// What a widget below `home` inherits that could change how it draws:
  /// every [InheritedTheme] and every [InheritedWidget] that is not on the
  /// allowlist, from the app's `Navigator` (what the builder wraps; the routes differ)
  /// up to the root. Providers and [MediaQuery] are
  /// data an app or a test supplies by itself, so they are left out;
  /// everything else has to be the same in `HermesApp` and `pumpScreen`.
  List<String> inheritedAbove(WidgetTester tester, Finder home) {
    final types = <String>[];
    tester.element(home).visitAncestorElements((e) {
      final w = e.widget;
      final name = w.runtimeType.toString();
      final ignored =
          w is MediaQuery ||
          name.startsWith('_InheritedProviderScope') ||
          _notTheme.contains(name);
      if (!ignored && (w is InheritedTheme || w is InheritedWidget)) {
        types.add(name);
      }
      return true;
    });
    return types;
  }

  Future<void> pumpHermesApp(WidgetTester tester) async {
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
  }

  testWidgets('HermesApp mounts AppThemeScopes above its home', (tester) async {
    await pumpHermesApp(tester);

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

  for (final brightness in Brightness.values) {
    testWidgets(
      'pumpScreen inherits the same theme widgets as HermesApp (${brightness.name})',
      (tester) async {
        await pumpHermesApp(tester);
        final app = inheritedAbove(tester, find.byType(Navigator).first);

        await pumpScreen(
          tester,
          ScreenshotRecorder('theme-scopes'),
          const Scaffold(body: Text('home')),
          brightness: brightness,
        );
        final harness = inheritedAbove(tester, find.byType(Navigator).first);

        expect(app, isNotEmpty);
        expect(harness, app);
      },
    );
  }

  test('every engine that builds a MaterialApp mounts AppThemeScopes', () {
    // The conversation window and the quick panel are engines of their own
    // that `runApp` a MaterialApp, which no test can start without native
    // channels, so check their source.
    final missing = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.contains('generated') &&
            f.readAsStringSync().contains('MaterialApp(') &&
            !f.readAsStringSync().contains('AppThemeScopes('))
          f.path,
    ];
    expect(missing, isEmpty);
  });
}
