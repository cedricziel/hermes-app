import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:hermes_app/src/models/model_provider_option.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/workspaces/workspace_models.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_queue_keys.dart';
import '../support/fake_queue_transport.dart';
import '../support/queue_store_dir.dart';

/// A transport whose reply streams deliver an event the moment it is added,
/// so a test can change the controller's state at an exact point inside a
/// synchronous stretch of the send path (a real stream delivers later).
class _SyncReplyTransport extends FakeChatTransport {
  final replies = <StreamController<ChatEvent>>[];

  @override
  Stream<ChatEvent> send({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    bool queued = false,
    WorkspaceChoice? workspace,
    void Function()? onSubmitting,
    bool voiceTurn = false,
    bool interrupted = false,
    bool Function()? authorize,
  }) {
    super.send(
      threadId: threadId,
      profile: profile,
      text: text,
      attachments: attachments,
      model: model,
      queued: queued,
      workspace: workspace,
      onSubmitting: onSubmitting,
      voiceTurn: voiceTurn,
      interrupted: interrupted,
      authorize: authorize,
    );
    final reply = StreamController<ChatEvent>(sync: true);
    replies.add(reply);
    return reply.stream;
  }
}

/// A queue transport that, once Hermes accepted the prompt, asks the
/// controller to begin the same submission again, as a transport that
/// re-sent after a reconnect would. [again] completes with what that threw.
class _LateSubmitTransport extends FakeQueueTransport {
  final lateCall = Completer<void>();
  final again = Completer<Object?>();

  @override
  Stream<ChatEvent> sendQueued({
    String? threadId,
    String? profile,
    required String text,
    List<OutgoingAttachment> attachments = const [],
    ModelChoice? model,
    required Future<void> Function() beforeSubmit,
    Future<void> Function()? onNotSubmitted,
    bool Function()? queueDispatchAllowed,
  }) async* {
    await beforeSubmit();
    send(
      threadId: threadId,
      profile: profile,
      text: text,
      attachments: attachments,
      model: model,
      queued: true,
    );
    yield const PromptAccepted('streaming');
    await lateCall.future;
    try {
      await beforeSubmit();
      again.complete(null);
    } on Object catch (error) {
      again.complete(error);
    }
  }
}

