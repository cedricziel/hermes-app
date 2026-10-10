import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/local_notification_service.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/request_answers.dart';
import 'package:hermes_app/src/notifications/request_notifications.dart';

import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_chat_transport.dart';
import 'support/memory_token_store.dart';
import 'support/fake_notification_service.dart';

const _approval = NotificationAnswer(
  target: NotificationTarget(threadId: 's1', profile: 'work'),
  title: 'Cleanup',
  request: PendingRequest(requestId: 'r1', kind: PendingRequestKind.approval),
  answer: ApprovalChoiceAnswer('once'),
);

/// The payload of an approval notification for s1 in work, titled Cleanup.
String _payload() => notificationPayload(
  attentionFor(
    event: const ApprovalRequested(
      ApprovalRequest(
        requestId: 'r1',
        command: 'rm -rf build',
        description: '',
        choices: ['once', 'deny'],
      ),
    ),
    thread: ChatThread(id: 's1', title: 'Cleanup', updatedAt: DateTime(2026)),
    appFocused: false,
    selectedThreadId: null,
    enabled: true,
    profile: 'work',
  )!,
);

NotificationResponse _action(String actionId) => NotificationResponse(
  notificationResponseType: NotificationResponseType.selectedNotificationAction,
  payload: _payload(),
  actionId: actionId,
);

