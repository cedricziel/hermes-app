import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/agent_messages/agent_message_watcher.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/widgets/thread_sidebar.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/profiles/hermes_profiles_repository.dart';
import 'package:provider/provider.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';
import 'support/pump_chat.dart';

/// A message from Hermes found for the shown profile puts its chat in the
/// list without a refresh, and leaves the open chat as it was.
void main() {
  late FakeHermesServer server;
  late AgentMessageFinds finds;

  void list(List<Map<String, Object?>> rows) => server.on(
    'GET',
    '/api/sessions',
    sessionListBody(rows),
    query: {'profile': 'work'},
  );

  setUp(() {
    finds = AgentMessageFinds();
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'work', isDefault: true),
          profileRow(name: 'home'),
        ]),
      )
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'work'))
      ..on(
        'GET',
        '/api/sessions/recent/messages',
        messageListBody('recent', [
          messageRow(id: 1, role: 'assistant', content: 'the recent chat'),
        ]),
      );
    list([sessionRow(id: 'recent', title: 'Recent chat')]);
  });

  tearDown(() => finds.dispose());

  Future<void> pump(WidgetTester tester) => pumpChatScreen(
    tester,
    server: server,
    withProfiles: true,
    providers: [ChangeNotifierProvider.value(value: finds)],
  );

  Finder inSidebar(String title) => find.descendant(
    of: find.byType(ThreadSidebar),
    matching: find.text(title),
  );

  int lists() => server.requestsTo('GET', '/api/sessions').length;

  testWidgets(
    'a find in the shown profile adds the chat and keeps the open one',
    (tester) async {
      await pump(tester);
      await openThread(tester, 'Recent chat');
      list([
        sessionRow(
          id: 'hermes-app-1',
          title: 'Message: Report',
          source: 'hermes_app',
          unread: true,
        ),
        sessionRow(id: 'recent', title: 'Recent chat'),
      ]);

      finds.report({'work'});
      await tester.pumpAndSettle();

      expect(inSidebar('Message: Report'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Chat),
          matching: find.textContaining('the recent chat', findRichText: true),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('a find keeps the draft in the composer', (tester) async {
    await pump(tester);
    await tester.enterText(composerField, 'half a thought');
    list([
      sessionRow(id: 'hermes-app-1', title: 'Message: Report', unread: true),
      sessionRow(id: 'recent', title: 'Recent chat'),
    ]);

    finds.report({'work'});
    await tester.pumpAndSettle();

    expect(inSidebar('Message: Report'), findsOneWidget);
    expect(
      tester.widget<EditableText>(composerField).controller.text,
      'half a thought',
    );
  });

  testWidgets('a find in another profile reads nothing', (tester) async {
    await pump(tester);
    final before = lists();

    finds.report({'home'});
    await tester.pumpAndSettle();

    expect(lists(), before);
  });

  group('ChatController.refreshThreadList', () {
    late FakeChatTransport transport;
    late AttentionNotifier attention;
    late ChatController chat;

    setUp(() async {
      transport = FakeChatTransport();
      attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      chat = ChatController(
        repository: HermesChatRepository(HermesApiClient(server.dio()).raw),
        profiles: HermesProfilesRepository(HermesApiClient(server.dio()).raw),
        transport: transport,
        attention: attention,
        report: (_) {},
      );
      addTearDown(() {
        chat.dispose();
        attention.dispose();
      });
      await chat.loadThreads();
    });

    ChatThread thread(String id) => chat.threads.firstWhere((t) => t.id == id);

    final delivered = sessionRow(
      id: 'hermes-app-1',
      title: 'Message: Report',
      source: 'hermes_app',
      unread: true,
    );

    test('waits for a list that is loading and then reads again', () async {
      final held = Completer<void>();
      var served = 0;
      server.onRequest('GET', '/api/sessions', (_) async {
        if (served++ == 0) await held.future;
        return (
          status: 200,
          body: sessionListBody([
            delivered,
            sessionRow(id: 'recent', title: 'Recent chat'),
          ]),
        );
      }, query: {'profile': 'work'});
      final loading = chat.loadThreads();
      await pumpEventQueue();

      await chat.refreshThreadList();
      expect(served, 1);

      held.complete();
      await loading;
      await pumpEventQueue();

      expect(served, 2);
      expect(chat.threads.map((t) => t.id), contains('hermes-app-1'));
    });

    test('reads again when a change starts while it reads', () async {
      final readHeld = Completer<void>();
      final archiveHeld = Completer<void>();
      var served = 0;
      server
        ..onRequest('GET', '/api/sessions', (_) async {
          if (served++ == 0) await readHeld.future;
          return (
            status: 200,
            body: sessionListBody([
              delivered,
              sessionRow(id: 'recent', title: 'Recent chat'),
            ]),
          );
        }, query: {'profile': 'work'})
        ..onRequest('PATCH', '/api/sessions/recent', (_) async {
          await archiveHeld.future;
          return (status: 200, body: sessionPatchBody());
        });

      final refreshing = chat.refreshThreadList();
      await pumpEventQueue();
      final archiving = chat.housekeeping!.archive(thread('recent'));
      await pumpEventQueue();
      expect(chat.threadListInvalidationBlocked, isTrue);

      readHeld.complete();
      await refreshing;
      expect(chat.threads.map((t) => t.id), isNot(contains('hermes-app-1')));

      archiveHeld.complete();
      await archiving;
      await pumpEventQueue();

      expect(served, 2);
      expect(chat.threads.map((t) => t.id), contains('hermes-app-1'));
    });

    test('drops a waiting read when another profile loads', () async {
      final archiveHeld = Completer<void>();
      server
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'other', title: 'Other')]),
          query: {'profile': 'home'},
        )
        ..onRequest('PATCH', '/api/sessions/recent', (_) async {
          await archiveHeld.future;
          return (status: 200, body: sessionPatchBody());
        });
      final archiving = chat.housekeeping!.archive(thread('recent'));
      await pumpEventQueue();
      await chat.refreshThreadList();

      await chat.loadThreads('home');
      archiveHeld.complete();
      await archiving;
      await pumpEventQueue();

      final homeLists = server
          .requestsTo('GET', '/api/sessions')
          .where((r) => r.queryParameters['profile'] == 'home');
      expect(homeLists, hasLength(1));
    });

    test('is not run again once it has been run', () async {
      final held = Completer<void>();
      var served = 0;
      server.onRequest('GET', '/api/sessions', (_) async {
        if (served++ == 0) await held.future;
        return (
          status: 200,
          body: sessionListBody([sessionRow(id: 'recent', title: 'Recent')]),
        );
      }, query: {'profile': 'work'});
      final loading = chat.loadThreads();
      await pumpEventQueue();
      await chat.refreshThreadList();
      held.complete();
      await loading;
      await pumpEventQueue();
      chat.select('recent');
      await pumpEventQueue();

      expect(served, 2);
    });

    test('keeps a chat nothing was sent in at the top', () async {
      chat.newThread();
      final local = chat.selectedThread!;
      // Newer than the unsent chat, which the list's own order would put first.
      list([
        sessionRow(
          id: 'hermes-app-1',
          title: 'Message: Report',
          source: 'hermes_app',
          unread: true,
          lastActive: 4102444800,
        ),
        sessionRow(id: 'recent', title: 'Recent chat'),
      ]);

      await chat.refreshThreadList();

      expect(chat.threads.first, same(local));
      expect(chat.selectedId, local.id);
      expect(chat.threads.map((t) => t.id), contains('hermes-app-1'));
    });

    test('never marks the open chat unread', () async {
      chat.select('recent');
      await pumpEventQueue();
      expect(thread('recent').unread, isFalse);
      list([sessionRow(id: 'recent', title: 'Recent chat', unread: true)]);

      await chat.refreshThreadList();

      expect(thread('recent').unread, isFalse);
    });

    test('marks a chat that is not open unread', () async {
      list([sessionRow(id: 'recent', title: 'Recent chat', unread: true)]);

      await chat.refreshThreadList();

      expect(thread('recent').unread, isTrue);
    });

    test(
      'leaves a reply in flight and a queued prompt where they are',
      () async {
        chat.select('recent');
        await pumpEventQueue();
        chat.submit('First', const []);
        await pumpEventQueue();
        chat.submit('Second', const []);
        await pumpEventQueue();
        final replying = thread('recent');
        expect(replying.isReplying, isTrue);
        expect(chat.queuedIn(replying).map((p) => p.text), ['Second']);
        final messages = replying.messages.length;
        list([delivered]);

        await chat.refreshThreadList();

        expect(thread('recent'), same(replying));
        expect(replying.isReplying, isTrue);
        expect(replying.messages, hasLength(messages));
        expect(chat.queuedIn(replying).map((p) => p.text), ['Second']);
        expect(transport.sends, hasLength(1));
      },
    );
  });
}
