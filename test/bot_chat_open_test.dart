import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:hermes_app/src/bot_mode/bot_chat_context.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_chat_repository.dart';
import 'package:hermes_app/src/bot_mode/bot_mode_roster_repository.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_hermes_server.dart';

BotChatContext context(String name, String id) => BotChatContext(
  bot: BotModeBot(serverId: 'fixture', name: name, revision: 0),
  rootId: id,
  storedId: id,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeHermesServer server;
  late FakeChatTransport transport;
  late ChatController chat;
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    server = FakeHermesServer();
    transport = FakeChatTransport();
    server.on('GET', '/api/sessions', sessionListBody([]));
    for (final id in ['alpha', 'beta']) {
      server.on(
        'GET',
        '/api/sessions/$id',
        sessionRow(id: id, title: 'Bot Chat'),
      );
      server.on('GET', '/api/sessions/$id/messages', messageListBody(id, []));
    }
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      report: (_) {},
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });
  });
  test(
    'returning after restart resolves stored owner and canonical context',
    () async {
      await chat.openBot(context('research', 'alpha'));
      expect(chat.profile, 'research');
      expect(chat.selectedThread!.botContext!.storedId, 'alpha');
      expect(chat.selectedThread!.title, 'Bot Chat');
    },
  );
  test('late canonical open cannot replace a newly selected bot', () async {
    final gate = Completer<Object?>();
    server.onRequest(
      'GET',
      '/api/sessions/alpha',
      (_) async => (status: 200, body: await gate.future),
    );
    final alpha = chat.openBot(context('research', 'alpha'));
    await pumpEventQueue();
    await chat.openBot(context('writer', 'beta'));
    gate.complete(sessionRow(id: 'alpha', title: 'Bot Chat'));
    await alpha;
    expect(chat.selectedId, 'beta');
    expect(chat.profile, 'writer');
  });
  test('canonical rename and generic archive are prevented; explicit retirement is scoped', () async {
    await chat.openBot(context('research', 'alpha'));
    final thread = chat.selectedThread!;
    await chat.housekeeping!.rename(thread, 'renamed');
    await chat.housekeeping!.archive(thread);
    expect(server.requestsTo('PATCH', '/api/sessions/alpha'), isEmpty);
    expect(thread.title, 'Bot Chat');
    server.on('PATCH', '/api/sessions/alpha', {'ok': true});
    await chat.housekeeping!.archive(thread, retireCanonical: true);
    expect(server.requestsTo('PATCH', '/api/sessions/alpha').length, 1);
    expect(chat.selectedThread, isNull);
  });
  test('unknown mentions and selected handles are preserved without a client handoff', () async {
    await chat.openBot(context('research', 'alpha'));
    chat.submit(
      'Ask @writer; preserve unknown@example.com and @unknown.',
      const [],
    );
    expect(
      transport.sends.single.text,
      'Ask @writer; preserve unknown@example.com and @unknown.',
    );
    expect(transport.sends.single.profile, 'research');
    transport.sends.single.emit(
      const ReplyCompleted('Writer (@writer): attributed reply'),
    );
    await pumpEventQueue();
    expect(transport.sends.length, 1);
    expect(chat.selectedThread!.messages.last.content, contains('@writer'));
  });
  test(
    'canonical new and reset compact while New Chat creates ordinary context',
    () async {
      await chat.openBot(context('research', 'alpha'));
      await chat.runSlashCommand('/new');
      await chat.runSlashCommand('/reset');
      expect(transport.slashRuns, ['/compress', '/compress']);
      expect(chat.selectedThread!.botContext, isNotNull);
      chat.newThread();
      expect(chat.selectedThread!.botContext, isNull);
      expect(chat.selectedThread!.remote, isFalse);
    },
  );
  test(
    'compaction follows the stored tip for history and later sends',
    () async {
      chat.dispose();
      server.on(
        'GET',
        '/api/sessions/alpha-tip/messages',
        messageListBody('alpha-tip', []),
      );
      final attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      addTearDown(attention.dispose);
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: transport,
        botChats: BotModeChatRepository((method, _) async {
          expect(method, 'session.list');
          return {
            'sessions': [
              {'id': 'alpha', 'title': 'Bot Chat', 'resolved_id': 'alpha-tip'},
            ],
          };
        }),
        attention: attention,
        report: (_) {},
      );
      await chat.openBot(context('research', 'alpha'));

      await chat.runSlashCommand('/new');

      expect(chat.selectedId, 'alpha-tip');
      expect(chat.selectedThread!.id, 'alpha-tip');
      expect(chat.selectedThread!.botContext!.rootId, 'alpha');
      expect(chat.selectedThread!.botContext!.storedId, 'alpha-tip');
      expect(
        server.requestsTo('GET', '/api/sessions/alpha-tip/messages'),
        isNotEmpty,
      );
      chat.submit('Next question', const []);
      expect(transport.sends.last.threadId, 'alpha-tip');
      expect(transport.sends.last.profile, 'research');
    },
  );
  test('a failed tip lookup reports completed compaction accurately', () async {
    chat.dispose();
    final reports = <String>[];
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    addTearDown(attention.dispose);
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      botChats: BotModeChatRepository((_, _) async {
        throw StateError('lookup unavailable');
      }),
      attention: attention,
      report: reports.add,
    );
    await chat.openBot(context('research', 'alpha'));

    expect(await chat.runSlashCommand('/reset'), isTrue);
    expect(transport.slashRuns, ['/compress']);
    expect(reports.single, contains('compacted'));
    expect(reports.single, isNot(contains('Could not run')));
  });
}
