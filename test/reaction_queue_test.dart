import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/owned_session_transport.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:hermes_app/src/chat/reactions/reaction_state.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/fake_gateway.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_queue_keys.dart';

const _scope = QueueScope(
  serverKey: 'server',
  accountKey: 'account',
  profile: 'work',
  conversationId: 'stored',
);
const _row = DurableReactionRow(rowId: 42, role: 'user');
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DurableQueueStore store;
  late AttentionNotifier attention;
  late ValueNotifier<bool> activity;
  late ChatController chat;
  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    directory = await Directory.systemTemp.createTemp('reaction-queue-');
    store = DurableQueueStore(directory: directory, keys: FakeQueueKeys());
    await store.commit(_scope, 'Repeated');
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    activity = ValueNotifier(true);
  });
  tearDown(() async {
    chat.dispose();
    attention.dispose();
    activity.dispose();
    await directory.delete(recursive: true);
  });
  Future<void> open(ChatTransport transport) async {
    final server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([sessionRow(id: 'stored')]))
      ..on(
        'GET',
        '/api/sessions/stored/messages',
        messageListBody('stored', [
          {
            ...messageRow(id: 1, role: 'user', content: 'Repeated'),
            'row_id': 21,
          },
          {
            ...messageRow(id: 2, role: 'assistant', content: 'Previous'),
            'row_id': 22,
          },
        ]),
      );
    chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      transport: transport,
      attention: attention,
      activity: activity,
      report: (_) {},
      queueStore: () async => store,
      queueScope: (thread, profile) => QueueScope(
        serverKey: 'server',
        accountKey: 'account',
        profile: profile,
        conversationId: thread.id,
      ),
    );
    await chat.loadThreads('work');
    chat.select('stored');
    final thread = chat.selectedThread!;
    if (chat.queueBusy(thread)) {
      final restored = Completer<void>();
      void changed() {
        if (!chat.queueBusy(thread) && !restored.isCompleted) {
          restored.complete();
        }
      }

      chat.addListener(changed);
      try {
        await restored.future.timeout(const Duration(seconds: 5));
      } finally {
        chat.removeListener(changed);
      }
    }
    await pumpEventQueue();
  }

  MessageReactionsUpdated reaction(OwnedSessionBinding binding) =>
      MessageReactionsUpdated(
        const MessageReactionSnapshot(
          rowId: 42,
          role: 'user',
          reactions: [ReportedReaction(emoji: '🎉', author: 'agent')],
        ),
        runtimeId: binding.runtimeId,
        connection: binding.connection,
      );
  test('actual queue transport stamps receipt and reaction before submit answer binds only deferred user', () async {
    final gateway = FakeGateway()..activeSessions = {};
    gateway.handlers['session.resume'] = (_) => {
      'session_id': 'runtime',
      'stored_session_id': 'stored',
      'session_key': 'stored',
    };
    gateway.handlers['prompt.submit'] = (_) {
      gateway.event('message.reaction', 'runtime', {
        'row_id': 42,
        'role': 'user',
        'reactions': [
          {'emoji': '🎉', 'author': 'agent'},
        ],
      });
      return {'status': 'streaming', 'user_row_id': 42};
    };
    final transport = HermesGatewayTransport(connect: gateway.connect);
    addTearDown(transport.close);
    await open(transport);
    final thread = chat.selectedThread!;
    expect(chat.queueNeedsReview(thread), true);
    final accepted = Completer<void>();
    void changed() {
      if (chat.queuedIn(thread).isEmpty && !accepted.isCompleted) {
        accepted.complete();
      }
    }

    chat.addListener(changed);
    chat.sendQueued(thread);
    try {
      await accepted.future.timeout(const Duration(seconds: 5));
    } finally {
      chat.removeListener(changed);
    }
    await pumpEventQueue();
    final user = thread.messages.where((m) => m.role == ChatRole.user).last;
    expect(user.canonicalRow?.rowId, 42);
    expect(chat.reactionsFor(thread, user.canonicalRow!)?.single.emoji, '🎉');
    expect(thread.messages.first.canonicalRow?.rowId, 21);
    expect(chat.queuedIn(thread), isEmpty);
    expect(
      gateway.methods.where((method) => method == 'prompt.submit'),
      hasLength(1),
    );
  });
  test(
    'pending reaction and canonical receipt wait for distinct typed acceptance',
    () async {
      final transport = _OwnedQueue();
      addTearDown(transport.close);
      await open(transport);
      final thread = chat.selectedThread!;
      chat.sendQueued(thread);
      await transport.prepared.future;
      await pumpEventQueue();
      final send = transport.sends.single;
      send.emit(reaction(transport.binding!));
      send.emit(
        PromptAcknowledged(
          42,
          runtimeId: 'runtime',
          connection: transport.binding!.connection,
        ),
      );
      await pumpEventQueue();
      expect(
        thread.messages.where((m) => m.canonicalRow?.rowId == 42),
        isEmpty,
      );
      expect(chat.queuedIn(thread), hasLength(1));
      expect(chat.reactionsFor(thread, _row), isNull);
      send.emit(const PromptAccepted('streaming'));
      await pumpEventQueue();
      final user = thread.messages
          .where((m) => m.canonicalRow?.rowId == 42)
          .single;
      expect(user.role, ChatRole.user);
      expect(user.content, 'Repeated');
      expect(chat.reactionsFor(thread, _row)?.single.emoji, '🎉');
      expect(thread.messages.first.canonicalRow?.rowId, 21);
      expect(chat.queuedIn(thread), isEmpty);
    },
  );
  for (final stale in ['physical', 'runtime', 'unstamped', 'activity']) {
    test(
      '$stale receipt cannot give canonical identity to deferred queue user',
      () async {
        final transport = _OwnedQueue();
        addTearDown(transport.close);
        await open(transport);
        final thread = chat.selectedThread!;
        chat.sendQueued(thread);
        await transport.prepared.future;
        await pumpEventQueue();
        final send = transport.sends.single;
        if (stale == 'activity') activity.value = false;
        send.emit(
          PromptAcknowledged(
            42,
            runtimeId: stale == 'unstamped'
                ? null
                : stale == 'runtime'
                ? 'old-runtime'
                : 'runtime',
            connection: stale == 'unstamped'
                ? null
                : stale == 'physical'
                ? Object()
                : transport.binding!.connection,
          ),
        );
        send.emit(const PromptAccepted('streaming'));
        await pumpEventQueue();
        expect(
          thread.messages.where((m) => m.canonicalRow?.rowId == 42),
          isEmpty,
        );
        expect(thread.messages.first.canonicalRow?.rowId, 21);
        if (stale != 'activity') {
          expect(
            thread.messages
                .where((m) => m.role == ChatRole.user)
                .last
                .canonicalRow,
            isNull,
          );
        }
      },
    );
  }
}

