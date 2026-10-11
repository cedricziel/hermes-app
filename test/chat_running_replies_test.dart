import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/background/running_replies.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_notification_service.dart';
import 'support/pump_chat.dart';

/// The chats a background run is told about when the app leaves while their
/// reply still runs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHermesServer server;
  late FakeChatTransport transport;
  late AttentionNotifier attention;
  late FakeNotificationService service;
  late RunningReplies running;
  late ChatController chat;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    transport = FakeChatTransport();
    running = RunningReplies();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([
          sessionRow(id: 's1', title: 'Run failure', lastActive: 1780000600),
          sessionRow(id: 's2', title: 'Trip plan', lastActive: 1780000500),
        ]),
        query: {'profile': 'work'},
      )
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 's9', title: 'Elsewhere')]),
        query: {'profile': 'home'},
      )
      ..on(
        'GET',
        '/api/sessions/s1/messages',
        messageListBody('s1', [messageRow(id: 1, role: 'user', content: 'Hi')]),
      )
      ..on(
        'GET',
        '/api/sessions/s2/messages',
        messageListBody('s2', [messageRow(id: 1, role: 'user', content: 'Hi')]),
      );
    service = FakeNotificationService();
    final settings = NotificationSettings();
    await settings.load();
    attention = AttentionNotifier(
      service: service,
      settings: settings,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      runningReplies: running,
      report: (_) {},
    );
  });

  tearDown(() {
    chat.dispose();
    attention.dispose();
  });

  Future<FakeSend> replyIn(String id) async {
    await chat.loadThreads('work');
    chat.select(id);
    await pumpEventQueue();
    chat.submit('Any news?', const []);
    await pumpEventQueue();
    return transport.sends.last;
  }

  test('remembers the chats whose reply runs when the app leaves', () async {
    await replyIn('s1');

    chat.rememberRunningReplies();
    await pumpEventQueue();

    final remembered = await running.read();
    expect(remembered.map((r) => (r.profile, r.threadId)), [('work', 's1')]);
  });

  test('keeps the chats an ask handed over when the app leaves', () async {
    await running.add(
      RunningReply(
        profile: 'work',
        threadId: 'asked',
        since: DateTime.now(),
        fromAsk: true,
      ),
    );
    await replyIn('s1');

    chat.rememberRunningReplies();
    await pumpEventQueue();

    expect((await running.read()).map((r) => r.threadId), ['asked', 's1']);
  });

  test('remembers nothing when no reply runs', () async {
    await chat.loadThreads('work');

    chat.rememberRunningReplies();
    await pumpEventQueue();

    expect(await running.read(), isEmpty);
  });

  test('forgets them when the app returns', () async {
    await replyIn('s1');
    chat.rememberRunningReplies();
    await pumpEventQueue();

    chat.forgetRunningReplies();
    await pumpEventQueue();

    expect(await running.read(), isEmpty);
  });

  test('forgets them when it starts, as a killed app left them', () async {
    await running.replace([
      RunningReply(profile: 'work', threadId: 's9', since: DateTime.now()),
    ]);
    final restarted = ChatController(
      repository: HermesChatRepository(server.client().raw),
      attention: attention,
      runningReplies: running,
      report: (_) {},
    );
    addTearDown(restarted.dispose);
    await pumpEventQueue();

    expect(await running.read(), isEmpty);
  });

  test('forgets a chat whose reply ends after the app left', () async {
    final turn = await replyIn('s1');
    chat.rememberRunningReplies();
    await pumpEventQueue();

    turn.emit(const ReplyCompleted('Nothing new.'));
    await pumpEventQueue();

    expect(await running.read(), isEmpty);
  });

  test('keeps the other chats when one reply ends', () async {
    final first = await replyIn('s1');
    chat.select('s2');
    await pumpEventQueue();
    chat.submit('And here?', const []);
    await pumpEventQueue();
    chat.rememberRunningReplies();
    await pumpEventQueue();

    first.emit(const ReplyCompleted('Nothing new.'));
    await pumpEventQueue();

    expect((await running.read()).map((r) => r.threadId), ['s2']);
  });

  group('across profiles', () {
    test(
      'keeps a reply that runs on after a switch to another profile',
      () async {
        await replyIn('s1');
        await chat.loadThreads('home');

        chat.rememberRunningReplies();
        await pumpEventQueue();

        expect((await running.read()).map((r) => (r.profile, r.threadId)), [
          ('work', 's1'),
        ]);
      },
    );

    test('adds the replies of both profiles', () async {
      await replyIn('s1');
      await chat.loadThreads('home');
      chat.select('s9');
      await pumpEventQueue();
      chat.submit('Here too', const []);
      await pumpEventQueue();

      chat.rememberRunningReplies();
      await pumpEventQueue();

      expect(
        (await running.read()).map((r) => (r.profile, r.threadId)),
        unorderedEquals([('work', 's1'), ('home', 's9')]),
      );
    });

    test('keeps it when the profile is loaded again', () async {
      await replyIn('s1');
      await chat.loadThreads('home');
      await chat.loadThreads('work');

      chat.rememberRunningReplies();
      await pumpEventQueue();

      expect((await running.read()).map((r) => r.threadId), ['s1']);
    });

    test('forgets it when its reply ends in the other profile', () async {
      final turn = await replyIn('s1');
      await chat.loadThreads('home');
      turn.emit(const ReplyCompleted('Done.'));
      await pumpEventQueue();

      chat.rememberRunningReplies();
      await pumpEventQueue();

      expect(await running.read(), isEmpty);
    });

    test(
      'lets go of a reply that a run ended while the app was away',
      () async {
        await replyIn('s1');
        await chat.loadThreads('home');
        chat.rememberRunningReplies();
        await pumpEventQueue();
        await running.forget([
          RunningReply(profile: 'work', threadId: 's1', since: DateTime.now()),
        ]);

        chat.forgetRunningReplies();
        await pumpEventQueue();
        chat.rememberRunningReplies();
        await pumpEventQueue();

        expect(await running.read(), isEmpty);
      },
    );
  });

  group('how long a remembered reply counts', () {
    ChatController chatAt(DateTime Function() now) {
      final other = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: transport,
        attention: attention,
        runningReplies: running,
        now: now,
        report: (_) {},
      );
      addTearDown(other.dispose);
      return other;
    }

    test('keeps the time it was first remembered across pauses', () async {
      await replyIn('s1');
      chat.rememberRunningReplies();
      await pumpEventQueue();
      final first = (await running.read()).single.since;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      chat.forgetRunningReplies();
      await pumpEventQueue();
      chat.rememberRunningReplies();
      await pumpEventQueue();

      expect((await running.read()).single.since, first);
    });

    test('lets a reply carried out of its profile expire', () async {
      var now = DateTime.utc(2026, 10, 11, 8);
      final aging = chatAt(() => now);
      await aging.loadThreads('work');
      aging.select('s1');
      await pumpEventQueue();
      aging.submit('Any news?', const []);
      await pumpEventQueue();
      await aging.loadThreads('home');
      aging.rememberRunningReplies();
      await pumpEventQueue();
      expect(await running.read(), hasLength(1));

      now = now.add(const Duration(hours: 25));
      aging.forgetRunningReplies();
      await pumpEventQueue();
      aging.rememberRunningReplies();
      await pumpEventQueue();

      expect(await running.read(), isEmpty);
    });

    test('keeps the list of a pause that comes while the return is still '
        'asking the server', () async {
      final held = _HeldStatuses();
      final slow = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: held,
        attention: attention,
        runningReplies: running,
        report: (_) {},
      );
      addTearDown(slow.dispose);
      await slow.loadThreads('work');
      slow.select('s1');
      await pumpEventQueue();
      slow.submit('Any news?', const []);
      await pumpEventQueue();
      await slow.loadThreads('home');
      slow.rememberRunningReplies();
      await pumpEventQueue();
      held.gate = Completer<void>();

      slow.forgetRunningReplies();
      await pumpEventQueue();
      slow.rememberRunningReplies();
      await pumpEventQueue();
      held.gate!.complete();
      await pumpEventQueue();

      expect((await running.read()).map((r) => r.threadId), ['s1']);
    });

    test('keeps what a pause carried while the return is still reading the '
        'list', () async {
      final held = _HeldRead();
      final slow = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: transport,
        attention: attention,
        runningReplies: held,
        report: (_) {},
      );
      addTearDown(slow.dispose);
      await slow.loadThreads('work');
      slow.select('s1');
      await pumpEventQueue();
      slow.submit('Any news?', const []);
      await pumpEventQueue();
      await slow.loadThreads('home');
      slow.rememberRunningReplies();
      await pumpEventQueue();
      held.gate = Completer<void>();

      slow.forgetRunningReplies();
      await pumpEventQueue();
      slow.select('s9');
      await pumpEventQueue();
      slow.submit('Here too', const []);
      await pumpEventQueue();
      await slow.loadThreads('work');
      slow.rememberRunningReplies();
      await pumpEventQueue();
      held.gate!.complete();
      await pumpEventQueue();
      slow.rememberRunningReplies();
      await pumpEventQueue();

      expect(
        (await held.read()).map((r) => (r.profile, r.threadId)),
        unorderedEquals([('work', 's1'), ('home', 's9')]),
      );
    });

    test('drops a carried reply whose session no longer runs', () async {
      await replyIn('s1');
      await chat.loadThreads('home');
      chat.rememberRunningReplies();
      await pumpEventQueue();
      transport.activeInProfile['work'] = {'s1': 'idle'};

      chat.forgetRunningReplies();
      await pumpEventQueue();
      chat.rememberRunningReplies();
      await pumpEventQueue();

      expect(await running.read(), isEmpty);
    });

    test('keeps a carried reply whose session still works', () async {
      await replyIn('s1');
      await chat.loadThreads('home');
      chat.rememberRunningReplies();
      await pumpEventQueue();
      transport.activeInProfile['work'] = {'s1': 'working'};

      chat.forgetRunningReplies();
      await pumpEventQueue();
      chat.rememberRunningReplies();
      await pumpEventQueue();

      expect((await running.read()).map((r) => r.threadId), ['s1']);
    });
  });

  group('a reply a background run announced', () {
    RunningReply announced() =>
        RunningReply(profile: 'work', threadId: 's1', since: DateTime.now());

    Future<FakeSend> awayReply() async {
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      addTearDown(
        () => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      return replyIn('s1');
    }

    test('is not announced again when its ending arrives on return', () async {
      final turn = await awayReply();
      chat.rememberRunningReplies();
      await running.markAnnounced([announced()]);

      turn.emit(const ReplyCompleted('Done.'));
      await pumpEventQueue();

      expect(service.shown, isEmpty);
    });

    test('is announced when no run announced it', () async {
      final turn = await awayReply();

      turn.emit(const ReplyCompleted('Done.'));
      await pumpEventQueue();

      expect(service.shown.single.body, 'Done.');
    });

    test('is checked only once', () async {
      final turn = await awayReply();
      await running.markAnnounced([announced()]);
      turn.emit(const ReplyCompleted('Done.'));
      await pumpEventQueue();

      chat.submit('And again?', const []);
      await pumpEventQueue();
      transport.sends.last.emit(const ReplyCompleted('Again.'));
      await pumpEventQueue();

      expect(service.shown.map((n) => n.body), ['Again.']);
    });

    ChatController resumedWith(Duration grace) {
      final other = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: transport,
        attention: attention,
        runningReplies: running,
        replayGrace: grace,
        report: (_) {},
      );
      addTearDown(other.dispose);
      return other;
    }

    test(
      'stops silencing once the replay on return has had its time',
      () async {
        final back = resumedWith(const Duration(milliseconds: 80));
        TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.paused,
        );
        addTearDown(
          () => TestWidgetsFlutterBinding.instance
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed),
        );
        await back.loadThreads('work');
        back.select('s1');
        await pumpEventQueue();
        back.submit('Any news?', const []);
        await pumpEventQueue();
        final turn = transport.sends.last;
        back.rememberRunningReplies();
        await running.markAnnounced([announced()]);
        back.forgetRunningReplies();
        await Future<void>.delayed(const Duration(milliseconds: 250));

        turn.emit(const ReplyCompleted('Later.'));
        await pumpEventQueue();

        expect(service.shown.map((n) => n.body), ['Later.']);
      },
    );

    test('still silences the replayed ending within that time', () async {
      final back = resumedWith(const Duration(seconds: 5));
      TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      addTearDown(
        () => TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await back.loadThreads('work');
      back.select('s1');
      await pumpEventQueue();
      back.submit('Any news?', const []);
      await pumpEventQueue();
      final turn = transport.sends.last;
      back.rememberRunningReplies();
      await running.markAnnounced([announced()]);
      back.forgetRunningReplies();

      turn.emit(const ReplyCompleted('Done.'));
      await pumpEventQueue();

      expect(service.shown, isEmpty);
    });

    test('is forgotten when the user sends a new prompt in the chat', () async {
      final turn = await awayReply();
      turn.emit(const ReplyCompleted('Done.'));
      await pumpEventQueue();
      await running.markAnnounced([announced()]);

      chat.submit('Next', const []);
      await pumpEventQueue();

      expect(await running.readAnnounced(), isEmpty);
    });

    test('is forgotten when the app is left again', () async {
      await running.markAnnounced([announced()]);

      chat.rememberRunningReplies();
      await pumpEventQueue();

      expect(await running.readAnnounced(), isEmpty);
    });

    test('is forgotten at start', () async {
      await running.markAnnounced([announced()]);
      final restarted = ChatController(
        repository: HermesChatRepository(server.client().raw),
        attention: attention,
        runningReplies: running,
        report: (_) {},
      );
      addTearDown(restarted.dispose);
      await pumpEventQueue();

      expect(await running.readAnnounced(), isEmpty);
    });
  });

  group('on the chat screen', () {
    final mark = RunningReply(
      profile: 'work',
      threadId: 's9',
      since: DateTime.utc(2026, 10, 11),
    );

    testWidgets('leaving the app writes the list', (tester) async {
      final store = RunningReplies();
      await pumpChatScreen(
        tester,
        providers: [Provider<RunningReplies?>.value(value: store)],
      );
      await tester.runAsync(() => store.replace([mark]));

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }

      // The write reads the stored list first, which takes both clocks.
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(pumpEventQueue);
        await tester.pump();
      }
      // The mock chats are not on the server, so none is remembered.
      expect(
        await tester.runAsync(() async {
          await pumpEventQueue();
          return store.read();
        }),
        isEmpty,
      );
    });

    testWidgets('coming back clears it', (tester) async {
      final store = RunningReplies();
      await pumpChatScreen(
        tester,
        providers: [Provider<RunningReplies?>.value(value: store)],
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.runAsync(() => store.replace([mark]));

      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }

      expect(
        await tester.runAsync(() async {
          await pumpEventQueue();
          return store.read();
        }),
        isEmpty,
      );
    });
  });
}

/// A transport whose answer about live sessions can be held back.
class _HeldStatuses extends FakeChatTransport {
  Completer<void>? gate;

  @override
  Future<Map<String, String>> activeStatuses({String? profile}) async {
    await gate?.future;
    return {};
  }
}

/// A list whose read answers with what it held when asked, but late.
class _HeldRead extends RunningReplies {
  Completer<void>? gate;

  @override
  Future<List<RunningReply>> read() async {
    final held = await super.read();
    await gate?.future;
    return held;
  }
}
