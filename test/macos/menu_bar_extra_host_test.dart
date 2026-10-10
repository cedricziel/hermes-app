import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/app_lock/app_lock_controller.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/macos/mac_window.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_host.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_link.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_model.dart';
import 'package:hermes_app/src/macos/menu_bar_extra/menu_bar_extra_settings.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_conversation_window_host.dart';
import '../support/fake_device_authenticator.dart';
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
    });

    tearDown(() {
      MacWindow.enabled = macWindow;
    });

    /// Mounts the host, deciding on [platform] as it starts, and returns the
    /// link the chat screen would get (null where the host provides none).
    Future<({FakeMenuBarTray tray, ValueGetter<MenuBarExtraLink?> link})>
    pumpHost(
      WidgetTester tester, {
      MenuBarExtraSettings? settings,
      AppLockController? lock,
      TargetPlatform platform = TargetPlatform.macOS,
      GlobalKey<NavigatorState>? navigatorKey,
    }) async {
      final tray = FakeMenuBarTray();
      final windowHost = FakeConversationWindowHost();
      final windows = ConversationWindows(
        host: windowHost,
        store: ConversationWindowStore(SharedPreferencesAsync()),
        connection: () => null,
        headers: ({rejected}) async => const {},
      );
      addTearDown(() {
        windows.dispose();
        windowHost.dispose();
      });
      MenuBarExtraLink? link;
      final host = MaterialApp(
        navigatorKey: navigatorKey,
        home: MenuBarExtraHost(
          navigatorKey: navigatorKey ?? GlobalKey<NavigatorState>(),
          tray: tray,
          child: Builder(
            builder: (context) {
              link = context.read<MenuBarExtraLink?>();
              return const Text('app');
            },
          ),
        ),
      );
      debugDefaultTargetPlatformOverride = platform;
      try {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<ConversationWindows?>.value(
                value: windows,
              ),
              if (settings != null)
                ChangeNotifierProvider<MenuBarExtraSettings>.value(
                  value: settings,
                ),
              if (lock != null)
                ChangeNotifierProvider<AppLockController>.value(value: lock),
            ],
            child: host,
          ),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      return (tray: tray, link: () => link);
    }

    Future<MenuBarExtraSettings> loadedSettings() async {
      final settings = MenuBarExtraSettings();
      addTearDown(settings.dispose);
      await settings.load();
      return settings;
    }

    testWidgets('shows the item while the setting is on', (tester) async {
      final settings = await loadedSettings();
      final host = await pumpHost(tester, settings: settings);
      final tray = host.tray;

      expect(find.text('app'), findsOneWidget);
      expect(tray.last.visible, isTrue);
      expect(tray.last.state, MenuBarIconState.idle);

      await settings.setEnabled(false);
      expect(tray.last.visible, isFalse);

      await tester.pumpWidget(const SizedBox());
      expect(tray.last.visible, isFalse);
    });

    testWidgets('keeps the item hidden until the setting has loaded', (
      tester,
    ) async {
      final settings = MenuBarExtraSettings();
      addTearDown(settings.dispose);
      final host = await pumpHost(tester, settings: settings);

      expect(host.tray.updates, isEmpty);
    });

    testWidgets('only passes its child through without the setting', (
      tester,
    ) async {
      final host = await pumpHost(tester);

      expect(find.text('app'), findsOneWidget);
      expect(host.tray.updates, isEmpty);
      expect(host.link(), isNull);
    });

    testWidgets('gives the chat screen its link on macOS only', (tester) async {
      final settings = await loadedSettings();

      final onMac = await pumpHost(tester, settings: settings);
      expect(onMac.link(), isNotNull);

      await tester.pumpWidget(const SizedBox());
      final onPhone = await pumpHost(
        tester,
        settings: settings,
        platform: TargetPlatform.iOS,
      );
      expect(onPhone.link(), isNull);
      expect(onPhone.tray.updates, isEmpty);
    });

    group('with a chat', () {
      late FakeChatTransport transport;
      late ChatController chat;

      setUp(() {
        transport = FakeChatTransport();
        final attention = AttentionNotifier(
          service: null,
          settings: null,
          onOpen: (_) {},
        );
        chat = ChatController(
          transport: transport,
          attention: attention,
          report: (_) {},
        );
        addTearDown(() {
          chat.dispose();
          attention.dispose();
        });
      });

      Future<void> startApproval(
        WidgetTester tester,
        MenuBarExtraLink link,
      ) async {
        link.connect(chat: chat, openChat: (_) {}, newChat: () {});
        chat
          ..newThread()
          ..submit('Private plan', const []);
        transport.sends.single.emit(
          const ApprovalRequested(
            ApprovalRequest(
              requestId: 'r1',
              command: 'rm -rf build',
              description: '',
              choices: ['once', 'always'],
            ),
          ),
        );
        // The menu follows the chat at most every 150 ms.
        await tester.pump(const Duration(milliseconds: 200));
      }

      testWidgets('asks before "always" in the app\'s window and then sends', (
        tester,
      ) async {
        final settings = await loadedSettings();
        final navigatorKey = GlobalKey<NavigatorState>();
        final host = await pumpHost(
          tester,
          settings: settings,
          navigatorKey: navigatorKey,
        );
        await startApproval(tester, host.link()!);

        host.tray.pickKey(host.tray.item('Always allow').key!);
        await tester.pump();
        await tester.pump();

        expect(find.text('Always allow this?'), findsOneWidget);
        expect(transport.approvalAnswers, isEmpty);

        await tester.tap(find.text('Yes, always allow'));
        await tester.pumpAndSettle();

        expect(transport.approvalAnswers, [('r1', 'always')]);
      });

      testWidgets('sends nothing when the question is declined', (
        tester,
      ) async {
        final settings = await loadedSettings();
        final navigatorKey = GlobalKey<NavigatorState>();
        final host = await pumpHost(
          tester,
          settings: settings,
          navigatorKey: navigatorKey,
        );
        await startApproval(tester, host.link()!);

        host.tray.pickKey(host.tray.item('Always allow').key!);
        await tester.pump();
        await tester.pump();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(transport.approvalAnswers, isEmpty);
      });

      testWidgets('follows the app lock', (tester) async {
        final settings = await loadedSettings();
        final authenticator = FakeDeviceAuthenticator();
        final lock = AppLockController(
          authenticator: authenticator,
          coverWhenInactive: false,
        );
        addTearDown(lock.dispose);
        await lock.load();
        await lock.setEnabled(true);
        final host = await pumpHost(tester, settings: settings, lock: lock);
        await startApproval(tester, host.link()!);
        expect(host.tray.titles, contains('rm -rf build'));

        lock.didChangeAppLifecycleState(AppLifecycleState.hidden);
        await tester.pump();

        expect(host.tray.titles, [
          '1 reply running',
          '1 request waiting',
          'Unlock Hermes…',
          'New Chat',
          'Show Main Window',
          'Quit Hermes',
        ]);
      });
    });
  });
}
