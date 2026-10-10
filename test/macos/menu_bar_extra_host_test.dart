import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_host.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_link.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_model.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_settings.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_menu_bar_tray.dart';
import '../support/pump_chat.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('the chat screen', () {
    testWidgets('connects its chat to the menu bar item while it is shown', (
      tester,
    ) async {
      final link = MenuBarExtraLink();
      addTearDown(link.dispose);
      var shown = 0;
      final transport = FakeChatTransport();

      await pumpChatScreen(
        tester,
        transport: transport,
        onShowChat: () => shown++,
        providers: [InheritedProvider<MenuBarExtraLink?>.value(value: link)],
      );

      final chat = link.chat!;
      chat
        ..newThread()
        ..submit('Plan the trip', const []);
      expect(MenuBarExtraModel.of(chat).replies.single.title, 'Plan the trip');

      link.newChat();
      expect(shown, 1);
      expect(chat.selectedThread!.messages, isEmpty);

      final thread = chat.threads.firstWhere((t) => t.title == 'Plan the trip');
      link.openChat(NotificationTarget(threadId: thread.id));
      expect(shown, 2);
      expect(chat.selectedThread, same(thread));

      await tester.pumpWidget(const SizedBox());
      expect(link.chat, isNull);
    });
  });

  group('the host', () {
    var macWindow = false;

    setUp(() {
      macWindow = MacWindow.enabled;
      MacWindow.enabled = true;
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    });

    tearDown(() {
      MacWindow.enabled = macWindow;
    });

    Future<FakeMenuBarTray> pumpHost(
      WidgetTester tester, {
      MenuBarExtraSettings? settings,
    }) async {
      final tray = FakeMenuBarTray();
      final host = MaterialApp(
        home: MenuBarExtraHost(
          navigatorKey: GlobalKey<NavigatorState>(),
          tray: tray,
          child: const Text('app'),
        ),
      );
      await tester.pumpWidget(
        settings == null
            ? host
            : ChangeNotifierProvider<MenuBarExtraSettings>.value(
                value: settings,
                child: host,
              ),
      );
      debugDefaultTargetPlatformOverride = null;
      return tray;
    }

    testWidgets('shows the item while the setting is on', (tester) async {
      final settings = MenuBarExtraSettings();
      addTearDown(settings.dispose);
      final tray = await pumpHost(tester, settings: settings);

      expect(find.text('app'), findsOneWidget);
      expect(tray.last.visible, isTrue);
      expect(tray.last.state, MenuBarIconState.idle);

      await settings.setEnabled(false);
      expect(tray.last.visible, isFalse);

      await tester.pumpWidget(const SizedBox());
      expect(tray.last.visible, isFalse);
    });

    testWidgets('only passes its child through without the setting', (
      tester,
    ) async {
      final tray = await pumpHost(tester);

      expect(find.text('app'), findsOneWidget);
      expect(tray.updates, isEmpty);
    });
  });
}