class _OwnedQueue extends FakeChatTransport
    implements QueueSubmissionTransport, OwnedSessionTransport {
  OwnedSessionBinding? binding = OwnedSessionBinding(
    connection: Object(),
    runtimeId: 'runtime',
    profile: 'work',
  );
  final prepared = Completer<void>();
  final changes = StreamController<OwnedSessionChange>.broadcast(sync: true);
  @override
  Stream<OwnedSessionChange> get ownedSessions => changes.stream;
  @override
  OwnedSessionBinding? ownedSessionFor(String threadId, {String? profile}) =>
      threadId == 'stored' && profile == 'work' ? binding : null;
  @override
  Future<Map<String, Object?>> readOwnedSession(
    OwnedSessionBinding binding,
    String method,
  ) async => throw const FakeRpcError(-32601);
  @override
  Stream<ChatEvent> sendQueued({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    required Future<void> Function() beforeSubmit,
    Future<void> Function()? onNotSubmitted,
  }) async* {
    await beforeSubmit();
    final stream = send(
      threadId: threadId,
      profile: profile,
      text: text,
      attachments: attachments,
      model: model,
      queued: true,
    );
    prepared.complete();
    yield* stream;
  }

  @override
  Future<void> close() async {
    await changes.close();
    await super.close();
  }
}
