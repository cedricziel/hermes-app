import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart'
    show ChatMessage, ChatRole, ChatThread, MessageStatus;
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/queue_storage/durable_queue_store.dart';
import 'package:hermes_app/src/chat/queue_storage/queue_record.dart';
import 'package:hermes_app/src/chat/thread_sections.dart';
import 'package:hermes_app/src/models/hermes_models_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_queue_keys.dart';

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
  late FakeQueueKeys keys;
  late FakeChatTransport transport;
  late FakeHermesServer server;
  late AttentionNotifier attention;
  late List<String> reports;
  late List<ChatSendNotice> notices;
  late List<String> drafts;
  late ValueNotifier<bool> activity;
  Completer<DurableQueueStore>? storeGate;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    directory = await Directory.systemTemp.createTemp('voice-turn-test-');
    keys = FakeQueueKeys();
    store = DurableQueueStore(directory: directory, keys: keys);
    transport = FakeChatTransport();
    reports = [];
    notices = [];
    drafts = [];
    activity = ValueNotifier(true);
    storeGate = null;
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
    attention.dispose();
    await directory.delete(recursive: true);
  });

  /// A chat on the stored thread. With [gated] the protected queue store
  /// stays closed until [storeGate] completes, so the restore is still
  /// running when the turn arrives.
  Future<ChatController> open({
    String? profile = 'work',
    bool gated = false,
    bool models = false,
  }) async {
    if (gated) storeGate = Completer<DurableQueueStore>();
    final chat = ChatController(
      repository: HermesChatRepository(server.client().raw),
      models: models ? HermesModelsRepository(server.client().raw) : null,
      activity: activity,
      transport: transport,
      attention: attention,
      report: reports.add,
      onSendNotice: notices.add,
      onDraft: drafts.add,
      queueStore: () => gated ? storeGate!.future : Future.value(store),
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
    await chat.loadThreads(profile);
    chat.select('stored');
    if (!gated) {
      while (chat.queueBusy(chat.selectedThread!)) {
        await pumpEventQueue();
      }
    }
    await pumpEventQueue();
    return chat;
  }

  Future<VoiceTurnRefusal?> speak(
    ChatController chat, {
    bool Function()? wanted,
    bool interrupted = false,
    void Function()? onSubmitting,
    void Function(VoiceTurnAnswer)? onAnswer,
  }) => chat.submitVoiceTurn(
    'hello',
    wanted: wanted ?? () => true,
    interrupted: interrupted,
    onSubmitting: onSubmitting,
    onAnswer: onAnswer,
  );

  group('refusals leave nothing sent and nothing queued', () {
    test('a reply that is running refuses as busy', () async {
      final chat = await open();
      await chat.submit('typed', const []);
      expect(await speak(chat), VoiceTurnRefusal.busy);
      expect(transport.sends, hasLength(1));
      expect(chat.queuedIn(chat.selectedThread!), isEmpty);
    });

    test(
      'a turn no longer wanted is refused before anything is sent',
      () async {
        final chat = await open();
        expect(
          await speak(chat, wanted: () => false),
          VoiceTurnRefusal.noLongerWanted,
        );
        expect(transport.sends, isEmpty);
        expect(chat.selectedThread!.messages, isEmpty);
      },
    );

    test(
      'a restored queue with prompts refuses as paused and sends none',
      () async {
        await store.commit(_scope(), 'restored prompt');
        final chat = await open();
        expect(await speak(chat), VoiceTurnRefusal.queuePaused);
        expect(transport.sends, isEmpty);
        expect(chat.queuedIn(chat.selectedThread!).map((p) => p.text), [
          'restored prompt',
        ]);
      },
    );

    test(
      'a queue behind a running reply refuses as busy, not paused',
      () async {
        final chat = await open();
        await chat.submit('typed', const []);
        await chat.submit('queued behind it', const []);
        expect(chat.queuePaused(chat.selectedThread!), isFalse);
        expect(await speak(chat), VoiceTurnRefusal.busy);
      },
    );

    test('a paused queue is not joined and no queued prompt is sent', () async {
      final chat = await open();
      await chat.submit('typed', const []);
      await chat.submit('queued behind it', const []);
      final thread = chat.selectedThread!;
      transport.sends.single
        ..emit(const ReplyCompleted('', stopped: true))
        ..finish();
      await pumpEventQueue();
      expect(chat.queuePaused(thread), isTrue);
      expect(await speak(chat), VoiceTurnRefusal.queuePaused);
      expect(transport.sends, hasLength(1));
      expect(chat.queuedIn(thread).map((p) => p.text), ['queued behind it']);
    });

    test('a failed restore refuses and sends nothing', () async {
      final chat = await open(gated: true);
      final answer = speak(chat);
      await pumpEventQueue();
      storeGate!.completeError(StateError('keys unavailable'));
      expect(await answer, VoiceTurnRefusal.queueRestoreFailed);
      expect(transport.sends, isEmpty);
      expect(chat.queuedIn(chat.selectedThread!), isEmpty);
    });

    test('a model that is not usable refuses', () async {
      server.on('GET', '/api/model/options', {'providers': []});
      final chat = await open(models: true);
      await pumpEventQueue();
      expect(chat.modelSendAllowed, isFalse);
      expect(await speak(chat), VoiceTurnRefusal.modelOrBranchNotAllowed);
      expect(transport.sends, isEmpty);
    });

    test('an unconfirmed profile refuses while the chat is busy', () async {
      final chat = await open(profile: null);
      await chat.submit('typed', const []);
      expect(await speak(chat), VoiceTurnRefusal.profileNotConfirmed);
      expect(transport.sends, hasLength(1));
    });

    test('a reclaimed session refuses', () async {
      final chat = await open();
      await chat.submit('typed', const []);
      transport.sends.single
        ..emit(const SessionReclaimed('rt', 'stored', 'x'))
        ..emit(const ReplyCompleted('Done'))
        ..finish();
      await pumpEventQueue();
      expect(await speak(chat), VoiceTurnRefusal.sessionReclaimed);
      expect(transport.sends, hasLength(1));
    });
  });

  group('the queue restore', () {
    test(
      'a turn that arrives before the restore waits for it, then sends',
      () async {
        final chat = await open(gated: true);
        final thread = chat.selectedThread!;
        expect(chat.queuedIn(thread), isEmpty);
        VoiceTurnRefusal? refused = VoiceTurnRefusal.busy;
        var done = false;
        unawaited(
          speak(chat).then((r) {
            refused = r;
            done = true;
          }),
        );
        await pumpEventQueue();
        expect(done, isFalse);
        expect(transport.sends, isEmpty);
        storeGate!.complete(store);
        for (var i = 0; i < 50 && !done; i++) {
          await pumpEventQueue();
        }
        expect(done, isTrue);
        expect(refused, isNull);
        final send = transport.sends.single;
        expect(send.voiceTurn, isTrue);
        expect(send.queued, isFalse);
      },
    );

    test(
      'End during a restore that then fails is not a restore failure',
      () async {
        final chat = await open(gated: true);
        var wanted = true;
        final answer = speak(chat, wanted: () => wanted);
        await pumpEventQueue();
        wanted = false;
        storeGate!.completeError(StateError('keys unavailable'));
        expect(await answer, VoiceTurnRefusal.noLongerWanted);
      },
    );

    test(
      'a restore that finds queued prompts refuses and sends none',
      () async {
        await store.commit(_scope(), 'restored prompt');
        final chat = await open(gated: true);
        final answer = speak(chat);
        await pumpEventQueue();
        storeGate!.complete(store);
        expect(await answer, VoiceTurnRefusal.queuePaused);
        expect(transport.sends, isEmpty);
        expect(chat.queuedIn(chat.selectedThread!), hasLength(1));
      },
    );

    test('End or mute during the restore sends and queues nothing', () async {
      final chat = await open(gated: true);
      var wanted = true;
      final answer = speak(chat, wanted: () => wanted);
      await pumpEventQueue();
      wanted = false;
      storeGate!.complete(store);
      expect(await answer, VoiceTurnRefusal.noLongerWanted);
      expect(transport.sends, isEmpty);
      expect(chat.queuedIn(chat.selectedThread!), isEmpty);
      expect(chat.selectedThread!.messages, isEmpty);
    });
  });

  group('the send', () {
    test('is a voice turn that is never queued', () async {
      final chat = await open();
      expect(await speak(chat), isNull);
      final send = transport.sends.single;
      expect(send.voiceTurn, isTrue);
      expect(send.queued, isFalse);
      expect(send.interrupted, isFalse);
      expect(chat.selectedThread!.isReplying, isTrue);
    });

    test('carries the still-wanted check as authorize', () async {
      final chat = await open();
      var wanted = true;
      var submitting = 0;
      await speak(chat, wanted: () => wanted, onSubmitting: () => submitting++);
      final send = transport.sends.single;
      wanted = false;
      // End while the session was still opening: nothing is written.
      expect(send.submit(), isFalse);
      expect(submitting, 0);
      await pumpEventQueue();
      expect(chat.selectedThread!.messages, isEmpty);
      expect(chat.selectedThread!.isReplying, isFalse);
    });

    test(
      'a wanted send runs onSubmitting where the transport writes',
      () async {
        final chat = await open();
        var submitting = 0;
        await speak(chat, onSubmitting: () => submitting++);
        expect(transport.sends.single.submit(), isTrue);
        expect(submitting, 1);
      },
    );

    test(
      'a withdrawn send is reported and leaves the chat as it was',
      () async {
        final chat = await open();
        final answers = <VoiceTurnAnswer>[];
        var wanted = true;
        await speak(chat, wanted: () => wanted, onAnswer: answers.add);
        wanted = false;
        transport.sends.single.submit();
        await pumpEventQueue();
        expect(answers, [VoiceTurnAnswer.withdrawn]);
        expect(chat.lastSentPrompt(chat.selectedThread!), isNull);
        expect(await chat.submit('typed later', const []), isTrue);
        expect(transport.sends, hasLength(2));
      },
    );
  });

  group('what Hermes answers', () {
    for (final (status, answer) in [
      ('streaming', VoiceTurnAnswer.started),
      ('queued', VoiceTurnAnswer.queued),
      ('steered', VoiceTurnAnswer.steered),
      ('redirected', VoiceTurnAnswer.redirected),
    ]) {
      test('$status is reported once', () async {
        final chat = await open();
        final answers = <VoiceTurnAnswer>[];
        await speak(chat, onAnswer: answers.add);
        transport.sends.single.emit(PromptAccepted(status));
        await pumpEventQueue();
        expect(answers, [answer]);
        expect(chat.selectedThread!.messages.first.content, 'hello');
      });
    }

    test('a typed prompt gets no voice answer', () async {
      final chat = await open();
      final answers = <VoiceTurnAnswer>[];
      await speak(chat, onAnswer: answers.add);
      await pumpEventQueue();
      expect(answers, isEmpty);
    });

    test('voice_stopped leaves no prompt and no placeholder', () async {
      final chat = await open();
      final answers = <VoiceTurnAnswer>[];
      await speak(chat, onAnswer: answers.add);
      transport.sends.single
        ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
        ..finish();
      await pumpEventQueue();
      expect(answers, [VoiceTurnAnswer.voiceStopped]);
      final thread = chat.selectedThread!;
      expect(thread.messages, isEmpty);
      expect(thread.isReplying, isFalse);
      expect(reports, isEmpty);
    });

    test('a typed stop phrase says so and hands the words back', () async {
      final chat = await open();
      await chat.submit('stop', const []);
      transport.sends.single
        ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
        ..finish();
      await pumpEventQueue();
      expect(notices, [ChatSendNotice.stopCommand]);
      expect(drafts, ['stop']);
      expect(chat.selectedThread!.messages, isEmpty);
    });

    test('a typed stop phrase of another chat is not handed back', () async {
      final chat = await open();
      await chat.submit('stop', const []);
      chat.newThread();
      transport.sends.single
        ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
        ..finish();
      await pumpEventQueue();
      expect(notices, [ChatSendNotice.stopCommandElsewhere]);
      expect(drafts, isEmpty);
    });

    test('a spoken stop phrase tells the call, not the chat', () async {
      final chat = await open();
      await speak(chat);
      transport.sends.single
        ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
        ..finish();
      await pumpEventQueue();
      expect(notices, isEmpty);
      expect(drafts, isEmpty);
    });

    test('voice_stopped for a typed prompt leaves no placeholder', () async {
      final chat = await open();
      await chat.submit('stop', const []);
      transport.sends.single
        ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
        ..finish();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      expect(thread.messages, isEmpty);
      expect(thread.isReplying, isFalse);
    });
  });

  group('interrupted', () {
    Future<ChatController> settled() async {
      final chat = await open();
      await chat.submit('earlier', const []);
      transport.sends.single
        ..emit(const ReplyCompleted('Done'))
        ..emit(const SessionInfo(running: false))
        ..finish();
      await pumpEventQueue();
      return chat;
    }

    test('goes out when the thread is settled', () async {
      final chat = await settled();
      expect(await speak(chat, interrupted: true), isNull);
      expect(transport.sends.last.interrupted, isTrue);
    });

    test('is left out while the session was not reported idle', () async {
      final chat = await open();
      await chat.submit('earlier', const []);
      transport.sends.single
        ..emit(const ReplyCompleted('Done'))
        ..finish();
      await pumpEventQueue();
      expect(chat.selectedThread!.isReplying, isFalse);
      expect(await speak(chat, interrupted: true), isNull);
      expect(transport.sends.last.voiceTurn, isTrue);
      expect(transport.sends.last.interrupted, isFalse);
    });

    test('is left out on a thread that never ran', () async {
      final chat = await open();
      expect(await speak(chat, interrupted: true), isNull);
      expect(transport.sends.single.interrupted, isFalse);
    });

    test('is not sent when not asked for', () async {
      final chat = await settled();
      expect(await speak(chat), isNull);
      expect(transport.sends.last.interrupted, isFalse);
    });
  });

  group('after a turn that was not sent', () {
    test('the chat listens for the session again', () async {
      final chat = await open();
      var wanted = true;
      await speak(chat, wanted: () => wanted);
      // Opening the session closes the watch the follow-ups listened on.
      transport.followUpStreams['stored']!.finish();
      await pumpEventQueue();
      final before = transport.followUpCalls;
      wanted = false;
      transport.sends.single.submit();
      await pumpEventQueue();
      expect(transport.followUpCalls, greaterThan(before));
    });

    test('a typed stop phrase leaves the chat listening again', () async {
      final chat = await open();
      await chat.submit('stop', const []);
      transport.followUpStreams['stored']!.finish();
      await pumpEventQueue();
      final before = transport.followUpCalls;
      transport.sends.single
        ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
        ..finish();
      await pumpEventQueue();
      expect(transport.followUpCalls, greaterThan(before));
    });
  });

  group(
    'a turn withdrawn before it was written leaves the thread as it was',
    () {
      test('its last activity and its place in the sidebar', () async {
        final chat = await open();
        final thread = chat.selectedThread!;
        final updated = thread.updatedAt;
        final now = DateTime.now();
        List<ThreadSectionKind> sections() => [
          for (final s in groupThreads(chat.threads, now: now)) s.kind,
        ];
        final before = sections();
        var wanted = true;
        await speak(chat, wanted: () => wanted);
        wanted = false;
        transport.sends.single.submit();
        await pumpEventQueue();
        expect(thread.messages, isEmpty);
        expect(thread.updatedAt, updated);
        expect(sections(), before);
      });

      test('the same when Hermes takes the words as a stop phrase', () async {
        final chat = await open();
        final thread = chat.selectedThread!;
        final updated = thread.updatedAt;
        await speak(chat);
        transport.sends.single
          ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
          ..finish();
        await pumpEventQueue();
        expect(thread.updatedAt, updated);
      });

      test('a newer last activity set meanwhile is kept', () async {
        final chat = await open();
        final thread = chat.selectedThread!;
        var wanted = true;
        await speak(chat, wanted: () => wanted);
        final newer = DateTime.now().add(const Duration(days: 1));
        thread.updatedAt = newer;
        wanted = false;
        transport.sends.single.submit();
        await pumpEventQueue();
        expect(thread.updatedAt, newer);
      });

      test('the earlier reply still settled without a completion', () async {
        final chat = await open();
        final thread = chat.selectedThread!;
        await chat.submit('earlier', const []);
        transport.sends.single
          ..emit(const SessionInfo(running: false))
          ..finish();
        await pumpEventQueue();
        final earlier = thread.messages.last;
        expect(earlier.settledWithoutCompletion, isTrue);
        var wanted = true;
        await speak(chat, wanted: () => wanted);
        // The new turn took over the late completion.
        expect(earlier.settledWithoutCompletion, isFalse);
        wanted = false;
        transport.sends.last.submit();
        await pumpEventQueue();
        expect(thread.messages.last, same(earlier));
        expect(earlier.settledWithoutCompletion, isTrue);
      });

      test('a stop asked during a withdrawn turn is not current for the next '
          'turn', () async {
        final chat = await open();
        final thread = chat.selectedThread!;
        final stop = Completer<bool>();
        transport.onStop = (_) => stop.future;
        await chat.submit('stop', const []);
        final stopping = chat.stopReply(thread);
        await pumpEventQueue();
        transport.sends.single
          ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
          ..finish();
        await pumpEventQueue();
        await chat.submit('next', const []);
        await pumpEventQueue();
        stop.completeError(StateError('lost'));
        await stopping;
        expect(reports, isEmpty);
      });

      test('an answer to an earlier stop is still current', () async {
        final chat = await open();
        final thread = chat.selectedThread!;
        final stop = Completer<bool>();
        transport.onStop = (_) => stop.future;
        await chat.submit('typed', const []);
        final stopping = chat.stopReply(thread);
        await pumpEventQueue();
        transport.sends.single
          ..emit(const ReplyCompleted('', stopped: true))
          ..finish();
        await pumpEventQueue();
        var wanted = true;
        await speak(chat, wanted: () => wanted);
        wanted = false;
        transport.sends.last.submit();
        await pumpEventQueue();
        // The stop fails after the withdrawn turn: it is still about the reply
        // before it, so the user is told.
        stop.completeError(StateError('lost'));
        await stopping;
        expect(reports, contains('Could not stop the reply. Try again.'));
      });
    },
  );

  group('a stop phrase typed in a chat that is not open', () {
    /// Two stored chats, a prompt `stop` sent in the first and the second
    /// opened, then Hermes taking the words as a stop command.
    Future<ChatController> stopElsewhere() async {
      server
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 'stored'), sessionRow(id: 'other')]),
        )
        ..on(
          'GET',
          '/api/sessions/other/messages',
          messageListBody('other', []),
        )
        ..on('GET', '/api/sessions/stored', sessionRow(id: 'stored'))
        ..on('DELETE', '/api/sessions/stored', {'ok': true});
      final chat = await open();
      await chat.submit('stop', const []);
      chat.select('other');
      await pumpEventQueue();
      transport.sends.single
        ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
        ..finish();
      await pumpEventQueue();
      expect(notices, [ChatSendNotice.stopCommandElsewhere]);
      expect(drafts, isEmpty);
      return chat;
    }

    test('keeps the words through a refresh of the chat list', () async {
      final chat = await stopElsewhere();
      final before = chat.threads.firstWhere((t) => t.id == 'stored');
      await chat.loadThreads('work');
      // The refresh replaced the thread the words were typed in.
      expect(
        chat.threads.firstWhere((t) => t.id == 'stored'),
        isNot(same(before)),
      );
      chat.select('stored');
      await pumpEventQueue();
      expect(drafts, ['stop']);
    });

    test('forgets the words when the profile is switched', () async {
      final chat = await stopElsewhere();
      await chat.loadThreads('home');
      await chat.loadThreads('work');
      chat.select('stored');
      await pumpEventQueue();
      expect(drafts, isEmpty);
    });

    test('forgets the words when the chat is deleted', () async {
      final chat = await stopElsewhere();
      await chat.housekeeping!.delete(
        chat.threads.firstWhere((t) => t.id == 'stored'),
      );
      await chat.loadThreads('work');
      chat.select('stored');
      await pumpEventQueue();
      expect(drafts, isEmpty);
    });

    test('forgets the words when the app is suspended', () async {
      final chat = await stopElsewhere();
      activity.value = false;
      activity.value = true;
      await pumpEventQueue();
      while (chat.loadingThreads) {
        await pumpEventQueue();
      }
      chat.select('stored');
      await pumpEventQueue();
      expect(drafts, isEmpty);
    });

    test('hands the words over when a notification opens the chat', () async {
      final chat = await stopElsewhere();
      expect(
        await chat.restoreHandoff(
          const NotificationTarget(threadId: 'stored', profile: 'work'),
          () => true,
        ),
        isTrue,
      );
      expect(chat.selectedThread!.id, 'stored');
      expect(drafts, ['stop']);
    });

    test(
      'hands the words over when a notification opens a replying chat',
      () async {
        final chat = await stopElsewhere();
        chat.threads
            .firstWhere((t) => t.id == 'stored')
            .messages
            .add(
              ChatMessage(
                id: 'live',
                role: ChatRole.assistant,
                content: 'Still replying',
                createdAt: DateTime.now(),
                status: MessageStatus.streaming,
              ),
            );
        expect(
          await chat.restoreHandoff(
            const NotificationTarget(threadId: 'stored', profile: 'work'),
            () => true,
          ),
          isTrue,
        );
        expect(chat.selectedThread!.id, 'stored');
        expect(drafts, ['stop']);
      },
    );

    test('hands the words over when open() selects the chat', () async {
      final chat = await stopElsewhere();
      chat.open(
        const NotificationTarget(threadId: 'stored', profile: 'work'),
        fetchMissing: true,
      );
      await pumpEventQueue();
      expect(drafts, ['stop']);
    });
  });

  test('a stop phrase is reported with the thread it was sent in', () async {
    final chat = await open();
    final sent = chat.selectedThread!;
    final heard = <ChatThread>[];
    chat.addVoiceStoppedListener(heard.add);
    await chat.submit('stop', const []);
    // The user moved to another chat meanwhile.
    chat.newThread();
    transport.sends.single
      ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
      ..finish();
    await pumpEventQueue();
    expect(heard, hasLength(1));
    expect(heard.single, same(sent));
    expect(chat.selectedThread, isNot(same(sent)));
  });
}
