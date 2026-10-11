import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/settings/settings_dialog.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/spotlight/spotlight_settings.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/dictation_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_share_inbox.dart';

void main() {
  late SpotlightSettings settings;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    settings = SpotlightSettings();
    await settings.load();
  });

  Future<void> openAccountMenu(
    WidgetTester tester, {
    bool tooltip = true,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(
            create: (_) => ShareController(FakeShareInbox()),
          ),
          ChangeNotifierProvider(create: (_) => NotificationSettings()),
          ChangeNotifierProvider(create: (_) => DictationSettings()),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: const ChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (tooltip) await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
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
  }

  group('the account menu', () {
    testWidgets('opens the Spotlight dialog on iOS, enabled by default', (
      tester,
    ) async {
      await openAccountMenu(tester);
      await tester.tap(find.text('Spotlight'));
      await tester.pumpAndSettle();

      expect(find.text('Show chats in Spotlight'), findsOneWidget);
      expect(find.textContaining('while it is unlocked'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(settings.enabled, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('has no Spotlight entry on Android', (tester) async {
      await openAccountMenu(tester);

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Spotlight'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('has no Spotlight entry on macOS', (tester) async {
      await openAccountMenu(tester, tooltip: false);
      await tester.tap(find.byKey(const Key('mac-account-footer')));
      await tester.pumpAndSettle();

      expect(find.text('Settings…'), findsOneWidget);
      expect(find.text('Spotlight'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('the Settings dialog', () {
    testWidgets('has a Spotlight row on iOS that opens the dialog', (
      tester,
    ) async {
      await openSettings(tester, TargetPlatform.iOS);

      expect(find.text('Spotlight'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('setting-spotlight')));
      await tester.pumpAndSettle();

      expect(find.text('Show chats in Spotlight'), findsOneWidget);
    });

    testWidgets('opens Spotlight settings on macOS', (tester) async {
      await openSettings(tester, TargetPlatform.macOS);
      await tester.tap(find.byKey(const ValueKey('setting-spotlight')));
      await tester.pumpAndSettle();
      expect(find.text('Show chats in Spotlight'), findsOneWidget);
    });

    for (final platform in [TargetPlatform.android]) {
      testWidgets('has no Spotlight row on $platform', (tester) async {
        await openSettings(tester, platform);

        expect(find.byKey(const ValueKey('setting-spotlight')), findsNothing);
      });
    }
  });
}
