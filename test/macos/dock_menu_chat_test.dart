import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/macos/dock/dock_menu_bridge.dart';
import 'package:hermes_app/src/macos/dock/dock_menu_controller.dart';
import 'package:hermes_app/src/profiles/chat_profiles.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:hermes_app/src/windows/conversation_windows.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_conversation_window_host.dart';
import '../support/fake_dock_menu_bridge.dart';
import '../support/fake_hermes_server.dart';
import '../support/pump_chat.dart';

/// The Dock menu's choices reaching the chat screen.
void main() {
  late FakeHermesServer server;
  late FakeDockMenuBridge bridge;
  late FakeConversationWindowHost host;
  late ConversationWindows windows;
  late DockMenuController dock;
  late ChatProfiles profiles;
  late Completer<bool> unlock;
  var shown = 0;

  setUp(() {
    shown = 0;
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'home', isDefault: true),
          profileRow(name: 'work'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'home'))
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Trip plan', lastActive: 1780000300),
          sessionRow(id: 's2', title: 'Groceries', lastActive: 1780000200),
          sessionRow(id: 's3', title: 'Taxes', lastActive: 1780000100),
        ]),
        query: {'profile': 'home'},
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 'w1', title: 'Standup', lastActive: 1780000400),
        ]),
        query: {'profile': 'work'},
      )
      ..on('GET', '/api/sessions/s1', sessionRow(id: 's1', title: 'Trip plan'))
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [
          messageRow(id: 1, role: 'user', content: 'Where to?'),
        ]),
      );
  });

  Future<void> pump(WidgetTester tester) async {
    unlock = Completer();
    bridge = FakeDockMenuBridge();
    profiles = ChatProfiles(HermesProfilesRepository(server.client().raw));
    dock = DockMenuController(bridge: bridge, unlock: () => unlock.future)
      ..configure(DockMenuState.ready);
    addTearDown(dock.dispose);
    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      chatProfiles: profiles,
      transport: FakeChatTransport(),
      platform: TargetPlatform.macOS,
      onShowChat: () => shown++,
      providers: [
        ChangeNotifierProvider<DockMenuController?>.value(value: dock),
        ChangeNotifierProvider<ConversationWindows?>(
          create: (_) {
            host = FakeConversationWindowHost();
            addTearDown(host.dispose);
            return windows = ConversationWindows(
              host: host,
              store: ConversationWindowStore(SharedPreferencesAsync()),
              connection: () =>
                  (baseUrl: 'https://hermes.test', authRequired: true),
              headers: ({rejected}) async => const {},
            );
          },
        ),
      ],
    );
  }

  testWidgets('offers the newest chats of the shown profile', (tester) async {
    await pump(tester);

    expect(bridge.shownIds, ['s1', 's2', 's3']);
    expect(bridge.updates.last.$2.first.profile, 'home');
  });

  testWidgets('follows a profile switch', (tester) async {
    server.on('POST', '/api/profiles/active', {'ok': true});
    await pump(tester);

    unawaited(profiles.switchTo('work'));
    await tester.pumpAndSettle();

    expect(bridge.shownIds, ['w1']);
    expect(bridge.updates.last.$2.single.profile, 'work');
  });

  testWidgets('forgets the chats when the screen goes away', (tester) async {
    await pump(tester);
    expect(bridge.shownIds, isNotEmpty);

    await tester.pumpWidget(const SizedBox());

    expect(bridge.updates.last.$1, DockMenuState.ready);
    expect(bridge.updates.last.$2, isEmpty);
  });

  testWidgets('shows the chats again once the app unlocks', (tester) async {
    await pump(tester);

    dock.configure(DockMenuState.locked);
    expect(bridge.updates.last.$2, isEmpty);

    dock.configure(DockMenuState.ready);
    expect(bridge.shownIds, ['s1', 's2', 's3']);
  });

  testWidgets('a pick focuses the chat\'s conversation window', (tester) async {
    await pump(tester);
    await windows.open('s2', profile: 'home', title: 'Groceries');

    bridge.picks.add(const DockOpenChat('s2', 'home'));
    await tester.pumpAndSettle();

    expect(host.focused, ['w0']);
    expect(host.mainShown, 0);
    expect(shown, 0);
  });

  testWidgets('a pick opens a chat without a window in the main window', (
    tester,
  ) async {
    await pump(tester);

    bridge.picks.add(const DockOpenChat('s1', 'home'));
    await tester.pumpAndSettle();

    expect(host.mainShown, 1);
    expect(shown, 1);
    expect(find.text('Where to?'), findsOneWidget);
  });

  testWidgets('a pick opens a chat outside the loaded page', (tester) async {
    server
      ..on('GET', '/api/sessions/old', sessionRow(id: 'old', title: 'Old one'))
      ..on(
        'GET',
        '/api/sessions/old/messages',
        messageListBody('old', [
          messageRow(id: 1, role: 'user', content: 'From long ago'),
        ]),
      );
    await pump(tester);

    bridge.picks.add(const DockOpenChat('old', 'home'));
    await tester.pumpAndSettle();

    expect(find.text('From long ago'), findsOneWidget);
    expect(shown, 1);
  });

  testWidgets('a chat that is gone reports it and creates nothing', (
    tester,
  ) async {
    server.on('GET', '/api/sessions/gone', {'detail': 'nope'}, status: 404);
    await pump(tester);

    bridge.picks.add(const DockOpenChat('gone', 'home'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open that chat.'), findsOneWidget);
    expect(shown, 0);
    expect(bridge.shownIds, ['s1', 's2', 's3']);
    expect(server.requestsTo('POST', '/api/sessions'), isEmpty);
  });

  testWidgets('New Chat leaves the open chat for an empty one', (tester) async {
    await pump(tester);
    bridge.picks.add(const DockOpenChat('s1', 'home'));
    await tester.pumpAndSettle();
    expect(find.text('Where to?'), findsOneWidget);
    shown = 0;

    bridge.picks.add(const DockNewChat());
    await tester.pumpAndSettle();

    expect(find.text('Where to?'), findsNothing);
    expect(shown, 1);
    expect(bridge.shownIds, ['s1', 's2', 's3'], reason: 'unsaved, not listed');
  });

  testWidgets('New Chat while locked starts only after the unlock', (
    tester,
  ) async {
    await pump(tester);
    bridge.picks.add(const DockOpenChat('s1', 'home'));
    await tester.pumpAndSettle();
    shown = 0;
    dock.configure(DockMenuState.locked);

    bridge.picks.add(const DockNewChat());
    await tester.pumpAndSettle();
    expect(find.text('Where to?'), findsOneWidget);
    expect(shown, 0);

    dock.configure(DockMenuState.ready);
    unlock.complete(true);
    await tester.pumpAndSettle();

    expect(find.text('Where to?'), findsNothing);
    expect(shown, 1);
  });

  testWidgets('New Chat while locked does nothing when the unlock fails', (
    tester,
  ) async {
    await pump(tester);
    bridge.picks.add(const DockOpenChat('s1', 'home'));
    await tester.pumpAndSettle();
    shown = 0;
    dock.configure(DockMenuState.locked);

    bridge.picks.add(const DockNewChat());
    unlock.complete(false);
    await tester.pumpAndSettle();
    dock.configure(DockMenuState.ready);
    await tester.pumpAndSettle();

    expect(find.text('Where to?'), findsOneWidget);
    expect(shown, 0);
  });
}
