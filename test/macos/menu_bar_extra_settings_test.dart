import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_settings.dart';
import 'package:hermes_app/src/settings/settings_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('MenuBarExtraSettings', () {
    Future<MenuBarExtraSettings> relaunch() async {
      final settings = MenuBarExtraSettings();
      await settings.load();
      return settings;
    }

    test('is not loaded until load completes', () async {
      final settings = MenuBarExtraSettings();
      expect(settings.loaded, isFalse);

      await settings.load();

      expect(settings.loaded, isTrue);
    });

    test('an edit made before the first load still counts as loaded', () async {
      final settings = MenuBarExtraSettings();

      await settings.setEnabled(false);
      await settings.load();

      expect(settings.loaded, isTrue);
      expect(settings.enabled, isFalse);
    });

    test('starts on', () async {
      expect((await relaunch()).enabled, isTrue);
    });

    test('keeps the switch across launches', () async {
      final settings = await relaunch();

      await settings.setEnabled(false);

      expect((await relaunch()).enabled, isFalse);
      await settings.setEnabled(true);
      expect((await relaunch()).enabled, isTrue);
    });

    test(
      'tells listeners about a change, but not about the same value',
      () async {
        final settings = await relaunch();
        var heard = 0;
        settings.addListener(() => heard++);

        await settings.setEnabled(true);
        await settings.setEnabled(false);

        expect(heard, 1);
      },
    );

    test('an edit made while loading wins over what was stored', () async {
      await SharedPreferencesAsync().setBool('menuBarExtra.enabled', true);
      final settings = MenuBarExtraSettings();

      final loading = settings.load();
      await settings.setEnabled(false);
      await loading;

      expect(settings.enabled, isFalse);
    });
  });

  group('the Settings dialog', () {
    Future<MenuBarExtraSettings> openSettings(
      WidgetTester tester, {
      required TargetPlatform platform,
    }) async {
      debugDefaultTargetPlatformOverride = platform;
      final settings = MenuBarExtraSettings();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: settings,
          child: MaterialApp(
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
      // The dialog has decided which rows it shows.
      debugDefaultTargetPlatformOverride = null;
      return settings;
    }

    testWidgets('has a switch on macOS, on by default', (tester) async {
      await openSettings(tester, platform: TargetPlatform.macOS);

      final row = find.byKey(const ValueKey('setting-menuBarExtra'));
      expect(row, findsOneWidget);
      expect(find.text('Menu bar item'), findsOneWidget);
      expect(
        tester
            .widget<Switch>(
              find.descendant(of: row, matching: find.byType(Switch)),
            )
            .value,
        isTrue,
      );
    });

    testWidgets('turning it off hides the item', (tester) async {
      final settings = await openSettings(
        tester,
        platform: TargetPlatform.macOS,
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(settings.enabled, isFalse);
    });

    testWidgets('has none off macOS', (tester) async {
      await openSettings(tester, platform: TargetPlatform.iOS);

      expect(find.byKey(const ValueKey('setting-menuBarExtra')), findsNothing);
    });
  });
}