QueueScope _scope() => QueueScope(
  serverKey: 'server',
  accountKey: 'account',
  profile: 'work',
  conversationId: 'stored',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late DurableQueueStore store;
  late FakeHermesServer server;
  late AttentionNotifier attention;
  late ValueNotifier<bool> activity;
  late List<String> reports;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    directory = await Directory.systemTemp.createTemp('send-guards-test-');
    store = DurableQueueStore(directory: directory, keys: FakeQueueKeys());
    activity = ValueNotifier(true);
    reports = [];
    attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    server = FakeHermesServer()
      ..on('GET', '/api/sessions', sessionListBody([sessionRow(id: 'stored')]))
      ..on(
        'GET',
        '/api/sessions/stored/messages',
        messageListBody('stored', []),
      );
  });

  tearDown(() async {
    activity.dispose();
    attention.dispose();
    await deleteQueueStoreDir(directory);
  });

  Future<ChatController> open(ChatTransport transport) async {
    final chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      activity: activity,
      transport: transport,
      attention: attention,
      report: reports.add,
      queueStore: () async => store,
      queueChanges: ValueNotifier(true),
      canShowQueues: () => true,
      queueScope: (thread, profile) => QueueScope(
        serverKey: 'server',
        accountKey: 'account',
        profile: profile,
        conversationId: thread.id,
      ),
    );
    addTearDown(chat.dispose);
    await chat.loadThreads('work');
    chat.select('stored');
    final thread = chat.selectedThread!;
    while (chat.queueBusy(thread)) {
      await pumpEventQueue();
    }
    await pumpEventQueue();
    return chat;
  }

  /// A spoken turn whose still-wanted check runs [atSend] on its second ask,
  /// the last one before the controller hands the prompt to `_send`. Nothing
  /// else runs between that ask and `_send`, so [atSend] is where the state
  /// the guards at the top of `_send` read can change under a send that
  /// already passed the caller's own checks.
  Future<VoiceTurnRefusal?> speakAndChange(
    ChatController chat,
    void Function() atSend,
  ) {
    var asks = 0;
    return chat.submitVoiceTurn(
      'spoken',
      wanted: () {
        if (++asks == 2) atSend();
        return true;
      },
      interrupted: false,
    );
  }

  /// A chat whose first turn is over, so a spoken turn is accepted.
  Future<(ChatController, _SyncReplyTransport)> afterFirstTurn() async {
    final transport = _SyncReplyTransport();
    final chat = await open(transport);
    expect(await chat.submit('typed', const []), isTrue);
    transport.replies.single.add(const ReplyCompleted('Done'));
    await pumpEventQueue();
    expect(transport.sends.map((send) => send.text), ['typed']);
    expect(chat.selectedThread!.isReplying, isFalse);
    return (chat, transport);
  }

  group('a send whose chat changed after the caller checked it', () {
    test('into a session reclaimed meanwhile writes nothing', () async {
      final (chat, transport) = await afterFirstTurn();
      final thread = chat.selectedThread!;
      final before = thread.messages.length;

      final refusal = await speakAndChange(
        chat,
        () => transport.replies.single.add(
          const SessionReclaimed('runtime', 'stored', 'idle'),
        ),
      );

      expect(refusal, VoiceTurnRefusal.noLongerWanted);
      expect(transport.sends.map((send) => send.text), ['typed']);
      expect(thread.messages, hasLength(before));
      expect(thread.isReplying, isFalse);
    });

    test(
      'while the controller went inactive meanwhile starts no turn',
      () async {
        final (chat, transport) = await afterFirstTurn();
        final thread = chat.selectedThread!;
        final before = [...thread.messages];

        final refusal = await speakAndChange(
          chat,
          () => activity.value = false,
        );

        expect(refusal, VoiceTurnRefusal.noLongerWanted);
        expect(transport.sends.map((send) => send.text), ['typed']);
        // Neither the spoken words nor a thinking reply were added.
        expect(thread.messages, before);
        expect(thread.isReplying, isFalse);
      },
    );
  });

  group('a queued prompt that never reached Hermes', () {
    Future<(ChatController, ChatThread, FakeQueueTransport)> reviewed() async {
      await store.commit(_scope(), 'unsent');
      final transport = FakeQueueTransport();
      final chat = await open(transport);
      final thread = chat.selectedThread!;
      expect(chat.queuedIn(thread).single.text, 'unsent');
      return (chat, thread, transport);
    }

    test('whose session could not be opened goes back to queued, not '
        'submitting, and is not sent again', () async {
      final (chat, thread, transport) = await reviewed();
      transport.openError = StateError('session cannot be opened');

      chat.sendQueued(thread);
      await pumpEventQueue();

      expect(transport.sends.map((send) => send.text), ['unsent']);
      final entry = chat.queuedIn(thread).single;
      expect(entry.submitting, isFalse);
      expect(entry.durable!.state, QueueRecordState.queued);
      expect(entry.uncertain, isFalse);
      expect(
        (await store.load(_scope())).records.single.state,
        QueueRecordState.queued,
      );
      // Nothing resends it by itself...
      await pumpEventQueue();
      expect(transport.sends, hasLength(1));
      // ...and the user can still take it out: a submitting entry cannot be.
      await chat.removeQueued(thread, entry);
      expect(chat.queuedIn(thread), isEmpty);
      expect((await store.load(_scope())).records, isEmpty);
    });
  });

  test('a queued prompt that Hermes already accepted cannot begin its '
      'submission again', () async {
    await store.commit(_scope(), 'once');
    final transport = _LateSubmitTransport();
    final chat = await open(transport);
    final thread = chat.selectedThread!;

    chat.sendQueued(thread);
    // The accepted prompt left the queue; the transport's stream is still open.
    while (chat.queuedIn(thread).isNotEmpty) {
      await pumpEventQueue();
    }
    transport.lateCall.complete();

    expect(await transport.again.future, isA<QueueSubmissionNotStarted>());
    expect(transport.sends.map((send) => send.text), ['once']);
    expect(chat.queuedIn(thread), isEmpty);
  });
}
