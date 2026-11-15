import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/notifications/notifications_dialog.dart';
import 'package:hermes_app/src/notifications/system_notification_settings.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(settings.load);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
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
