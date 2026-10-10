import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_mode/bot_chat_context.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/macos/dock/dock_menu_bridge.dart';
import 'package:hermes_app/src/macos/dock/dock_menu_controller.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';

import '../support/fake_dock_menu_bridge.dart';
import '../support/recorded_events.dart';

ChatThread thread(
  String id, {
  String title = 'A chat',
  int minutesAgo = 0,
  bool remote = true,
  bool pinned = false,
  BotChatContext? bot,
}) => ChatThread(
  id: id,
  title: title,
  updatedAt: DateTime(2026, 1, 1, 12).subtract(Duration(minutes: minutesAgo)),
  remote: remote,
  pinned: pinned,
  botContext: bot,
);

void main() {
  late FakeDockMenuBridge bridge;
  late BreadcrumbTrail trail;
  late RecordedEvents events;
  late bool unlocks;
  late Completer<bool>? prompt;
  late int unlockCalls;
  late DockMenuController dock;
  late List<String> opened;
  late int newChats;
  var open = (String id, String profile) async => DockOpenResult.inMain;

  void expectLast(DockMenuState state) {
    expect(bridge.updates.last.$1, state);
    expect(bridge.updates.last.$2, isEmpty);
  }

  List<Object> crumbs(String name) => [
    for (final c in trail.recent)
      if (c.name == name) c.attributes,
  ];

  setUp(() {
    bridge = FakeDockMenuBridge();
    trail = BreadcrumbTrail(capacity: 50);
    events = RecordedEvents();
    unlocks = true;
    prompt = null;
    unlockCalls = 0;
    opened = [];
    newChats = 0;
    open = (id, profile) async {
      opened.add('$profile/$id');
      return DockOpenResult.inMain;
    };
    dock = DockMenuController(
      bridge: bridge,
      unlock: () async {
        unlockCalls++;
        return prompt != null ? prompt!.future : unlocks;
      },
      breadcrumbs: Breadcrumbs.of(trail),
      events: events.call,
    );
    dock.bind(
      open: (id, profile) => open(id, profile),
      newChat: () => newChats++,
    );
    addTearDown(dock.dispose);
  });

  group('recent chats', () {
    test('lists the five newest saved chats of the profile', () {
      dock.configure(DockMenuState.ready);
      dock.setChats([
        for (var i = 0; i < 7; i++) thread('t$i', minutesAgo: 7 - i),
      ], 'work');

      final (state, chats) = bridge.updates.last;
      expect(state, DockMenuState.ready);
      expect([for (final c in chats) c.id], ['t6', 't5', 't4', 't3', 't2']);
      expect(chats.every((c) => c.profile == 'work'), isTrue);
    });

    test('leaves out drafts and hidden bot registries, ignores pinning', () {
      const bot = BotChatContext(
        bot: BotModeBot(serverId: 's', name: 'ada', revision: 0),
        rootId: 'r',
        storedId: 'registry',
      );
      dock.configure(DockMenuState.ready);
      dock.setChats([
        thread('draft', remote: false),
        thread('registry', bot: bot),
        thread('pinned', pinned: true, minutesAgo: 30),
        thread('new', minutesAgo: 1),
      ], 'work');

      expect([for (final c in bridge.updates.last.$2) c.id], ['new', 'pinned']);
    });

    test('shortens titles to 40 characters and names untitled chats', () {
      dock.configure(DockMenuState.ready);
      dock.setChats([
        thread('long', title: 'x' * 60, minutesAgo: 1),
        thread('exact', title: 'y' * 40, minutesAgo: 2),
        thread('blank', title: '  \n ', minutesAgo: 3),
        thread('lines', title: 'Plan\nthe   trip', minutesAgo: 4),
      ], 'work');

      final titles = [for (final c in bridge.updates.last.$2) c.title];
      expect(titles[0], '${'x' * 39}…');
      expect(titles[0].length, 40);
      expect(titles[1], 'y' * 40);
      expect(titles[2], 'Untitled chat');
      expect(titles[3], 'Plan the trip');
    });

    test('lists none while the profile is unresolved', () {
      dock.configure(DockMenuState.ready);
      dock.setChats([thread('a')], 'work');
      dock.setChats([thread('a')], null);

      expect(bridge.updates.last.$2, isEmpty);
    });

    test('pushes only when the list changed', () {
      dock.configure(DockMenuState.ready);
      final chats = [thread('a', title: 'One')];
      dock.setChats(chats, 'work');
      final pushes = bridge.updates.length;

      chats.single.updatedAt = DateTime(2026, 1, 1, 13);
      dock.setChats(chats, 'work');
      expect(bridge.updates, hasLength(pushes));

      dock.setChats(chats, 'home');
      expect(bridge.updates, hasLength(pushes + 1));
    });
  });

  group('state', () {
    test('holds no chats while off or locked', () {
      dock.setChats([thread('a')], 'work');
      expect(bridge.updates.expand((u) => u.$2), isEmpty);

      dock.configure(DockMenuState.locked);
      dock.setChats([thread('a')], 'work');
      expectLast(DockMenuState.locked);
    });

    test('drops the chats when the state leaves ready', () {
      dock.configure(DockMenuState.ready);
      dock.setChats([thread('a')], 'work');

      dock.configure(DockMenuState.locked);
      expectLast(DockMenuState.locked);

      dock.configure(DockMenuState.ready);
      expectLast(DockMenuState.ready);

      dock.setChats([thread('a')], 'work');
      dock.configure(DockMenuState.off);
      expectLast(DockMenuState.off);
    });

    test('clearChats empties the list and tells the runner', () {
      dock.configure(DockMenuState.ready);
      dock.setChats([thread('a')], 'work');

      dock.clearChats();

      expectLast(DockMenuState.ready);
    });

    test('tells listeners when the state changes', () {
      var heard = 0;
      dock.addListener(() => heard++);
      dock.configure(DockMenuState.ready);
      dock.configure(DockMenuState.ready);
      dock.configure(DockMenuState.locked);
      expect(heard, 2);
    });
  });

  group('picking a chat', () {
    test('opens it and leaves a crumb without the chat in it', () async {
      dock.configure(DockMenuState.ready);

      bridge.picks.add(const DockOpenChat('secret-id', 'secret-profile'));
      await pumpEventQueue();

      expect(opened, ['secret-profile/secret-id']);
      expect(crumbs('dock.menu.action'), [
        {'action': 'open_chat', 'window': false, 'deferred': false},
      ]);
    });

    test('says when a conversation window took it', () async {
      dock.configure(DockMenuState.ready);
      open = (id, profile) async => DockOpenResult.inWindow;

      bridge.picks.add(const DockOpenChat('a', 'work'));
      await pumpEventQueue();

      expect(crumbs('dock.menu.action'), [
        {'action': 'open_chat', 'window': true, 'deferred': false},
      ]);
    });

    test('logs a chat that could not be opened, with the kind only', () async {
      dock.configure(DockMenuState.ready);
      open = (id, profile) async => DockOpenResult.unavailable;
      bridge.picks.add(const DockOpenChat('secret-id', 'work'));
      await pumpEventQueue();

      open = (id, profile) async => throw StateError('offline');
      bridge.picks.add(const DockOpenChat('secret-id', 'work'));
      await pumpEventQueue();

      expect(events.named('dock.menu.open_failed'), [
        {'reason': 'unavailable'},
        {'reason': 'network'},
      ]);
    });

    test('ignores a pick while locked or signed out', () async {
      dock.configure(DockMenuState.locked);
      bridge.picks.add(const DockOpenChat('a', 'work'));
      dock.configure(DockMenuState.off);
      bridge.picks.add(const DockOpenChat('a', 'work'));
      await pumpEventQueue();

      expect(opened, isEmpty);
    });
  });

  group('New Chat', () {
    test('starts at once when the app is unlocked', () async {
      dock.configure(DockMenuState.ready);

      bridge.picks.add(const DockNewChat());
      await pumpEventQueue();

      expect(newChats, 1);
      expect(unlockCalls, 0);
      expect(crumbs('dock.menu.action'), [
        {'action': 'new_chat', 'window': false, 'deferred': false},
      ]);
      expect(crumbs('dock.menu.deferred'), isEmpty);
    });

    test('does nothing while signed out', () async {
      bridge.picks.add(const DockNewChat());
      await pumpEventQueue();

      expect(newChats, 0);
    });

    test('while locked, waits for the unlock and then starts', () async {
      dock.configure(DockMenuState.locked);
      prompt = Completer();

      bridge.picks.add(const DockNewChat());
      await pumpEventQueue();
      expect(unlockCalls, 1);
      expect(newChats, 0);

      dock.configure(DockMenuState.ready);
      prompt!.complete(true);
      await pumpEventQueue();

      expect(newChats, 1);
      expect(crumbs('dock.menu.deferred'), [
        {'outcome': 'completed'},
      ]);
      expect(crumbs('dock.menu.action'), [
        {'action': 'new_chat', 'window': false, 'deferred': true},
      ]);
    });

    test('is dropped when the unlock fails, and a later unlock does not '
        'revive it', () async {
      dock.configure(DockMenuState.locked);
      unlocks = false;

      bridge.picks.add(const DockNewChat());
      await pumpEventQueue();
      dock.configure(DockMenuState.ready);
      await pumpEventQueue();

      expect(newChats, 0);
      expect(crumbs('dock.menu.deferred'), [
        {'outcome': 'cancelled'},
      ]);
    });

    test('is dropped by a sign-out while it waits', () async {
      dock.configure(DockMenuState.locked);
      prompt = Completer();
      bridge.picks.add(const DockNewChat());
      await pumpEventQueue();

      dock.configure(DockMenuState.off);
      dock.configure(DockMenuState.ready);
      prompt!.complete(true);
      await pumpEventQueue();

      expect(newChats, 0);
      expect(crumbs('dock.menu.deferred'), [
        {'outcome': 'cancelled'},
      ]);
    });

    test('is dropped when the app locks again while it waits', () async {
      dock.configure(DockMenuState.ready);
      dock.configure(DockMenuState.locked);
      prompt = Completer();
      bridge.picks.add(const DockNewChat());
      await pumpEventQueue();

      dock.configure(DockMenuState.ready);
      dock.configure(DockMenuState.locked);
      prompt!.complete(true);
      await pumpEventQueue();

      expect(newChats, 0);
    });

    test('a newer pick replaces the one that waits', () async {
      dock.configure(DockMenuState.locked);
      prompt = Completer();
      bridge.picks
        ..add(const DockNewChat())
        ..add(const DockNewChat());
      await pumpEventQueue();

      dock.configure(DockMenuState.ready);
      prompt!.complete(true);
      await pumpEventQueue();

      expect(newChats, 1);
      expect(
        [for (final c in crumbs('dock.menu.deferred')) c],
        [
          {'outcome': 'cancelled'},
          {'outcome': 'completed'},
        ],
      );
    });
  });
}
