import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/fake_share_inbox.dart';

void main() {
  late NotificationSettings settings;
  final notifyTile = find.widgetWithText(SwitchListTile, 'Notify me');

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    settings = NotificationSettings();
  });

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(settings.load);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthController()),
          ChangeNotifierProvider(
            create: (_) => ShareController(FakeShareInbox()),
          ),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme(),
          home: const ChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
  }

  testWidgets('the account menu opens the dialog with the switch on', (
    tester,
  ) async {
    await openDialog(tester);

    expect(notifyTile, findsOneWidget);
    expect(tester.widget<SwitchListTile>(notifyTile).value, isTrue);
  });

  testWidgets('the dialog says alerts need the app to be running', (
    tester,
  ) async {
    await openDialog(tester);

    expect(
      find.text(
        'Alerts arrive while Hermes is running, including for a short time '
        'after you leave it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('flipping the switch turns notifications off', (tester) async {
    await openDialog(tester);

    await tester.tap(notifyTile);
    await tester.pumpAndSettle();

    expect(settings.enabled, isFalse);
    expect(tester.widget<SwitchListTile>(notifyTile).value, isFalse);
  });

  testWidgets('a denied permission points to system settings', (tester) async {
    await tester.runAsync(() => settings.recordPermission(granted: false));

    await openDialog(tester);

    expect(
      find.text('Turn on notifications for Hermes in system settings.'),
      findsOneWidget,
    );
  });

  testWidgets('no permission hint when nothing was denied', (tester) async {
    await openDialog(tester);

    expect(
      find.text('Turn on notifications for Hermes in system settings.'),
      findsNothing,
    );
  });

  testWidgets('no permission hint while the switch is off', (tester) async {
    await tester.runAsync(() async {
      await settings.recordPermission(granted: false);
      await settings.setEnabled(false);
    });

    await openDialog(tester);

    expect(
      find.text('Turn on notifications for Hermes in system settings.'),
      findsNothing,
    );
  });

  testWidgets('the dialog has a switch for scheduled tasks, on to begin with', (
    tester,
  ) async {
    await openDialog(tester);

    final tile = find.byKey(const Key('schedule-alerts'));
    expect(tester.widget<SwitchListTile>(tile).value, isTrue);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    expect(settings.scheduleAlerts, isFalse);
  });

  testWidgets('the scheduled tasks switch waits for notifications to be on', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.tap(notifyTile);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('schedule-alerts')))
          .onChanged,
      isNull,
    );
  });
}
