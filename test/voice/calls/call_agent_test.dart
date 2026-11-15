import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/voice/calls/call_agent.dart';

import '../../support/fake_chat_transport.dart';
import '../../support/fake_hermes_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeChatTransport transport;
  late ChatController chat;
  late ChatCallAgent agent;
  var contextLost = 0;
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
    chat.newThread();
    contextLost = 0;
    agent = ChatCallAgent(chat, onContextLost: () => contextLost++);
    addTearDown(() {
      agent.dispose();
      chat.dispose();
      attention.dispose();
    });
  });
  test(
    'speaks prose incrementally and keeps reasoning and MEDIA paths out',
    () async {
      final spoken = <String>[];
      final done = agent.reply(
        'Hello',
        onText: spoken.add,
        onAttention: (_) {},
        wanted: () => true,
      );
      await pumpEventQueue();
      final send = transport.sends.single;
      send
        ..emit(const ReasoningUpdated('Private deliberation.'))
        ..emit(const ReplyDelta('Hello.'));
      await pumpEventQueue();
      expect(spoken.join(), 'Hello.');
      send.emit(
        const ReplyDelta(' Welcome &amp; enjoy!\nMEDIA:/tmp/voice.ogg'),
      );
      await pumpEventQueue();
      send.emit(
        const ReplyCompleted(
          'Hello. Welcome &amp; enjoy!\nMEDIA:/tmp/voice.ogg',
        ),
      );
      await done;
      expect(spoken.join(), contains('Welcome & enjoy!'));
      expect(spoken.join(), isNot(contains('MEDIA:')));
      expect(spoken.join(), isNot(contains('Private')));
      expect(chat.selectedThread!.messages.first.content, 'Hello');
    },
  );
  test('a busy chat is not queued or interrupted by a new call', () async {
    chat.submit('Unrelated work', const []);
    await expectLater(
      agent.reply(
        'Voice',
        onText: (_) {},
        onAttention: (_) {},
        wanted: () => true,
      ),
      throwsA(
        isA<CallTurnRefused>().having(
          (e) => e.reason,
          'reason',
          VoiceTurnRefusal.busy,
        ),
      ),
    );
    await agent.interrupt();
    expect(transport.sends.length, 1);
    expect(chat.selectedThread!.isReplying, isTrue);
    expect(chat.queuedIn(chat.selectedThread!), isEmpty);
  });
  test('changing chat ends the captured context', () {
    chat.newThread();
    expect(contextLost, greaterThan(0));
    expect(agent.valid, isFalse);
  });
  test('interrupting an owned turn waits for its stopped event', () async {
    final reply = agent.reply(
      'Hello',
      onText: (_) {},
      onAttention: (_) {},
      wanted: () => true,
    );
    final failed = expectLater(reply, throwsStateError);
    await pumpEventQueue();
    final stopping = agent.interrupt();
    await pumpEventQueue();
    expect(transport.stops, isNotEmpty);
    transport.sends.single.emit(const ReplyCompleted('', stopped: true));
    await stopping;
    await failed;
    expect(chat.selectedThread!.isReplying, isFalse);
  });
  test(
    'approval pauses the call and is never answered automatically',
    () async {
      final waiting = <bool>[];
      final reply = agent.reply(
        'Check the server',
        onText: (_) {},
        onAttention: waiting.add,
        wanted: () => true,
      );
      final interrupted = expectLater(reply, throwsStateError);
      await pumpEventQueue();
      transport.sends.single.emit(
        const ApprovalRequested(
          ApprovalRequest(
            requestId: 'call-approval',
            command: 'restart service',
            description: 'Restart the service',
            choices: ['once', 'deny'],
          ),
        ),
      );
      await pumpEventQueue();
      expect(waiting.last, isTrue);
      expect(chat.selectedThread!.messages.last.awaitingInput, isTrue);
      transport.stopsRunning = false;
      await agent.interrupt();
      await interrupted;
    },
  );
  test(
    'reports an approval raised by a reply this call did not start',
    () async {
      final seen = <bool>[];
      agent.watchAttention(seen.add);
      expect(agent.attention, isFalse);
      // A typed message, not a voice turn.
      expect(await chat.submit('Check the server', const []), isTrue);
      await pumpEventQueue();
      transport.sends.single.emit(
        const ApprovalRequested(
          ApprovalRequest(
            requestId: 'typed-approval',
            command: 'restart service',
            description: 'Restart the service',
            choices: ['once', 'deny'],
          ),
        ),
      );
      await pumpEventQueue();
      expect(agent.attention, isTrue);
      expect(seen, [true]);
      transport.stopsRunning = false;
    },
  );
  test(
    'speaks the new reply when the history arrives above it mid-turn',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final server = FakeHermesServer();
      final gate = Completer<void>();
      server
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: 's1', title: 'Chat')]),
        )
        ..onRequest('GET', '/api/sessions/s1/messages', (_) async {
          await gate.future;
          return (
            status: 200,
            body: messageListBody('s1', [
              messageRow(id: 1, role: 'user', content: 'Hi'),
              messageRow(id: 2, role: 'assistant', content: 'Old answer.'),
            ]),
          );
        });
      final attention = AttentionNotifier(
        service: null,
        settings: null,
        onOpen: (_) {},
      );
      final remote = ChatController(
        repository: HermesChatRepository(HermesApiClient(server.dio()).raw),
        transport: transport,
        attention: attention,
        report: (_) {},
      );
      await remote.loadThreads();
      remote.select('s1');
      final caller = ChatCallAgent(remote, onContextLost: () {});
      addTearDown(() {
        caller.dispose();
        remote.dispose();
        attention.dispose();
      });

      final spoken = <String>[];
      final done = caller.reply(
        'Voice',
        onText: spoken.add,
        onAttention: (_) {},
        wanted: () => true,
      );
      await pumpEventQueue();
      final send = transport.sends.single;
      send.emit(const ReplyDelta('New answer.'));
      await pumpEventQueue();

      // The older turns land above the prompt while the reply streams.
      gate.complete();
      await pumpEventQueue();
      expect(
        [for (final m in remote.threads.single.messages) m.content],
        ['Hi', 'Old answer.', 'Voice', 'New answer.'],
      );
      send.emit(const ReplyCompleted('New answer.'));
      await done;

      expect(spoken.join(), 'New answer.');
    },
  );

  group('a voice turn', () {
    Future<CallTurnRefused> refusal(Future<void> reply) async {
      try {
        await reply;
      } on CallTurnRefused catch (e) {
        return e;
      }
      fail('expected a refusal');
    }

    test('goes out as a voice turn that is never queued', () async {
      final done = agent.reply(
        'Hello',
        onText: (_) {},
        onAttention: (_) {},
        wanted: () => true,
      );
      await pumpEventQueue();
      final send = transport.sends.single;
      expect(send.voiceTurn, isTrue);
      expect(send.queued, isFalse);
      expect(send.interrupted, isFalse);
      send.emit(const ReplyCompleted('Hi.'));
      await done;
    });

    test('asks to be marked interrupted only when told to', () async {
      // A settled thread: an earlier typed turn ended and Hermes went idle.
      await chat.submit('earlier', const []);
      transport.sends.single
        ..emit(const ReplyCompleted('Done'))
        ..emit(const SessionInfo(running: false))
        ..finish();
      await pumpEventQueue();
      final done = agent.reply(
        'Hello',
        onText: (_) {},
        onAttention: (_) {},
        wanted: () => true,
        interrupted: true,
      );
      await pumpEventQueue();
      expect(transport.sends.last.interrupted, isTrue);
      transport.sends.last.emit(const ReplyCompleted('Hi.'));
      await done;
    });

    test('refuses while a reply runs, sending nothing', () async {
      await chat.submit('Unrelated work', const []);
      final refused = await refusal(
        agent.reply(
          'Voice',
          onText: (_) {},
          onAttention: (_) {},
          wanted: () => true,
        ),
      );
      expect(refused.reason, VoiceTurnRefusal.busy);
      expect(transport.sends, hasLength(1));
    });

    test('refuses while a paused queue holds prompts', () async {
      await chat.submit('Unrelated work', const []);
      await chat.submit('Queued behind it', const []);
      transport.sends.single
        ..emit(const ReplyCompleted('', stopped: true))
        ..finish();
      await pumpEventQueue();
      final thread = chat.selectedThread!;
      expect(chat.queuedIn(thread), isNotEmpty);
      final refused = await refusal(
        agent.reply(
          'Voice',
          onText: (_) {},
          onAttention: (_) {},
          wanted: () => true,
        ),
      );
      expect(refused.reason, VoiceTurnRefusal.queuePaused);
      expect(refused.kind, 'queue_paused');
      expect(transport.sends, hasLength(1));
      expect(chat.queuedIn(thread), hasLength(1));
    });

    test('End before prompt.submit is written sends nothing', () async {
      var wanted = true;
      var submitting = 0;
      final done = agent.reply(
        'Hello',
        onText: (_) {},
        onAttention: (_) {},
        wanted: () => wanted,
        onSubmitted: () => submitting++,
      );
      final refused = refusal(done);
      await pumpEventQueue();
      wanted = false;
      expect(transport.sends.single.submit(), isFalse);
      expect((await refused).reason, VoiceTurnRefusal.noLongerWanted);
      expect(submitting, 0);
      expect(chat.selectedThread!.messages, isEmpty);
    });

    test('interrupt before prompt.submit is written sends nothing', () async {
      var submitting = 0;
      final done = agent.reply(
        'Hello',
        onText: (_) {},
        onAttention: (_) {},
        // The call still wants the turn: only the interrupt says no.
        wanted: () => true,
        onSubmitted: () => submitting++,
      );
      final failed = expectLater(done, throwsA(isA<Object>()));
      await pumpEventQueue();
      // It waits for the withdrawn turn to end.
      final interrupting = agent.interrupt();
      await pumpEventQueue();
      expect(transport.sends.single.submit(), isFalse);
      await interrupting;
      await failed;
      expect(submitting, 0);
      expect(chat.selectedThread!.messages, isEmpty);
    });

    test('runs onSubmitted where the transport writes the prompt', () async {
      var submitting = 0;
      final done = agent.reply(
        'Hello',
        onText: (_) {},
        onAttention: (_) {},
        wanted: () => true,
        onSubmitted: () => submitting++,
      );
      await pumpEventQueue();
      expect(submitting, 0, reason: 'handed over is not written');
      expect(transport.sends.single.submit(), isTrue);
      expect(submitting, 1);
      transport.sends.single.emit(const ReplyCompleted('Hi.'));
      await done;
    });

    for (final (status, answer) in [
      ('queued', CallTurnAnswer.queued),
      ('steered', CallTurnAnswer.steered),
      ('redirected', CallTurnAnswer.redirected),
    ]) {
      test('$status ends the wait at once', () async {
        final answers = <CallTurnAnswer>[];
        final done = agent.reply(
          'Hello',
          onText: (_) {},
          onAttention: (_) {},
          wanted: () => true,
          onAnswer: answers.add,
        );
        await pumpEventQueue();
        transport.sends.single.emit(PromptAccepted(status));
        await done.timeout(const Duration(seconds: 1));
        expect(answers, [answer]);
      });
    }

    test('voice_stopped ends the wait and leaves no placeholder', () async {
      final answers = <CallTurnAnswer>[];
      final done = agent.reply(
        'stop',
        onText: (_) {},
        onAttention: (_) {},
        wanted: () => true,
        onAnswer: answers.add,
      );
      await pumpEventQueue();
      transport.sends.single
        ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
        ..finish();
      await done.timeout(const Duration(seconds: 1));
      expect(answers, [CallTurnAnswer.voiceStopped]);
      expect(chat.selectedThread!.messages, isEmpty);
    });

    test('reports a message typed in the chat, not its own', () async {
      var typed = 0;
      agent.watchTyped(() => typed++);
      final done = agent.reply(
        'Hello',
        onText: (_) {},
        onAttention: (_) {},
        wanted: () => true,
      );
      await pumpEventQueue();
      expect(typed, 0, reason: 'the call\'s own prompt is not typed');
      transport.sends.single.emit(const ReplyCompleted('Hi.'));
      await done;
      await chat.submit('typed in the chat', const []);
      await pumpEventQueue();
      expect(typed, 1);
    });
  });

  group('a turn that was not sent leaves the chat as it was', () {
    /// Sends a spoken turn and withdraws it before it is written.
    Future<void> withdraw({bool interrupted = false}) async {
      var wanted = true;
      final refused = agent
          .reply(
            'Secret words',
            onText: (_) {},
            onAttention: (_) {},
            wanted: () => wanted,
            interrupted: interrupted,
          )
          .then<void>((_) {}, onError: (Object _) {});
      await pumpEventQueue();
      wanted = false;
      transport.sends.last.submit();
      await refused;
      await pumpEventQueue();
    }

    test('the words do not become the chat title', () async {
      await withdraw();
      expect(chat.selectedThread!.title, 'New chat');
      expect(chat.selectedThread!.messages, isEmpty);
    });

    test('a typed stop phrase leaves no title either', () async {
      await chat.submit('Secret stop words', const []);
      transport.sends.single
        ..emit(const PromptAccepted(PromptAccepted.voiceStopped))
        ..finish();
      await pumpEventQueue();
      expect(chat.selectedThread!.title, 'New chat');
    });

    test('is not mistaken for a typed message', () async {
      var typed = 0;
      agent.watchTyped(() => typed++);
      await withdraw();
      expect(typed, 0);
    });

    test('keeps a pending interrupted for the next turn', () async {
      await chat.submit('earlier', const []);
      transport.sends.single
        ..emit(const ReplyCompleted('Done'))
        ..emit(const SessionInfo(running: false))
        ..finish();
      await pumpEventQueue();
      await withdraw(interrupted: true);
      final done = agent.reply(
        'Again',
        onText: (_) {},
        onAttention: (_) {},
        wanted: () => true,
        interrupted: true,
      );
      await pumpEventQueue();
      expect(transport.sends.last.text, 'Again');
      expect(transport.sends.last.interrupted, isTrue);
      transport.sends.last.emit(const ReplyCompleted('Hi.'));
      await done;
    });

    test(
      'a chat bound by the withdrawn send creates its session again',
      () async {
        var wanted = true;
        final first = agent
            .reply(
              'Hello',
              onText: (_) {},
              onAttention: (_) {},
              wanted: () => wanted,
            )
            .then<void>((_) {}, onError: (Object _) {});
        await pumpEventQueue();
        transport.sends.single.emit(const ThreadBound('never-stored'));
        await pumpEventQueue();
        wanted = false;
        transport.sends.single.submit();
        await first;
        await pumpEventQueue();
        final done = agent.reply(
          'Again',
          onText: (_) {},
          onAttention: (_) {},
          wanted: () => true,
        );
        await pumpEventQueue();
        expect(transport.sends.last.text, 'Again');
        expect(transport.sends.last.threadId, isNull);
        transport.sends.last.emit(const ReplyCompleted('Hi.'));
        await done;
      },
    );
  });
}
