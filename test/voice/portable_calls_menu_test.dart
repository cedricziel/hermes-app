import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_screen.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/share/share_controller.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/voice/calls/portable_call_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_share_inbox.dart';

void main() {
  late PortableCallSettings settings;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    settings = PortableCallSettings();
  });

  Future<void> openAccountMenu(WidgetTester tester) async {
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
  }

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('the account menu turns calls on on $platform', (tester) async {
      await openAccountMenu(tester);
      await tester.tap(find.text('Voice calls'));
      await tester.pumpAndSettle();
      expect(settings.enabled, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(settings.enabled, isTrue);
    }, variant: TargetPlatformVariant.only(platform));
  }

  testWidgets('iOS has no Voice calls entry', (tester) async {
    await openAccountMenu(tester);
    expect(find.text('Voice calls'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
