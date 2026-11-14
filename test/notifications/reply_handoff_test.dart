import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/account_key.dart';
import 'package:hermes_app/src/auth/auth_controller.dart'
    show kSavedServerUrlKey, normalizeServerUrl;
import 'package:hermes_app/src/background/headless_hermes.dart';
import 'package:hermes_app/src/background/running_replies.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/inline_reply.dart';
import 'package:hermes_app/src/notifications/local_notification_service.dart';
import 'package:hermes_app/src/notifications/notification_posting.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/notification_settings.dart';
import 'package:hermes_app/src/notifications/request_answers.dart';
import 'package:hermes_app/src/notifications/request_notifications.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/fake_chat_transport.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_notification_service.dart';
import '../support/memory_token_store.dart';
import '../support/recording_tracer.dart';

const _url = 'http://hermes.test';
const _session = HermesSession(
  accessToken: 'access',
  refreshToken: 'refresh',
  expiresAt: 4102444800,
  provider: 'basic',
  userId: 'u1',
  serverUrl: _url,
  mintedAt: 1000,
);

const _approval = NotificationAnswer(
  target: NotificationTarget(threadId: 's1', profile: 'work'),
  title: 'Cleanup',
  request: PendingRequest(requestId: 'r1', kind: PendingRequestKind.approval),
  answer: ApprovalChoiceAnswer('once'),
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
  late NotificationSettings settings;
  late RunningReplies running;
  late RequestAnswerSender sender;
  late String hash;
  var inFront = false;
  var appLockOn = false;
  late List<({InlineReplyRoute route, DateTime due, String? input})> calls;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({kSavedServerUrlKey: _url});
    server = FakeHermesServer()
      ..on('GET', '/api/status', {'auth_required': true});
    store = MemoryTokenStore(_session);
    transport = FakeChatTransport();
    notifications = FakeNotificationService();
    settings = NotificationSettings();
    running = RunningReplies();
    sender = RequestAnswerSender(
      transport: () => transport,
      notifications: notifications,
    );
    hash = accountHashFor(accountKeyFor(normalizeServerUrl(_url)!, _session));
    inFront = false;
    appLockOn = false;
    calls = [];
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  HeadlessDeps deps() => HeadlessDeps(
    tokenStore: store,
    prefs: SharedPreferencesAsync(),
    devServerUrl: '',
    adapter: server,
    telemetry: (attributes) => ConnectionTelemetry(tracer: RecordingTracer()),
    closeGrace: const Duration(milliseconds: 50),
  );

  String payload({bool marker = true, bool request = false}) => jsonEncode({
    't': 'thread-1',
    'p': 'work',
    if (marker) 'y': 1,
    'n': 'Trip plan',
    'a': hash,
    if (request) ...{
      'r': const PendingRequest(
        requestId: 'r1',
        kind: PendingRequestKind.approval,
      ).toJson(),
    },
  });

  NotificationResponse response({
    String? input = 'Yes, book it',
    String? body,
    String actionId = kReplyChatAction,
    bool marker = true,
    bool request = false,
  }) => NotificationResponse(
    notificationResponseType:
        NotificationResponseType.selectedNotificationAction,
    payload: body ?? payload(marker: marker, request: request),
    actionId: actionId,
    input: input,
  );

  /// The app's reply handler: the real [sendInlineReply] on the fake
  /// transport.
  InlineReplyRunner runner() =>
      ({required payload, required input, required due, required route}) {
        calls.add((route: route, due: due, input: input));
        return sendInlineReply(
          payload: payload,
          input: input,
          due: due,
          route: route,
          platform: TargetPlatform.iOS,
          notifications: notifications,
          settings: settings,
          appLockAtArrival: () async => appLockOn,
          appLockBeforePost: () async => appLockOn,
          appInFront: () async => inFront,
          running: running,
          transportFor: (_) => transport,
          deps: deps(),
        );
      };

  /// An app that offers and, once confirmed, reports [report] after [after]
  /// (never for null).
  ReceivePort fakeApp(
    String? report, {
    Duration after = Duration.zero,
    void Function()? onGo,
  }) {
    final app = ReceivePort();
    addTearDown(app.close);
    app.listen((message) {
      final reply = (message as List).last as SendPort;
      final confirm = ReceivePort();
      addTearDown(confirm.close);
      confirm.listen((go) async {
        if (go != 'go') return;
        onGo?.call();
        if (report == null) return;
        await Future<void>.delayed(after);
        reply.send(report);
      });
      reply.send(['offer', confirm.sendPort]);
    });
    return app;
  }

  group('routing a reply from the background isolate', () {
    test('hands it to the running app, which sends it once', () async {
      final app = RequestAnswers(sender, reply: runner())..start();
      addTearDown(app.dispose);
      var alone = 0;
      final due = DateTime.now().add(const Duration(seconds: 25));

      final run = routeAnswer(
        response(),
        deadline: due,
        unanswered: (_) async {},
        alone: (_, _) async => AnswerOutcome.ok,
        aloneReply: (_, _) async {
          alone++;
          return AnswerOutcome.ok;
        },
        unansweredReply: (_) async => fail('the app posted its own ending'),
      );
      await _until(() => transport.sends.isNotEmpty);
      final send = transport.sends.single;
      send.onSubmitting!();
      transport.promptAccepted = true;
      send.emit(const ReplyCompleted('Done.'));

      expect(await run, AnswerOutcome.ok);
      expect(alone, 0);
      expect(transport.sends, hasLength(1));
      expect(send.text, 'Yes, book it');
      expect(send.queued, isTrue);
      expect(calls.single.route, InlineReplyRoute.app);
      expect(
        calls.single.due.millisecondsSinceEpoch,
        due.millisecondsSinceEpoch,
      );
    });

    test(
      'never reaches an answer, even next to a request in its payload',
      () async {
        final app = RequestAnswers(sender, reply: runner())..start();
        addTearDown(app.dispose);

        final run = routeAnswer(
          response(request: true),
          unanswered: (_) async {},
          alone: (_, _) async => fail('a reply is not an answer'),
          aloneReply: (_, _) async => fail('the app takes it'),
          unansweredReply: (_) async {},
        );
        await _until(() => transport.sends.isNotEmpty);
        transport.sends.single
          ..onSubmitting!()
          ..emit(const ReplyCompleted('ok'));
        transport.promptAccepted = true;
        await run;

        expect(transport.openAnswers, isEmpty);
        expect(transport.approvalAnswers, isEmpty);
        expect(transport.clarifyAnswers, isEmpty);
      },
    );

    test('answers alone at once with no app', () async {
      final due = DateTime.now().add(const Duration(seconds: 25));
      NotificationResponse? taken;
      DateTime? takenDue;

      final outcome = await routeAnswer(
        response(),
        lookup: () => null,
        pollFor: Duration.zero,
        deadline: due,
        unanswered: (_) async {},
        alone: (_, _) async => fail('a reply is not an answer'),
        aloneReply: (reply, deadline) async {
          taken = reply;
          takenDue = deadline;
          return AnswerOutcome.ok;
        },
        unansweredReply: (_) async {},
      );

      expect(outcome, AnswerOutcome.ok);
      expect(taken?.input, 'Yes, book it');
      expect(takenDue, due);
    });

    test('goes alone when the app has no reply handler to offer', () async {
      final app = RequestAnswers(sender)..start();
      addTearDown(app.dispose);
      var alone = 0;

      await routeAnswer(
        response(),
        takeTimeout: const Duration(milliseconds: 50),
        unanswered: (_) async {},
        alone: (_, _) async => AnswerOutcome.ok,
        aloneReply: (_, _) async {
          alone++;
          return AnswerOutcome.ok;
        },
        unansweredReply: (_) async {},
      );

      expect(alone, 1);
      expect(transport.sends, isEmpty);
    });

    test(
      'an offer that comes too late is never confirmed: one prompt',
      () async {
        final app = ReceivePort();
        addTearDown(app.close);
        final confirmed = <Object?>[];
        app.listen((message) async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          final confirm = ReceivePort();
          confirm.listen(confirmed.add);
          ((message as List).last as SendPort).send([
            'offer',
            confirm.sendPort,
          ]);
          await Future<void>.delayed(const Duration(milliseconds: 40));
          confirm.close();
        });
        var alone = 0;

        await routeAnswer(
          response(),
          lookup: () => app.sendPort,
          takeTimeout: const Duration(milliseconds: 10),
          unanswered: (_) async {},
          alone: (_, _) async => AnswerOutcome.ok,
          aloneReply: (_, _) async {
            alone++;
            return AnswerOutcome.ok;
          },
          unansweredReply: (_) async {},
        );
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(alone, 1);
        expect(confirmed, isEmpty);
      },
    );

    test(
      'a reply with no text, no marker or a job target is not routed',
      () async {
        var handled = 0;
        Future<AnswerOutcome> alone(NotificationResponse _, DateTime _) async {
          handled++;
          return AnswerOutcome.ok;
        }

        for (final r in [
          response(input: null),
          response(input: '  \n'),
          response(marker: false),
          response(body: jsonEncode({'j': 'job-1', 'y': 1})),
          response(body: 'plain-thread-id'),
        ]) {
          final outcome = await routeAnswer(
            r,
            lookup: () => null,
            pollFor: Duration.zero,
            unanswered: (_) async {},
            alone: (_, _) async => fail('a reply is not an answer'),
            aloneReply: alone,
            unansweredReply: (_) async => handled++,
          );
          expect(outcome, AnswerOutcome.failed);
        }

        expect(handled, 0);
      },
    );

    group('after the app took it over', () {
      Future<(AnswerOutcome, int)> route(
        String? report, {
        Duration after = Duration.zero,
        Duration left = const Duration(seconds: 5),
      }) async {
        final app = fakeApp(report, after: after);
        var told = 0;
        final outcome = await routeAnswer(
          response(),
          lookup: () => app.sendPort,
          deadline: DateTime.now().add(left),
          reportGrace: const Duration(milliseconds: 30),
          unanswered: (_) async {},
          alone: (_, _) async => fail('a reply is not an answer'),
          aloneReply: (_, _) async => fail('the app took it'),
          unansweredReply: (_) async => told++,
        );
        return (outcome, told);
      }

      test(
        'an ending the app posted stands: the isolate posts nothing',
        () async {
          final (outcome, told) = await route('unconfirmed:posted');
          expect(outcome, AnswerOutcome.failed);
          expect(told, 0);
          expect((await route('notSent:posted')).$2, 0);
          expect((await route('appLocked:posted')).$1, AnswerOutcome.locked);
        },
      );

      test('an answer or a send with no ending due needs none', () async {
        expect(await route('answered:none'), (AnswerOutcome.ok, 0));
        expect(await route('sent:none'), (AnswerOutcome.ok, 0));
        expect((await route('ignored:none')).$2, 0);
      });

      test('an ending due and not posted is posted by the isolate', () async {
        expect((await route('unconfirmed:none')).$2, 1);
        expect((await route('notSent:none')).$2, 1);
      });

      test('no report by due + reportGrace is "Couldn\'t confirm"', () async {
        final watch = Stopwatch()..start();
        final (outcome, told) = await route(
          null,
          left: const Duration(milliseconds: 100),
        );
        expect(outcome, AnswerOutcome.failed);
        expect(told, 1);
        expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(120));
      });

      test('a report that cannot be read counts as none', () async {
        expect((await route('whatever')).$2, 1);
        expect((await route('sent')).$2, 1);
      });

      test('a late report cannot replace the isolate\'s ending', () async {
        final app = fakeApp(
          'unconfirmed:posted',
          after: const Duration(milliseconds: 200),
        );
        var told = 0;

        await routeAnswer(
          response(),
          lookup: () => app.sendPort,
          deadline: DateTime.now().add(const Duration(milliseconds: 50)),
          reportGrace: const Duration(milliseconds: 30),
          unanswered: (_) async {},
          alone: (_, _) async => fail('a reply is not an answer'),
          aloneReply: (_, _) async => fail('the app took it'),
          unansweredReply: (_) async => told++,
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));

        // One ending, from the isolate; the late report found no listener.
        expect(told, 1);
      });
    });
  });

  group('the running app takes a reply over', () {
    test('its ending is posted before due and reported as posted', () async {
      final app = RequestAnswers(sender, reply: runner())..start();
      addTearDown(app.dispose);
      var told = 0;
      // The cutoff is 6 s before due: the prompt is written, never answered.
      final due = DateTime.now().add(const Duration(milliseconds: 6300));

      final run = routeAnswer(
        response(),
        deadline: due,
        unanswered: (_) async {},
        alone: (_, _) async => fail('a reply is not an answer'),
        aloneReply: (_, _) async => fail('the app took it'),
        unansweredReply: (_) async => told++,
      );
      await _until(() => transport.sends.isNotEmpty);
      transport.sends.single.onSubmitting!();

      await run;

      expect(told, 0);
      final shown = notifications.shown.single;
      expect(shown.body, kReplyUnconfirmedBody);
      expect(shown.title, 'Trip plan');
      expect(transport.sends, hasLength(1));
    });

    test('an ending that was not posted is posted by the isolate', () async {
      notifications.postResult = const NotificationPostResult(
        NotificationPostStatus.failed,
      );
      final app = RequestAnswers(sender, reply: runner())..start();
      addTearDown(app.dispose);
      final isolate = FakeNotificationService();

      final run = routeAnswer(
        response(),
        deadline: DateTime.now().add(const Duration(milliseconds: 6300)),
        unanswered: (_) async {},
        alone: (_, _) async => fail('a reply is not an answer'),
        aloneReply: (_, _) async => fail('the app took it'),
        unansweredReply: (reply) => postReplyUnconfirmed(
          payload: reply.payload,
          notifications: isolate,
          settings: settings,
          appLockOn: () async => false,
        ),
      );
      await _until(() => transport.sends.isNotEmpty);
      transport.sends.single.onSubmitting!();
      await run;

      expect(notifications.shown, isEmpty);
      expect(isolate.shown.single.body, kReplyUnconfirmedBody);
    });

    test('an answer announced once while the app is away', () async {
      final app = RequestAnswers(sender, reply: runner())..start();
      addTearDown(app.dispose);

      final run = routeAnswer(
        response(),
        unanswered: (_) async {},
        alone: (_, _) async => fail('a reply is not an answer'),
        aloneReply: (_, _) async => fail('the app took it'),
        unansweredReply: (_) async => fail('the app is fine'),
      );
      await _until(() => transport.sends.isNotEmpty);
      transport.sends.single.onSubmitting!();
      transport.promptAccepted = true;
      transport.sends.single.emit(const ReplyCompleted('Booked.'));
      await run;

      expect(notifications.shown, hasLength(1));
      expect(notifications.shown.single.threadId, 'thread-1');
    });

    test(
      'nothing is announced while the app is in front: the open chat does',
      () async {
        inFront = true;
        final app = RequestAnswers(sender, reply: runner())..start();
        addTearDown(app.dispose);

        final run = routeAnswer(
          response(),
          unanswered: (_) async {},
          alone: (_, _) async => fail('a reply is not an answer'),
          aloneReply: (_, _) async => fail('the app took it'),
          unansweredReply: (_) async => fail('the app is fine'),
        );
        await _until(() => transport.sends.isNotEmpty);
        transport.sends.single.onSubmitting!();
        transport.promptAccepted = true;
        transport.sends.single.emit(const ReplyCompleted('Booked.'));
        await run;

        expect(notifications.shown, isEmpty);
        expect(await running.takeAnnounced('work', 'thread-1'), isFalse);
      },
    );

    test('a failure inside the handler is reported as unconfirmed', () async {
      final app = RequestAnswers(
        sender,
        reply: ({
          required payload,
          required input,
          required due,
          required route,
        }) async => throw StateError('boom'),
      )..start();
      addTearDown(app.dispose);
      var told = 0;

      await routeAnswer(
        response(),
        unanswered: (_) async {},
        alone: (_, _) async => fail('a reply is not an answer'),
        aloneReply: (_, _) async => fail('the app took it'),
        unansweredReply: (_) async => told++,
      );

      expect(told, 1);
    });

    test(
      'request answers still go to the request, not to the reply handler',
      () async {
        final app = RequestAnswers(sender, reply: runner())..start();
        addTearDown(app.dispose);
        final approval = NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          payload: notificationPayload(
            attentionFor(
              event: const ApprovalRequested(
                ApprovalRequest(
                  requestId: 'r1',
                  command: 'rm -rf build',
                  description: '',
                  choices: ['once', 'deny'],
                ),
              ),
              thread: ChatThread(
                id: 's1',
                title: 'Cleanup',
                updatedAt: DateTime(2026),
              ),
              appFocused: false,
              selectedThreadId: null,
              enabled: true,
              profile: 'work',
            )!,
          ),
          actionId: kDenyAction,
        );

        final outcome = await routeAnswer(
          approval,
          unanswered: (_) async {},
          alone: (_, _) async => AnswerOutcome.failed,
        );

        expect(outcome, AnswerOutcome.ok);
        expect(transport.openAnswers, hasLength(1));
        expect(calls, isEmpty);
        expect(transport.sends, isEmpty);
      },
    );
  });

  group('on macOS', () {
    test(
      'a reply the notification service reports is sent once, by mac',
      () async {
        final app = RequestAnswers(
          sender,
          service: notifications,
          reply: runner(),
        )..start();
        addTearDown(app.dispose);
        final received = DateTime.now();

        notifications.reply(
          NotificationReply(
            payload: payload(),
            input: 'Yes, book it',
            receivedAt: received,
          ),
        );
        await _until(() => transport.sends.isNotEmpty);
        transport.sends.single
          ..onSubmitting!()
          ..emit(const ReplyCompleted('Done.'));
        transport.promptAccepted = true;
        await pumpEventQueue();

        expect(transport.sends, hasLength(1));
        expect(transport.openAnswers, isEmpty);
        expect(calls.single.route, InlineReplyRoute.mac);
        // The budget starts when Dart received the response.
        expect(calls.single.due, received.add(kAnswerBudget));
      },
    );

    test('a reply is not an answer for the sender either', () async {
      final app = RequestAnswers(sender, service: notifications)..start();
      addTearDown(app.dispose);

      notifications.reply(
        NotificationReply(
          payload: payload(request: true),
          input: 'Yes',
          receivedAt: DateTime.now(),
        ),
      );
      await pumpEventQueue();

      expect(transport.openAnswers, isEmpty);
      expect(notifications.shown, isEmpty);
    });
  });

  group('a reply that cannot be told', () {
    test('on the mac route says "Couldn\'t confirm" once', () async {
      final app = RequestAnswers(
        sender,
        service: notifications,
        settings: settings,
        reply: ({
          required payload,
          required input,
          required due,
          required route,
        }) async => throw StateError('boom'),
      )..start();
      addTearDown(app.dispose);

      notifications.reply(
        NotificationReply(
          payload: payload(),
          input: 'Yes',
          receivedAt: DateTime.now(),
        ),
      );
      await _until(() => notifications.shown.isNotEmpty);
      await pumpEventQueue();

      expect(notifications.shown.single.body, kReplyUnconfirmedBody);
      expect(notifications.shown.single.title, 'Trip plan');
    });

    test(
      'on the mac route an ending that was not posted is said once',
      () async {
        var first = true;
        final app = RequestAnswers(
          sender,
          service: notifications,
          settings: settings,
          reply:
              ({
                required payload,
                required input,
                required due,
                required route,
              }) async {
                if (!first) fail('sent twice');
                first = false;
                return const InlineReplyResult(
                  InlineReplyOutcome.failed,
                  ending: ReplyEnding.notSent,
                );
              },
        )..start();
        addTearDown(app.dispose);

        notifications.reply(
          NotificationReply(
            payload: payload(),
            input: 'Yes',
            receivedAt: DateTime.now(),
          ),
        );
        await _until(() => notifications.shown.isNotEmpty);

        expect(notifications.shown.single.body, kReplyUnconfirmedBody);
      },
    );

    test('on the mac route a posted ending stands alone', () async {
      final app = RequestAnswers(
        sender,
        service: notifications,
        settings: settings,
        reply:
            ({
              required payload,
              required input,
              required due,
              required route,
            }) async => const InlineReplyResult(
              InlineReplyOutcome.unconfirmed,
              ending: ReplyEnding.unconfirmed,
              endingPosted: true,
            ),
      )..start();
      addTearDown(app.dispose);

      notifications.reply(
        NotificationReply(
          payload: payload(),
          input: 'Yes',
          receivedAt: DateTime.now(),
        ),
      );
      await pumpEventQueue();

      expect(notifications.shown, isEmpty);
    });
  });

  group('the app route when everything hangs', () {
    test(
      'an announcement dropped at the cutoff leaves the chat recorded',
      () async {
        final slow = _SlowAllowed(const Duration(milliseconds: 900));
        final run = sendInlineReply(
          payload: payload(),
          input: 'Yes',
          due: DateTime.now().add(const Duration(milliseconds: 400)),
          route: InlineReplyRoute.lone,
          platform: TargetPlatform.iOS,
          notifications: slow,
          settings: settings,
          appLockAtArrival: () async => false,
          appLockBeforePost: () async => false,
          appInFront: () async => false,
          running: running,
          transportFor: (_) => transport,
          deps: deps(),
        );
        await _until(() => transport.sends.isNotEmpty);
        transport.sends.single.onSubmitting!();
        transport.promptAccepted = true;
        transport.sends.single.emit(const ReplyCompleted('Booked.'));

        final result = await run;
        await Future<void>.delayed(const Duration(milliseconds: 1100));

        expect(result.ending, isNull);
        expect((await running.read()).map((r) => r.threadId), ['thread-1']);
        expect(await running.readAnnounced(), isEmpty);
        expect(slow.shown, isEmpty);
      },
    );

    group('one grace for everything that hangs', () {
      HeadlessDeps slowDeps() => HeadlessDeps(
        tokenStore: store,
        prefs: SharedPreferencesAsync(),
        devServerUrl: '',
        adapter: server,
        telemetry: (attributes) =>
            ConnectionTelemetry(tracer: RecordingTracer()),
        closeGrace: const Duration(milliseconds: 400),
      );

      Future<InlineReplyResult> start(
        FakeChatTransport hung,
        NotificationService service,
      ) => sendInlineReply(
        payload: payload(),
        input: 'Yes',
        due: DateTime.now().add(const Duration(milliseconds: 300)),
        route: InlineReplyRoute.lone,
        platform: TargetPlatform.iOS,
        notifications: service,
        settings: settings,
        appLockAtArrival: () async => false,
        appLockBeforePost: () async => false,
        appInFront: () async => false,
        running: running,
        transportFor: (_) => hung,
        deps: slowDeps(),
      );

      test(
        'a hung close and a hung announcement end within one grace',
        () async {
          final hung = _HangingClose();
          final watch = Stopwatch()..start();
          final run = start(hung, _SlowAllowed(const Duration(seconds: 10)));
          await _until(() => hung.sends.isNotEmpty);
          hung.sends.single
            ..onSubmitting!()
            ..emit(const ReplyCompleted('Booked.'));
          hung.promptAccepted = true;

          await run;

          // 0.3 s cutoff + one 0.4 s grace for the runtime + one for close and
          // announcement together; two in sequence would pass 1.5 s.
          expect(watch.elapsedMilliseconds, lessThan(950));
        },
      );

      test('the transport is closed once, however many ask', () async {
        final hung = _HangingClose();
        final watch = Stopwatch()..start();
        final run = start(hung, notifications);
        await _until(() => hung.sends.isNotEmpty);
        hung.sends.single.onSubmitting!();

        await run;

        expect(hung.closeCalls, 1);
        expect(watch.elapsedMilliseconds, lessThan(1000));
      });
    });

    test(
      'an announcement not yet posted at the cutoff is never posted',
      () async {
        final slowAllowed = _SlowAllowed(const Duration(milliseconds: 600));
        final app = RequestAnswers(
          sender,
          reply:
              ({
                required payload,
                required input,
                required due,
                required route,
              }) => sendInlineReply(
                payload: payload,
                input: input,
                due: due,
                route: route,
                platform: TargetPlatform.iOS,
                notifications: slowAllowed,
                settings: settings,
                appLockAtArrival: () async => false,
                appLockBeforePost: () async => false,
                appInFront: () async => false,
                running: running,
                transportFor: (_) => transport,
                deps: deps(),
              ),
        )..start();
        addTearDown(app.dispose);

        final run = routeAnswer(
          response(),
          deadline: DateTime.now().add(const Duration(milliseconds: 6300)),
          unanswered: (_) async {},
          alone: (_, _) async => fail('a reply is not an answer'),
          aloneReply: (_, _) async => fail('the app took it'),
          unansweredReply: (_) async {},
        );
        await _until(() => transport.sends.isNotEmpty);
        transport.sends.single
          ..onSubmitting!()
          ..emit(const ReplyCompleted('Booked.'));
        await run;
        await Future<void>.delayed(const Duration(milliseconds: 800));

        expect(
          slowAllowed.shown.where((n) => n.body == kReplyUnconfirmedBody),
          hasLength(1),
        );
        expect(
          slowAllowed.shown.where((n) => n.body != kReplyUnconfirmedBody),
          isEmpty,
        );
      },
    );
  });

  group('LocalNotificationService on macOS', () {
    late _Plugin plugin;
    late LocalNotificationService service;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      plugin = _Plugin();
      service = LocalNotificationService(
        plugin: plugin,
        registerCategories: (_) async {},
      );
    });

    tearDown(() => service.dispose());

    Future<void> started() async {
      await service.requestPermission();
    }

    test('reports a reply on replies, not on answers or taps', () async {
      await started();
      final replies = <NotificationReply>[];
      final answers = <NotificationAnswer>[];
      final taps = <NotificationTarget>[];
      final subs = [
        service.replies.listen(replies.add),
        service.answers.listen(answers.add),
        service.taps.listen(taps.add),
      ];
      addTearDown(() async {
        for (final sub in subs) {
          await sub.cancel();
        }
      });

      final before = DateTime.now();
      plugin.onResponse!(response(request: true));
      await pumpEventQueue();

      expect(replies, hasLength(1));
      expect(replies.single.input, 'Yes, book it');
      expect(replies.single.payload, payload(request: true));
      expect(replies.single.receivedAt.isBefore(before), isFalse);
      expect(answers, isEmpty);
      expect(taps, isEmpty);
    });

    test(
      'a cold-launch reply is handed over once and does not open the chat',
      () async {
        plugin.launchDetails = NotificationAppLaunchDetails(
          true,
          notificationResponse: response(),
        );
        final replies = <NotificationReply>[];
        final taps = <NotificationTarget>[];
        final subs = [
          service.replies.listen(replies.add),
          service.taps.listen(taps.add),
        ];
        addTearDown(() async {
          for (final sub in subs) {
            await sub.cancel();
          }
        });

        expect(await service.launchTarget(), isNull);
        expect(await service.launchTarget(), isNull);
        await pumpEventQueue();

        expect(replies, hasLength(1));
        expect(taps, isEmpty);
      },
    );

    test('a cold-launch reply is sent once by the app', () async {
      plugin.launchDetails = NotificationAppLaunchDetails(
        true,
        notificationResponse: response(),
      );
      final app = RequestAnswers(sender, service: service, reply: runner())
        ..start();
      addTearDown(app.dispose);

      await service.launchTarget();
      await service.launchTarget();
      await _until(() => transport.sends.isNotEmpty);
      await pumpEventQueue();

      expect(transport.sends, hasLength(1));
      expect(calls.single.route, InlineReplyRoute.mac);
    });
  });

  group('answering a reply alone', () {
    late LoneAnswerer lone;

    setUp(() {
      lone = LoneAnswerer(
        transportFor: (_) => transport,
        notifications: notifications,
        settings: settings,
        running: running,
        appInFront: () async => inFront,
        locked: () async => appLockOn,
        deps: deps(),
      );
    });

    test('sends the text once, queued, with the lone budget', () async {
      final run = lone.reply(
        response(),
        DateTime.now().add(const Duration(seconds: 25)),
      );
      await _until(() => transport.sends.isNotEmpty);
      final send = transport.sends.single;
      send.onSubmitting!();
      transport.promptAccepted = true;
      send.emit(const ReplyCompleted('Done.'));

      expect(await run, AnswerOutcome.ok);
      expect(send.text, 'Yes, book it');
      expect(send.queued, isTrue);
      expect(transport.openAnswers, isEmpty);
    });

    test('goes in one chain with answers: never two at once', () async {
      final gate = transport.openAnswerGate = Completer<void>();
      final due = DateTime.now().add(const Duration(seconds: 25));

      final answer = lone.answer(_approval, due);
      final reply = lone.reply(response(), due);
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(transport.sends, isEmpty);

      gate.complete();
      await answer;
      await _until(() => transport.sends.isNotEmpty);
      transport.sends.single
        ..onSubmitting!()
        ..emit(const ReplyCompleted('Done.'));
      transport.promptAccepted = true;

      expect(await reply, AnswerOutcome.ok);
      expect(transport.openAnswers, hasLength(1));
      expect(transport.sends, hasLength(1));
    });

    test('with App Lock on sends nothing and says to open the app', () async {
      appLockOn = true;

      final outcome = await lone.reply(
        response(),
        DateTime.now().add(const Duration(seconds: 25)),
      );

      expect(outcome, AnswerOutcome.locked);
      expect(transport.sends, isEmpty);
      expect(notifications.shown.single.body, kOpenToReplyBody);
      expect(notifications.shown.single.title, 'Hermes');
    });
  });

  group("the isolate's own ending", () {
    test('is "Couldn\'t confirm", for the chat, under its title', () async {
      expect(
        await postReplyUnconfirmed(
          payload: payload(),
          notifications: notifications,
          settings: settings,
          appLockOn: () async => false,
        ),
        isTrue,
      );

      final shown = notifications.shown.single;
      expect(shown.body, kReplyUnconfirmedBody);
      expect(shown.title, 'Trip plan');
      expect(shown.threadId, 'thread-1');
      expect(shown.profile, 'work');
      expect(shown.category, isNull);
    });

    test('is under "Hermes" while App Lock is on, re-read right now', () async {
      await postReplyUnconfirmed(
        payload: payload(),
        notifications: notifications,
        settings: settings,
        appLockOn: () async => true,
      );

      expect(notifications.shown.single.title, 'Hermes');
      expect(notifications.shown.single.body, kReplyUnconfirmedBody);
      expect(
        notificationPayload(notifications.shown.single),
        isNot(contains('Trip plan')),
      );
    });

    test('is under "Hermes" when App Lock cannot be read', () async {
      await postReplyUnconfirmed(
        payload: payload(),
        notifications: notifications,
        settings: settings,
        appLockOn: () async => throw StateError('unreadable'),
      );

      expect(notifications.shown.single.title, 'Hermes');
    });

    test(
      'is not posted while notifications are off or not permitted',
      () async {
        notifications.allowedAnswer = false;
        expect(
          await postReplyUnconfirmed(
            payload: payload(),
            notifications: notifications,
            settings: settings,
            appLockOn: () async => false,
          ),
          isFalse,
        );
        notifications.allowedAnswer = true;
        await settings.load();
        await settings.setEnabled(false);
        await postReplyUnconfirmed(
          payload: payload(),
          notifications: notifications,
          settings: settings,
          appLockOn: () async => false,
        );

        expect(notifications.shown, isEmpty);
      },
    );

    test('is not posted for a payload that is not a chat reply\'s', () async {
      await postReplyUnconfirmed(
        payload: payload(marker: false),
        notifications: notifications,
        settings: settings,
      );

      expect(notifications.shown, isEmpty);
    });
  });

  test('replyReport carries the ending, whether posted, nothing else', () {
    expect(
      replyReport(
        const InlineReplyResult(
          InlineReplyOutcome.unconfirmed,
          ending: ReplyEnding.unconfirmed,
          endingPosted: true,
        ),
      ),
      'unconfirmed:posted',
    );
    expect(
      replyReport(
        const InlineReplyResult(
          InlineReplyOutcome.unreachable,
          ending: ReplyEnding.notSent,
        ),
      ),
      'notSent:none',
    );
    expect(
      replyReport(const InlineReplyResult(InlineReplyOutcome.answered)),
      'answered:none',
    );
  });

  test('disposing the app takes its offer port away', () {
    final app = RequestAnswers(sender)..start();
    expect(IsolateNameServer.lookupPortByName(kRequestAnswersPort), isNotNull);

    app.dispose();

    expect(IsolateNameServer.lookupPortByName(kRequestAnswersPort), isNull);
  });
}

/// Answers `allowed` only after [delay], the first time.
class _SlowAllowed extends FakeNotificationService {
  _SlowAllowed(this.delay);
  final Duration delay;
  var _asked = false;

  @override
  Future<bool?> allowed() async {
    if (!_asked) {
      _asked = true;
      await Future<void>.delayed(delay);
    }
    return super.allowed();
  }
}

/// A transport whose close never answers.
class _HangingClose extends FakeChatTransport {
  var closeCalls = 0;

  @override
  Future<void> close() {
    closeCalls++;
    closed = true;
    return Completer<void>().future;
  }
}

class _Plugin implements FlutterLocalNotificationsPlugin {
  DidReceiveNotificationResponseCallback? onResponse;
  NotificationAppLaunchDetails? launchDetails;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    onResponse = onDidReceiveNotificationResponse;
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async => launchDetails;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
