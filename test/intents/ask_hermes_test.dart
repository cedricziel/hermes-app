import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/background/headless_hermes.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/intents/ask_hermes.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
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
    appLockOn = false;
  });

  AskHermes hermes({AskEngine engine = AskEngine.headless}) => AskHermes(
    engine: engine,
    notifications: notifications,
    events: events.call,
    breadcrumbs: Breadcrumbs.of(trail),
    appLockOn: () async => appLockOn,
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
      await run.answer;

      run.expire();
      await run.finished;
      // Closing the socket ends the turn, which the handler would announce
      // as a failed reply.
      send.finish();
      await pumpEventQueue();

      expect(notifications.shown, isEmpty);
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
