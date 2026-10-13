import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_thread_bindings.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/chat/reactions/reaction_state.dart';
import 'package:hermes_app/src/chat/session_chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_attachment_source.dart';
import 'support/fake_chat_transport.dart';
import 'support/fake_gateway.dart';
import 'support/fake_hermes_server.dart';

void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late FakeHermesServer server;
  late AttentionNotifier attention;
  late ChatController chat;
  const row21 = DurableReactionRow(rowId: 21, role: 'user');
  const row22 = DurableReactionRow(rowId: 22, role: 'assistant');
  List<Map<String, Object?>> history() => [
    {...messageRow(id: 1, role: 'user', content: 'Repeated'), 'row_id': 21},
    {
      ...messageRow(id: 2, role: 'assistant', content: 'Repeated'),
      'row_id': 22,
    },
    messageRow(id: 21, role: 'user', content: 'Repeated'),
  ];
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['session.resume'] = (params) => {
      'session_id': params['profile'] == 'other' ? 'rt-2' : 'rt-1',
      'stored_session_id': params['session_key'] ?? 'stored-1',
      'session_key': params['session_key'] ?? 'stored-1',
    };
    transport = HermesGatewayTransport(connect: gateway.connect);
    server = FakeHermesServer()
      ..on(
        'GET',
        '/api/sessions',
        sessionListBody([sessionRow(id: 'stored-1', title: 'Reaction test')]),
      )
      ..on(
        'GET',
        '/api/sessions/stored-1/messages',
        messageListBody('stored-1', history()),
      );
    attention = AttentionNotifier(
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
  });
  tearDown(() async {
    chat.dispose();
    attention.dispose();
    await transport.close();
  });
  Future<void> open() async {
    await chat.loadThreads('work');
    chat.select('stored-1');
    await pumpEventQueue();
  }

  void reaction(int id, String role, String emoji, {String runtime = 'rt-1'}) =>
      gateway.event('message.reaction', runtime, {
        'row_id': id,
        'role': role,
        'reactions': [
          {'emoji': emoji, 'author': 'agent'},
        ],
      });

  test('actual watched reactions match canonical row and role rather than repeated text or aliases', () async {
    await open();
    final thread = chat.selectedThread!;
    reaction(21, 'user', '👍');
    reaction(22, 'user', 'Wrong role');
    reaction(21, 'user', 'Foreign', runtime: 'other');
    await pumpEventQueue();
    expect(chat.reactionsFor(thread, row21)?.single.emoji, '👍');
    expect(chat.reactionsFor(thread, row22), isEmpty);
    expect(thread.messages.last.canonicalRow, isNull);
    expect(thread.messages.map((message) => message.content), [
      'Repeated',
      'Repeated',
      'Repeated',
    ]);
    gateway.event('message.reaction', 'rt-1', {
      'row_id': 21,
      'role': 'user',
      'reactions': [],
    });
    await pumpEventQueue();
    expect(chat.reactionsFor(thread, row21), isEmpty);
  });

  test('live own user binds from its exact physical submit receipt even when reaction arrived first', () async {
    await open();
    gateway.handlers['prompt.submit'] = (params) {
      reaction(42, 'user', '🎉');
      return {'status': 'streaming', 'user_row_id': 42};
    };
    chat.submit('Repeated', const []);
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    final ownUser = thread.messages[thread.messages.length - 2];
    expect(ownUser.canonicalRow?.rowId, 42);
    expect(ownUser.canonicalRow?.role, 'user');
    expect(
      chat.reactionsFor(thread, ownUser.canonicalRow!)?.single.emoji,
      '🎉',
    );
    expect(thread.messages.first.canonicalRow?.rowId, 21);
    expect(thread.messages.last.role, ChatRole.assistant);
    expect(thread.isReplying, isTrue);
    gateway.event('message.complete', 'rt-1', {
      'text': 'Main',
      'status': 'complete',
    });
    await pumpEventQueue();
    expect(thread.messages.last.content, 'Main');
  });

  test('identity-free supported acknowledgement does not assign a message or settle main reply', () async {
    await open();
    chat.submit('New prompt', const []);
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    gateway.event('reaction', 'rt-1', {'kind': 'future'});
    gateway.event('reaction', 'rt-1', {'kind': 'vibe'});
    await pumpEventQueue();
    expect(
      chat.reactionsIn(thread)?.acknowledgement,
      SessionAcknowledgement.vibe,
    );
    expect(chat.reactionsFor(thread, row21), isEmpty);
    expect(chat.reactionsFor(thread, row22), isEmpty);
    expect(thread.messages[thread.messages.length - 2].canonicalRow, isNull);
    expect(thread.isReplying, isTrue);
    gateway.event('message.complete', 'rt-1', {
      'text': 'Main',
      'status': 'complete',
    });
    await pumpEventQueue();
  });

  test('pending unknown row reconciles with later existing history and live state beats older metadata', () async {
    await open();
    final thread = chat.selectedThread!;
    reaction(99, 'assistant', '🎉');
    await pumpEventQueue();
    expect(chat.reactionsIn(thread)?.pendingCount, 1);
    server.on(
      'GET',
      '/api/sessions/stored-1',
      sessionRow(
        id: 'stored-1',
        title: 'Reaction test',
        lastActive: 1780000060,
      ),
    );
    server.on(
      'GET',
      '/api/sessions/stored-1/messages',
      messageListBody('stored-1', [
        ...history(),
        {
          ...messageRow(id: 3, role: 'assistant', content: 'Loaded later'),
          'row_id': 99,
          'display_metadata': {
            'reactions': [
              {'emoji': 'Older', 'author': 'agent'},
            ],
          },
        },
      ]),
    );
    await chat.refreshThread('stored-1');
    await pumpEventQueue();
    expect(chat.reactionsIn(thread)?.pendingCount, 0);
    expect(
      chat
          .reactionsFor(
            thread,
            const DurableReactionRow(rowId: 99, role: 'assistant'),
          )
          ?.single
          .emoji,
      '🎉',
    );
  });

  test('compression retarget retains inherited row lineage on the same verified runtime', () async {
    await open();
    final thread = chat.selectedThread!;
    reaction(21, 'user', '👍');
    await pumpEventQueue();
    final state = chat.reactionsIn(thread);
    gateway.event('session.info', 'rt-1', {
      'stored_session_id': 'child-session',
    });
    await pumpEventQueue();
    expect(thread.id, 'child-session');
    expect(chat.reactionsIn(thread), same(state));
    expect(chat.reactionsFor(thread, row21)?.single.emoji, '👍');
    reaction(21, 'user', '🎉');
    await pumpEventQueue();
    expect(chat.reactionsFor(thread, row21)?.single.emoji, '🎉');
  });

  test('profile and reclaimed owners clear live badges and pending rows before late delivery', () async {
    await open();
    final oldThread = chat.selectedThread!;
    reaction(21, 'user', 'Old');
    reaction(99, 'user', 'Pending');
    await pumpEventQueue();
    final oldState = chat.reactionsIn(oldThread)!;
    await chat.loadThreads('other');
    chat.select('stored-1');
    await pumpEventQueue();
    reaction(21, 'user', 'Late');
    reaction(21, 'user', 'Current', runtime: 'rt-2');
    await pumpEventQueue();
    final thread = chat.selectedThread!;
    expect(oldState.pendingCount, 0);
    expect(chat.reactionsIn(oldThread), isNull);
    expect(chat.reactionsFor(thread, row21)?.single.emoji, 'Current');
    gateway.event('session.reclaimed', '', {
      'session_id': 'rt-2',
      'stored_session_id': 'stored-1',
      'reason': 'Synthetic',
    });
    await pumpEventQueue();
    reaction(21, 'user', 'Retired', runtime: 'rt-2');
    await pumpEventQueue();
    expect(chat.reactionsIn(thread), isNull);
  });

  test('protected activity retirement hides badges and late frames through the actual wrapper', () async {
    chat.dispose();
    final activity = ValueNotifier(true);
    addTearDown(activity.dispose);
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: SessionChatTransport(() => transport),
      activity: activity,
      attention: attention,
      report: (_) {},
    );
    await open();
    final thread = chat.selectedThread!;
    reaction(21, 'user', 'Protected');
    await pumpEventQueue();
    expect(chat.reactionsFor(thread, row21)?.single.emoji, 'Protected');
    activity.value = false;
    reaction(21, 'user', 'Retired');
    await pumpEventQueue();
    expect(chat.reactionsIn(thread), isNull);
    expect(chat.reactionsFor(thread, row21), isNull);
  });

  test('follow-up receipts never bind a nearest live user and old physical frames cannot reappear', () async {
    chat.dispose();
    final owned = _OwnedTransport();
    addTearDown(owned.close);
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: owned,
      attention: attention,
      report: (_) {},
    );
    await open();
    final thread = chat.selectedThread!;
    final old = owned.binding!;
    final follow = owned.followUpStreams['stored-1']!;
    follow.emit(
      PromptAcknowledged(
        77,
        runtimeId: old.runtimeId,
        connection: old.connection,
      ),
    );
    follow.emit(
      MessageReactionsUpdated(
        MessageReactionSnapshot.decode({
          'row_id': 21,
          'role': 'user',
          'reactions': [
            {'emoji': 'Old', 'author': 'agent'},
          ],
        })!,
        runtimeId: old.runtimeId,
        connection: old.connection,
      ),
    );
    await pumpEventQueue();
    expect(thread.messages.last.canonicalRow, isNull);
    expect(chat.reactionsFor(thread, row21)?.single.emoji, 'Old');
    owned.replace();
    final current = owned.binding!;
    follow.emit(
      MessageReactionsUpdated(
        MessageReactionSnapshot.decode({
          'row_id': 21,
          'role': 'user',
          'reactions': [
            {'emoji': 'Late', 'author': 'agent'},
          ],
        })!,
        runtimeId: old.runtimeId,
        connection: old.connection,
      ),
    );
    follow.emit(
      MessageReactionsUpdated(
        MessageReactionSnapshot.decode({
          'row_id': 21,
          'role': 'user',
          'reactions': [
            {'emoji': 'New', 'author': 'agent'},
          ],
        })!,
        runtimeId: current.runtimeId,
        connection: current.connection,
      ),
    );
    await pumpEventQueue();
    expect(chat.reactionsFor(thread, row21)?.single.emoji, 'New');
  });

  test(
    'earlier Todo ownership notification cannot expose old reaction scope',
    () async {
      chat.dispose();
      final owned = _OwnedTransport();
      addTearDown(owned.close);
      chat = ChatController(
        repository: HermesChatRepository(server.client().raw),
        transport: owned,
        attention: attention,
        report: (_) {},
      );
      await open();
      final thread = chat.selectedThread!;
      final binding = owned.binding!;
      owned.followUpStreams['stored-1']!.emit(
        MessageReactionsUpdated(
          MessageReactionSnapshot.decode({
            'row_id': 21,
            'role': 'user',
            'reactions': [
              {'emoji': 'Old owner', 'author': 'agent'},
            ],
          })!,
          runtimeId: binding.runtimeId,
          connection: binding.connection,
        ),
      );
      await pumpEventQueue();
      expect(chat.reactionsFor(thread, row21)?.single.emoji, 'Old owner');
      final observed = <String>[];
      chat.addListener(
        () => observed.addAll(
          chat.reactionsFor(thread, row21)?.map((value) => value.emoji) ??
              const [],
        ),
      );
      owned.replace();
      await pumpEventQueue();
      expect(observed, isNot(contains('Old owner')));
      expect(chat.reactionsFor(thread, row21), isEmpty);
    },
  );

  test('reaction notification activity retirement clears state without a notifier disposal exception', () async {
    chat.dispose();
    final activity = ValueNotifier(true);
    addTearDown(activity.dispose);
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: SessionChatTransport(() => transport),
      activity: activity,
      attention: attention,
      report: (_) {},
    );
    await open();
    final thread = chat.selectedThread!;
    chat.addListener(() {
      if (chat.reactionsFor(thread, row21)?.isNotEmpty ?? false) {
        activity.value = false;
      }
    });
    reaction(21, 'user', 'Protected');
    await pumpEventQueue();
    expect(activity.value, isFalse);
    expect(chat.reactionsIn(thread), isNull);
  });

  testWidgets(
    'actual bound chat shows supplied row badge and separate identity-free acknowledgement',
    (tester) async {
      await tester.runAsync(() async {
        await open();
        reaction(21, 'user', '👍');
        gateway.event('reaction', 'rt-1', {'kind': 'vibe'});
        await pumpEventQueue();
      });
      final composer = TextEditingController();
      final focus = FocusNode();
      final latest = LatestReply();
      addTearDown(composer.dispose);
      addTearDown(focus.dispose);
      addTearDown(latest.dispose);
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: chat,
              builder: (context, _) => boundChatThreadView(
                chat: chat,
                thread: chat.selectedThread,
                composerController: composer,
                composerFocus: focus,
                attachments: const [],
                attachmentSource: FakeAttachmentSource(),
                onAddAttachments: (_) {},
                onRemoveAttachment: (_) {},
                onSend: (_) {},
                latestReply: latest,
              ),
            ),
          ),
        ),
      );
      expect(find.text('👍 · agent'), findsOneWidget);
      expect(find.text('Session acknowledgement'), findsOneWidget);
      await tester.tap(find.text('Message reactions'));
      await tester.pumpAndSettle();
      expect(find.text('Author: agent'), findsOneWidget);
      await tester.runAsync(() async {
        gateway.event('message.reaction', 'rt-1', {
          'row_id': 21,
          'role': 'user',
          'reactions': [],
        });
        await pumpEventQueue();
      });
      await tester.pump();
      expect(find.text('👍 · agent'), findsNothing);
      expect(find.text('Session acknowledgement'), findsOneWidget);
    },
  );
}

class _OwnedTransport extends FakeChatTransport
    implements OwnedSessionTransport {
  OwnedSessionBinding? binding = OwnedSessionBinding(
    connection: Object(),
    runtimeId: 'same-runtime',
    profile: 'work',
  );
  final _changes = StreamController<OwnedSessionChange>.broadcast(sync: true);
  @override
  Stream<OwnedSessionChange> get ownedSessions => _changes.stream;
  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) =>
      threadId == 'stored-1' && binding?.profile == profile ? binding : null;
  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async => throw const FakeRpcError(-32601);
  void replace() {
    binding = OwnedSessionBinding(
      connection: Object(),
      runtimeId: 'same-runtime',
      profile: 'work',
    );
    _changes.add(OwnedSessionChange('stored-1', binding!));
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await super.close();
  }
}
