import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/background/headless_hermes.dart';
import 'package:hermes_app/src/background/running_replies.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/intents/ask_hermes.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/local_notification_service.dart'
    show targetFromPayload, notificationPayload;
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/auth/auth_controller.dart'
    show kSavedServerUrlKey;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_notification_service.dart';
import '../support/memory_token_store.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';

const _url = 'http://hermes.test';

const _approval = ApprovalRequested(
  ApprovalRequest(
    requestId: 'r1',
    command: 'rm -rf build',
    description: 'delete files',
    choices: ['once', 'deny'],
  ),
);

Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(done(), isTrue, reason: 'timed out waiting');
}

void main() {
  late FakeHermesServer server;
  late MemoryTokenStore store;
  late FakeChatTransport transport;
  late FakeNotificationService notifications;
  late RecordedEvents events;
  late RecordingTracer tracer;
  late BreadcrumbTrail trail;
  late RunningReplies running;
  var appLockOn = false;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({kSavedServerUrlKey: _url});
    server = FakeHermesServer()
      ..on('GET', '/api/status', {'auth_required': true});
    store = MemoryTokenStore(
      const HermesSession(
        accessToken: 'access',
        refreshToken: 'refresh',
        expiresAt: 4102444800,
        provider: 'basic',
        userId: 'u1',
        serverUrl: _url,
        mintedAt: 1000,
      ),
    );
    transport = FakeChatTransport();
    notifications = FakeNotificationService();
    events = RecordedEvents();
    tracer = RecordingTracer();
    trail = BreadcrumbTrail();
    running = RunningReplies();
    appLockOn = false;
  });

  AskHermes hermes({AskEngine engine = AskEngine.headless}) => AskHermes(
    engine: engine,
    notifications: notifications,
    events: events.call,
    breadcrumbs: Breadcrumbs.of(trail),
    appLockOn: () async => appLockOn,
    running: running,
    tracer: tracer,
    transportFor: (_) => transport,
    deps: HeadlessDeps(
      tokenStore: store,
      prefs: SharedPreferencesAsync(),
      devServerUrl: '',
      adapter: server,
      telemetry: (attributes) => ConnectionTelemetry(tracer: tracer),
    ),
  );

  AskRun ask(
    String question, {
    String? profile,
    String? chatId,
    Duration within = const Duration(seconds: 5),
    AskEngine engine = AskEngine.headless,
  }) => hermes(engine: engine).start(
    AskRequest(
      question: question,
      profile: profile,
      chatId: chatId,
      answerWithin: within,
    ),
  );

  Future<FakeSend> sent() async {
    await _until(() => transport.sends.isNotEmpty);
    return transport.sends.single;
  }

  group('what is sent', () {
    test('starts a new chat in the given profile', () async {
      final run = ask('How many tickets?', profile: 'work');
      final send = await sent();
      send
        ..emit(const ThreadBound('new-1'))
        ..emit(const ReplyCompleted('Three.'));

      final result = await run.answer;

      expect(send.threadId, isNull);
      expect(send.profile, 'work');
      expect(send.text, 'How many tickets?');
      expect(result.outcome, AskOutcome.answered);
      expect(result.text, 'Three.');
      await run.finished;
      expect(transport.closed, isTrue);
    });

    test('continues a chat in its own profile, not the given one', () async {
      final run = ask('And now?', profile: 'default', chatId: 'work/abc');
      final send = await sent();
      send.emit(const ReplyCompleted('Fine.'));

      await run.answer;

      expect(send.threadId, 'abc');
      expect(send.profile, 'work');
    });

    test('sends nothing for a blank question', () async {
      final run = ask('   ');

      expect((await run.answer).outcome, AskOutcome.failed);
      await run.finished;
      expect(transport.sends, isEmpty);
      expect(server.requests, isEmpty);
    });
  });

  group('answering in place', () {
    test('returns the reply text, cut at 4000 characters', () async {
      final run = ask('Tell me a lot');
      final send = await sent();
      send.emit(ReplyCompleted('x' * 5000));

      final result = await run.answer;

      expect(result.outcome, AskOutcome.answered);
      expect(result.text, '${'x' * 4000}…');
    });

    test('says so when the reply has no text', () async {
      final run = ask('Hello');
      (await sent()).emit(const ReplyCompleted(''));

      final result = await run.answer;

      expect(result.outcome, AskOutcome.answered);
      expect(result.text, 'Hermes replied without any text.');
    });

    test('keeps the error text out of a failed reply', () async {
      final run = ask('Hello');
      (await sent()).emit(
        const ReplyCompleted('Traceback: secret', failed: true),
      );

      final result = await run.answer;

      expect(result.outcome, AskOutcome.failed);
      expect(result.text, isNull);
    });

    test('does not post "Reply ready" for a reply given in place', () async {
      final run = ask('Hello');
      (await sent()).emit(const ReplyCompleted('Hi'));

      await run.answer;
      await run.finished;
      await pumpEventQueue();

      expect(notifications.shown, isEmpty);
    });
  });

  group('requests during the turn', () {
    final requests = <String, ChatEvent>{
      'an approval': _approval,
      'a question': const ClarifyRequested(
        ClarifyRequest(
          requestId: 'r2',
          batch: true,
          questions: [ClarifyQuestion(qid: 'q1', question: 'Which branch?')],
        ),
      ),
      'a secret': const VaultRequested(
        VaultRequest(requestId: 'r3', kind: VaultKind.saveLogin),
      ),
      'a sudo password': const UnsupportedRequested(
        UnsupportedRequest(requestId: 'r4', kind: UnsupportedKind.sudo),
      ),
    };

    for (final MapEntry(:key, :value) in requests.entries) {
      test('$key is handed to the app and posted as a notification', () async {
        final run = ask('Clean up');
        final send = await sent();
        send
          ..emit(const ThreadBound('new-1'))
          ..emit(value);

        final result = await run.answer;
        await run.finished;
        await pumpEventQueue();

        expect(result.outcome, AskOutcome.needsYou);
        expect(result.text, isNull);
        expect(notifications.shown, hasLength(1));
        expect(notifications.shown.single.timeSensitive, isTrue);
      });
    }
  });

  group('when Hermes cannot answer', () {
    test('signed out: nothing is sent', () async {
      store.session = null;

      final run = ask('Hello');

      expect((await run.answer).outcome, AskOutcome.signedOut);
      await run.finished;
      expect(transport.sends, isEmpty);
    });

    test('before the first unlock: nothing is sent', () async {
      store.unreadable = true;

      final run = ask('Hello');

      expect((await run.answer).outcome, AskOutcome.deviceLocked);
      await run.finished;
      expect(transport.sends, isEmpty);
    });

    test('server unreachable: nothing is sent', () async {
      server.on('GET', '/api/status', {}, status: 503);

      final run = ask('Hello');

      expect((await run.answer).outcome, AskOutcome.unreachable);
      await run.finished;
      expect(transport.sends, isEmpty);
    });

    test('App lock on: answers at once and touches nothing', () async {
      appLockOn = true;

      final run = ask('Hello');

      expect((await run.answer).outcome, AskOutcome.appLocked);
      await run.finished;
      expect(transport.sends, isEmpty);
      expect(server.requests, isEmpty);
      expect(notifications.shown, isEmpty);
      expect(events.named('intent.ask').single['outcome'], 'app_locked');
    });
  });

  group('a reply that takes longer', () {
    test('answers still working at the deadline and keeps waiting', () async {
      final run = ask('Think hard', within: const Duration(milliseconds: 50));
      final send = await sent();

      final result = await run.answer;
      var finished = false;
      unawaited(run.finished.then((_) => finished = true));
      await pumpEventQueue();

      expect(result.outcome, AskOutcome.stillWorking);
      expect(finished, isFalse);
      expect(transport.closed, isFalse);

      transport.promptAccepted = true;

      send
        ..emit(const ThreadBound('new-1'))
        ..emit(const ReplyCompleted('Done thinking.'));
      await run.finished;

      expect(notifications.shown, hasLength(1));
      expect(notifications.shown.single.threadId, 'new-1');
      expect(notifications.shown.single.body, 'Done thinking.');
      expect(transport.closed, isTrue);
    });

    test('posts "Reply failed" for a late failure', () async {
      final run = ask('Think hard', within: const Duration(milliseconds: 20));
      final send = await sent();
      await run.answer;

      transport.promptAccepted = true;

      send
        ..emit(const ThreadBound('new-1'))
        ..emit(const ReplyCompleted('boom', failed: true));
      await run.finished;

      expect(notifications.shown.single.body, kReplyFailedBody);
    });

    test('still posts the request notification of a late approval', () async {
      final run = ask('Think hard', within: const Duration(milliseconds: 20));
      final send = await sent();
      await run.answer;

      transport.promptAccepted = true;

      send
        ..emit(const ThreadBound('new-1'))
        ..emit(_approval);
      await run.finished;
      await pumpEventQueue();

      expect(notifications.shown.single.request, isNotNull);
    });

    test('stops announcing once iOS has ended the time', () async {
      final run = ask('Think hard', within: const Duration(milliseconds: 20));
      final send = await sent();
      transport.promptAccepted = true;
      send.emit(const ThreadBound('new-1'));
      await run.answer;

      run.expire();
      await run.finished;
      // The reply still arrives on the socket the handler listens to; iOS has
      // taken the time, so it is not announced from here.
      send.emit(const ReplyCompleted('Done thinking.'));
      await pumpEventQueue();

      expect(notifications.shown, isEmpty);
      expect(await running.read(), hasLength(1));
    });
  });

  group('handing the reply to the background check', () {
    Future<List<(String?, String, bool)>> remembered() async => [
      for (final r in await running.read()) (r.profile, r.threadId, r.fromAsk),
    ];

    test('remembers a new chat once the answer was "still working"', () async {
      final run = ask(
        'Think hard',
        profile: 'work',
        within: const Duration(milliseconds: 20),
      );
      final send = await sent();
      await run.answer;
      transport.promptAccepted = true;
      send.emit(const ThreadBound('new-1'));
      await pumpEventQueue();

      expect(await remembered(), [('work', 'new-1', true)]);
    });

    test('remembers a new chat bound before the deadline', () async {
      final run = ask(
        'Think hard',
        profile: 'work',
        within: const Duration(milliseconds: 800),
      );
      final send = await sent();
      transport.promptAccepted = true;
      send.emit(const ThreadBound('new-1'));
      await pumpEventQueue();
      expect(await remembered(), isEmpty);

      await run.answer;
      await pumpEventQueue();

      expect(await remembered(), [('work', 'new-1', true)]);
    });

    test(
      'remembers a continued chat in its own profile once accepted',
      () async {
        final run = ask(
          'Go on',
          profile: 'default',
          chatId: 'work/abc',
          within: const Duration(milliseconds: 20),
        );
        await sent();
        await run.answer;
        await pumpEventQueue();
        // The earlier reply of that chat must not be announced for a question
        // Hermes has not got yet.
        expect(await remembered(), isEmpty);

        transport.promptAccepted = true;
        for (var i = 0; i < 100 && (await remembered()).isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }

        expect(await remembered(), [('work', 'abc', true)]);
      },
    );

    test('remembers nothing for a reply given in place', () async {
      final run = ask('Hello');
      (await sent())
        ..emit(const ThreadBound('new-1'))
        ..emit(const ReplyCompleted('Hi'));
      await run.finished;
      await pumpEventQueue();

      expect(await remembered(), isEmpty);
    });

    test('forgets it when the reply is announced by the ask itself', () async {
      final run = ask('Think hard', within: const Duration(milliseconds: 20));
      final send = await sent();
      await run.answer;
      transport.promptAccepted = true;
      send
        ..emit(const ThreadBound('new-1'))
        ..emit(const ReplyCompleted('Done.'));
      await run.finished;
      await pumpEventQueue();

      expect(notifications.shown.single.body, 'Done.');
      expect(await remembered(), isEmpty);
    });

    test('keeps it when iOS ends the time', () async {
      final run = ask('Think hard', within: const Duration(milliseconds: 20));
      final send = await sent();
      transport.promptAccepted = true;
      send.emit(const ThreadBound('new-1'));
      await run.answer;

      run.expire();
      await run.finished;
      await pumpEventQueue();

      expect(await remembered(), [(null, 'new-1', true)]);
    });

    test(
      'posts no "Reply failed" when the turn ends without a reply',
      () async {
        final run = ask('Think hard', within: const Duration(milliseconds: 20));
        final send = await sent();
        transport.promptAccepted = true;
        send.emit(const ThreadBound('new-1'));
        await run.answer;

        send.finish();
        await run.finished;
        await pumpEventQueue();

        expect(notifications.shown, isEmpty);
        expect(await remembered(), [(null, 'new-1', true)]);
      },
    );
  });

  group('a question that never got to Hermes', () {
    test('is told once, with the question behind a tap', () async {
      final run = ask(
        'What is C++?',
        profile: 'work',
        within: const Duration(milliseconds: 20),
      );
      final send = await sent();
      await run.answer;

      send.finish();
      await run.finished;
      await pumpEventQueue();

      final shown = notifications.shown.single;
      expect(shown.body, "Couldn't send your question");
      expect(shown.title, 'Hermes');
      expect(shown.body, isNot(contains('C++')));
      final target = targetFromPayload(notificationPayload(shown))!;
      expect(target.prompt, 'What is C++?');
      expect(target.profile, 'work');
    });

    test('is told when the server cannot be reached after all', () async {
      server.on('GET', '/api/status', {}, status: 503);
      final run = ask('Hello', within: Duration.zero);

      expect((await run.answer).outcome, AskOutcome.stillWorking);
      await run.finished;

      expect(notifications.shown.single.prompt, 'Hello');
    });

    test('is told when nobody is signed in after all', () async {
      store.session = null;
      final run = ask('Hello', within: Duration.zero);

      await run.answer;
      await run.finished;

      expect(notifications.shown.single.prompt, 'Hello');
    });

    test('is not told when the answer was given in time', () async {
      store.session = null;
      final run = ask('Hello');

      expect((await run.answer).outcome, AskOutcome.signedOut);
      await run.finished;

      expect(notifications.shown, isEmpty);
    });

    test('is not told once Hermes accepted the question', () async {
      final run = ask('Hello', within: const Duration(milliseconds: 20));
      final send = await sent();
      send.emit(const ThreadBound('new-1'));
      await run.answer;
      // prompt.submit was answered, then the socket died before any frame.
      transport.promptAccepted = true;

      send.finish();
      await run.finished;
      await pumpEventQueue();

      expect(notifications.shown, isEmpty);
      expect(await running.read(), hasLength(1));
    });

    test(
      'is told when the chat was made but the prompt not accepted',
      () async {
        final run = ask('Hello', within: const Duration(milliseconds: 20));
        final send = await sent();
        send.emit(const ThreadBound('new-1'));
        await run.answer;

        send.finish();
        await run.finished;

        expect(notifications.shown.single.body, kAskNotSentBody);
        expect(await running.read(), isEmpty);
      },
    );

    test('carries at most 4000 characters of the question', () async {
      final run = ask('é' * 5000, within: Duration.zero);
      await sent();
      await run.answer;
      (transport.sends.single).finish();
      await run.finished;

      expect(notifications.shown.single.prompt, 'é' * 4000);
    });

    test('carries none of it once App Lock is on', () async {
      final run = ask('Hello', within: Duration.zero);
      await sent();
      await run.answer;
      appLockOn = true;
      transport.sends.single.finish();
      await run.finished;

      expect(notifications.shown.single.body, kAskNotSentBody);
      expect(notifications.shown.single.prompt, isNull);
    });
  });

  group('a second ask on a chat that is replying', () {
    test('is added to the running turn and posts nothing', () async {
      final run = ask('And this', chatId: 'work/abc');
      final send = await sent();
      send
        ..emit(const PromptFolded())
        ..finish();

      final result = await run.answer;
      await run.finished;
      await pumpEventQueue();

      expect(result.outcome, AskOutcome.folded);
      expect(notifications.shown, isEmpty);
    });
  });

  group('the deadline', () {
    test('is decided half a second before the intent gives up', () {
      const request = AskRequest(
        question: 'q',
        answerWithin: Duration(seconds: 20),
      );
      expect(request.decideWithin, const Duration(milliseconds: 19500));
      expect(
        const AskRequest(
          question: 'q',
          answerWithin: Duration(milliseconds: 200),
        ).decideWithin,
        Duration.zero,
      );
    });
  });

  group('an engine that was not there', () {
    test('is recorded with a fixed reason', () {
      hermes()
        ..recordUnavailable('ready_timeout')
        ..recordUnavailable('engine_start_failed')
        ..recordUnavailable('whatever the caller made up');

      expect(events.named('intent.unavailable'), [
        {'reason': 'ready_timeout'},
        {'reason': 'engine_start_failed'},
        {'reason': 'other'},
      ]);
    });
  });
  group('telemetry', () {
    Future<void> settle(AskRun run) async {
      await run.answer;
      await run.finished;
    }

    test(
      'records the span, the event and no breadcrumbs in a headless engine',
      () async {
        final run = ask('my salary is 100000', profile: 'secret-profile');
        (await sent()).emit(const ReplyCompleted('Your salary is public.'));
        await settle(run);

        final span = tracer.spans.single;
        expect(span.name, 'background.task');
        expect(span.attributes['task'], 'intent.ask');
        expect(span.attributes['engine'], 'headless');
        expect(span.attributes['continued'], false);
        expect(span.attributes['ask.outcome'], 'answered');
        expect(events.named('intent.ask'), [
          {'outcome': 'answered', 'waited_s': '<5'},
        ]);
        expect(trail.recent, isEmpty);
      },
    );

    test('the foreground engine leaves breadcrumbs', () async {
      final run = ask(
        'Hello',
        chatId: 'work/abc',
        engine: AskEngine.foreground,
      );
      (await sent()).emit(const ReplyCompleted('Hi'));
      await settle(run);

      expect(tracer.spans.single.attributes['engine'], 'foreground');
      expect(tracer.spans.single.attributes['continued'], true);
      expect(
        [for (final c in trail.recent) '${c.name} ${c.attributes}'],
        [
          'intent.ask.started {continued: true}',
          'intent.ask.ended {outcome: answered}',
        ],
      );
    });

    test('App Lock and a blank question have a span of their own', () async {
      appLockOn = true;
      await settle(ask('Hello', chatId: 'work/abc'));
      appLockOn = false;
      await settle(ask('  '));

      expect(
        [
          for (final s in tracer.spans)
            (
              s.attributes['task'],
              s.attributes['ask.outcome'],
              s.attributes['continued'],
            ),
        ],
        [('intent.ask', 'app_locked', true), ('intent.ask', 'failed', false)],
      );
    });

    test('a late reply counts as late', () async {
      final run = ask('Think', within: const Duration(milliseconds: 20));
      final send = await sent();
      await run.answer;
      send.emit(const ReplyCompleted('Hi'));
      await run.finished;

      expect(events.named('intent.ask'), [
        {'outcome': 'still_working', 'waited_s': 'late'},
      ]);
    });

    test('a run that cannot start still carries the span attributes', () async {
      store.session = null;
      final run = ask('Hello', chatId: 'work/abc');
      await settle(run);

      expect(tracer.spans.single.attributes['continued'], true);
      expect(events.named('intent.ask').single['outcome'], 'signed_out');
    });

    test('buckets the wait', () {
      expect(waitedBucket(const Duration(seconds: 1)), '<5');
      expect(waitedBucket(const Duration(seconds: 5)), '<15');
      expect(waitedBucket(const Duration(seconds: 14)), '<15');
      expect(waitedBucket(const Duration(seconds: 15)), '<25');
      expect(waitedBucket(const Duration(seconds: 25)), 'late');
    });

    test('carries no text, title, profile or id', () async {
      final run = ask(
        'my salary',
        profile: 'secret-profile',
        chatId: 'work/abc',
      );
      final send = await sent();
      send
        ..emit(const ThreadBound('thread-77'))
        ..emit(const ThreadTitled('Salary talk'))
        ..emit(const ReplyCompleted('reply text'));
      await settle(run);

      final recorded = [
        ...tracer.spans.map((s) => s.attributes.toString()),
        ...events.named('intent.ask').map((a) => a.toString()),
        ...trail.recent.map((c) => '${c.name} ${c.attributes}'),
      ].join(' ');
      for (final secret in [
        'salary',
        'secret-profile',
        'work',
        'abc',
        'thread-77',
        'Salary talk',
        'reply text',
      ]) {
        expect(recorded, isNot(contains(secret)));
      }
    });
  });
}
