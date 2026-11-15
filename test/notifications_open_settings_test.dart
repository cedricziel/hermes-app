import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/background/background_check_controller.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/notifications/notifications_dialog.dart';
import 'package:hermes_app/src/notifications/system_notification_settings.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// A check result the test sets directly, where the real controller only
/// reads on Android and iOS and from the platform.
class _Checks extends BackgroundCheckController {
  _Checks(this._result)
    : super(
        changes: ValueNotifier(0),
        account: () => null,
        signedOut: const Stream.empty(),
        permission: () async => null,
        platform: TargetPlatform.android,
        observeLifecycle: false,
      );
  final bool? _result;

  @override
  Future<void> refresh() async {
    permission = _result;
  }
}

void main() {
  late NotificationSettings settings;
  final button = find.byKey(const Key('notifications-open-settings'));

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    settings = NotificationSettings();
  });

  Future<void> openDialog(
    WidgetTester tester,
    OpenNotificationSettings opener, {
    TargetPlatform platform = TargetPlatform.android,
    Locale? locale,
    BackgroundCheckController? checks,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(settings.load);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          if (checks != null)
            ChangeNotifierProvider<BackgroundCheckController>.value(
              value: checks,
            ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHermesLightTheme().copyWith(platform: platform),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showNotificationsDialog(context, openSettings: opener),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a denied permission offers Open settings, one tap opens', (
    tester,
  ) async {
    var opened = 0;
    await tester.runAsync(() => settings.recordPermission(granted: false));

    await openDialog(tester, () async => opened++);

    expect(
      find.descendant(of: button, matching: find.text('Open settings')),
      findsOneWidget,
    );
    expect(opened, 0);

    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(opened, 1);
  });

  testWidgets('the button reads German in a German app', (tester) async {
    await tester.runAsync(() => settings.recordPermission(granted: false));

    await openDialog(tester, () async {}, locale: const Locale('de'));

    expect(find.text('Einstellungen öffnen'), findsOneWidget);
    expect(
      find.text('In den Systemeinstellungen für Hermes aktivieren.'),
      findsOneWidget,
    );
  });

  testWidgets('iOS offers it too', (tester) async {
    await tester.runAsync(() => settings.recordPermission(granted: false));

    await openDialog(tester, () async {}, platform: TargetPlatform.iOS);

    expect(button, findsOneWidget);
  });

  testWidgets('macOS offers it too', (tester) async {
    await tester.runAsync(() => settings.recordPermission(granted: false));

    await openDialog(tester, () async {}, platform: TargetPlatform.macOS);

    expect(button, findsOneWidget);
  });

  testWidgets('a background check that says denied shows it over the flag', (
    tester,
  ) async {
    // The stored flag says granted; the system's answer wins.
    await tester.runAsync(() => settings.recordPermission(granted: true));

    await openDialog(tester, () async {}, checks: _Checks(false));

    expect(button, findsOneWidget);
  });

  testWidgets('a background check that says allowed hides it over the flag', (
    tester,
  ) async {
    await tester.runAsync(() => settings.recordPermission(granted: false));

    await openDialog(tester, () async {}, checks: _Checks(true));

    expect(button, findsNothing);
  });

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets('the switch and the button are separate nodes on $platform', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var opened = 0;
      await tester.runAsync(() => settings.recordPermission(granted: false));
      await openDialog(tester, () async => opened++, platform: platform);

      final toggle = find.semantics.byPredicate(
        (node) => node.label.contains('Notify me'),
      );
      final pressable = find.semantics.byLabel('Open settings');
      final row = tester.getSemantics(
        find.descendant(
          of: find.byKey(const Key('notify-me')),
          matching: find.byType(Switch),
        ),
      );
      final action = tester.getSemantics(button);
      expect(row.id, isNot(action.id));
      expect(row.label, contains('Notify me'));
      expect(row.label, isNot(contains('Open settings')));
      expect(row.flagsCollection.isToggled, Tristate.isTrue);
      expect(action.label, 'Open settings');
      expect(action.flagsCollection.isButton, isTrue);
      expect(action.flagsCollection.isToggled, Tristate.none);

      tester.semantics.tap(toggle);
      await tester.pumpAndSettle();
      expect(settings.enabled, isFalse);
      expect(opened, 0);

      tester.semantics.tap(toggle);
      await tester.pumpAndSettle();
      expect(settings.enabled, isTrue);

      tester.semantics.tap(pressable);
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(settings.enabled, isTrue);
      handle.dispose();
    });
  }

  testWidgets('no button on Linux', (tester) async {
    await tester.runAsync(() => settings.recordPermission(granted: false));

    await openDialog(tester, () async {}, platform: TargetPlatform.linux);

    expect(button, findsNothing);
  });

  testWidgets('no button when nothing was denied', (tester) async {
    await openDialog(tester, () async {});

    expect(button, findsNothing);
  });

  testWidgets('no button while the switch is off', (tester) async {
    await tester.runAsync(() async {
      await settings.recordPermission(granted: false);
      await settings.setEnabled(false);
    });

    await openDialog(tester, () async {});

    expect(button, findsNothing);
  });

  test('only the platforms app_settings supports can open settings', () {
    const supported = {
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    };
    for (final platform in TargetPlatform.values) {
      expect(
        canOpenNotificationSettings(platform),
        supported.contains(platform),
      );
    }
  });
}