void main() {
  late FakeChatTransport transport;
  late FakeNotificationService notifications;
  late List<(String, Map<String, Object>)> logged;
  late RequestAnswerSender sender;
  var signedOut = false;

  setUp(() {
    transport = FakeChatTransport();
    notifications = FakeNotificationService();
    logged = [];
    signedOut = false;
    sender = RequestAnswerSender(
      transport: () => signedOut ? null : transport,
      notifications: notifications,
      events: () =>
          (name, [attributes = const {}]) => logged.add((name, attributes)),
    );
  });

  group('sending an answer', () {
    test('answers the request on a transport of its own', () async {
      final outcome = await sender.send(_approval);

      expect(outcome, AnswerOutcome.ok);
      final (id, answer, profile) = transport.openAnswers.single;
      expect(id, 'r1');
      expect((answer as ApprovalChoiceAnswer).choice, 'once');
      expect(profile, 'work');
      expect(transport.openAnswerThreads.single, 's1');
      expect(transport.closed, isTrue);
      expect(notifications.shown, isEmpty);
    });

    test('says so when the request is gone', () async {
      transport.accepts = false;

      final outcome = await sender.send(_approval);

      expect(outcome, AnswerOutcome.expired);
      final shown = notifications.shown.single;
      expect(shown.body, kAnswerFailedBody);
      expect(shown.title, 'Cleanup');
      expect(shown.threadId, 's1');
      expect(shown.profile, 'work');
      expect(shown.category, isNull);
    });

    test('says so when the call fails', () async {
      transport.answerError = Exception('socket closed');

      expect(await sender.send(_approval), AnswerOutcome.failed);
      expect(notifications.shown.single.body, kAnswerFailedBody);
    });

    test('says so when nobody is signed in', () async {
      signedOut = true;

      expect(await sender.send(_approval), AnswerOutcome.signedOut);
      expect(notifications.shown.single.body, kAnswerFailedBody);
    });

    test('logs the kind, outcome and route only', () async {
      transport.accepts = false;

      await sender.send(_approval, route: 'background');

      final (name, attributes) = logged.single;
      expect(name, 'notification.answer');
      expect(attributes, {
        'kind': 'approval',
        'outcome': 'expired',
        'route': 'background',
      });
    });
  });

  test('gives up in time to post the follow-up before the deadline', () async {
    transport.openAnswerGate = Completer<void>();
    sender = RequestAnswerSender(
      transport: () => transport,
      notifications: notifications,
      followUpMargin: const Duration(milliseconds: 10),
    );

    final outcome = await sender.send(
      _approval,
      deadline: DateTime.now().add(const Duration(milliseconds: 60)),
    );

    expect(outcome, AnswerOutcome.failed);
    expect(notifications.shown.single.body, kAnswerFailedBody);
  });

  group('routing a background action', () {
    test('hands it to the running app, which sends it', () async {
      final app = RequestAnswers(sender)..start();
      addTearDown(app.dispose);
      var alone = 0;

      final outcome = await routeAnswer(
        _action(kDenyAction),
        alone: (_, _) async {
          alone++;
          return AnswerOutcome.ok;
        },
      );

      expect(outcome, AnswerOutcome.ok);
      expect(alone, 0);
      final (_, answer, _) = transport.openAnswers.single;
      expect((answer as ApprovalChoiceAnswer).choice, 'deny');
    });

    test("waits a moment for the app's port to appear", () async {
      final app = RequestAnswers(sender)..start();
      addTearDown(app.dispose);
      var lookups = 0;

      final outcome = await routeAnswer(
        _action(kAllowOnceAction),
        lookup: () => ++lookups < 3
            ? null
            : IsolateNameServer.lookupPortByName(kRequestAnswersPort),
        alone: (_, _) async => AnswerOutcome.failed,
        pollEvery: const Duration(milliseconds: 5),
      );

      expect(outcome, AnswerOutcome.ok);
      expect(transport.openAnswers, hasLength(1));
    });

    test('answers alone when no app is running', () async {
      NotificationAnswer? sent;

      final outcome = await routeAnswer(
        _action(kAllowOnceAction),
        lookup: () => null,
        alone: (answer, _) async {
          sent = answer;
          return AnswerOutcome.expired;
        },
        pollFor: const Duration(milliseconds: 20),
        pollEvery: const Duration(milliseconds: 5),
      );

      expect(outcome, AnswerOutcome.expired);
      expect(sent!.request.requestId, 'r1');
      expect(sent!.target.profile, 'work');
    });

    test('answers alone when a port is left but nobody takes it', () async {
      final stale = ReceivePort();
      addTearDown(stale.close);
      var alone = 0;

      await routeAnswer(
        _action(kAllowOnceAction),
        lookup: () => stale.sendPort,
        alone: (_, _) async {
          alone++;
          return AnswerOutcome.ok;
        },
        takeTimeout: const Duration(milliseconds: 20),
      );

      expect(alone, 1);
    });

    test('an offer that comes too late is never confirmed', () async {
      final app = ReceivePort();
      addTearDown(app.close);
      final confirmed = <Object?>[];
      app.listen((message) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        final confirm = ReceivePort();
        confirm.listen(confirmed.add);
        ((message as List).last as SendPort).send(['offer', confirm.sendPort]);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        confirm.close();
      });
      var alone = 0;

      await routeAnswer(
        _action(kAllowOnceAction),
        lookup: () => app.sendPort,
        alone: (_, _) async {
          alone++;
          return AnswerOutcome.ok;
        },
        takeTimeout: const Duration(milliseconds: 10),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(alone, 1);
      expect(confirmed, isEmpty);
    });

    test('leaves the follow-up to the app once it took the answer', () async {
      final app = ReceivePort();
      addTearDown(app.close);
      app.listen((message) {
        final confirm = ReceivePort();
        addTearDown(confirm.close);
        ((message as List).last as SendPort).send(['offer', confirm.sendPort]);
      });
      var alone = 0;

      final outcome = await routeAnswer(
        _action(kAllowOnceAction),
        lookup: () => app.sendPort,
        alone: (_, _) async {
          alone++;
          return AnswerOutcome.ok;
        },
        deadline: DateTime.now().add(const Duration(milliseconds: 20)),
        reportGrace: Duration.zero,
      );

      expect(outcome, AnswerOutcome.failed);
      expect(alone, 0);
    });

    test('does nothing for a button that answers nothing', () async {
      var alone = 0;

      await routeAnswer(
        _action(kOpenAction),
        lookup: () => null,
        alone: (_, _) async {
          alone++;
          return AnswerOutcome.ok;
        },
      );

      expect(alone, 0);
    });
  });

  group('answering alone', () {
    setUp(
      () => SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty(),
    );

    test(
      'two answers at once share one sign-in and go one at a time',
      () async {
        var signIns = 0;
        final lone = LoneAnswerer(
          createAuth: () {
            signIns++;
            return AuthController(tokenStore: MemoryTokenStore());
          },
          transportFor: (_) => transport,
          notifications: notifications,
        );
        final gate = transport.openAnswerGate = Completer<void>();
        final deadline = DateTime.now().add(const Duration(seconds: 5));

        final first = lone.answer(_approval, deadline);
        final second = lone.answer(_approval, deadline);
        await pumpEventQueue();
        expect(transport.openAnswers, hasLength(1));
        gate.complete();

        expect(await first, AnswerOutcome.ok);
        expect(await second, AnswerOutcome.ok);
        expect(transport.openAnswers, hasLength(2));
        expect(signIns, 1);
      },
    );
  });

  group('the running app', () {
    test('sends what its notification service reports', () async {
      final answers = RequestAnswers(sender, service: notifications)..start();
      addTearDown(answers.dispose);

      notifications.answer(_approval);
      await pumpEventQueue();

      expect(transport.openAnswers.single.$1, 'r1');
    });
  });
}
