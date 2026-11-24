import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/navigation/desktop_menu_bar_settings.dart';
import 'package:hermes_app/src/settings/settings_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/test_localizations.dart';

void main() {
  late DesktopMenuBarSettings settings;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    settings = DesktopMenuBarSettings();
  });

  tearDown(() => settings.dispose());

  Future<void> openSettings(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(platform: platform),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsDialog(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    testWidgets('${platform.name}: the switch is off and turns the bar on', (
      tester,
    ) async {
      await openSettings(tester, platform);

      final row = find.byKey(const ValueKey('setting-desktopMenuBar'));
      expect(find.text('Show menu bar'), findsOneWidget);
      expect(
        tester
            .widget<Switch>(
              find.descendant(of: row, matching: find.byType(Switch)),
            )
            .value,
        isFalse,
      );
      expect(settings.enabled, isFalse);

      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pump();

      expect(settings.enabled, isTrue);
      expect(
        tester
            .widget<Switch>(
              find.descendant(of: row, matching: find.byType(Switch)),
            )
            .value,
        isTrue,
      );
    });
  }

  for (final platform in [
    TargetPlatform.macOS,
    TargetPlatform.iOS,
    TargetPlatform.android,
  ]) {
    testWidgets('${platform.name}: there is no Show menu bar switch', (
      tester,
    ) async {
      await openSettings(tester, platform);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Show menu bar'), findsNothing);
    });
  }
}
