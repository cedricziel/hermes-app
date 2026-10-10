import 'dart:isolate';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/notifications/attention_policy.dart';
import 'package:hermes_app/src/notifications/local_notification_service.dart';
import 'package:hermes_app/src/notifications/notification_service.dart';
import 'package:hermes_app/src/notifications/request_answers.dart';
import 'package:hermes_app/src/notifications/request_notifications.dart';

import 'support/fake_chat_transport.dart';
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

  group('routing a background action', () {
    test('hands it to the running app and reports its outcome', () async {
      final app = ReceivePort();
      addTearDown(app.close);
      app.listen((message) {
        final [payload, actionId, input, SendPort reply] = message as List;
        final answer = answerFromAction(
          payload as String?,
          actionId as String?,
          input as String?,
        );
        expect((answer!.answer as ApprovalChoiceAnswer).choice, 'deny');
        reply.send('ok');
      });
      var alone = 0;

      final outcome = await routeAnswer(
        _action(kDenyAction),
        lookup: () => app.sendPort,
        alone: (_) async {
          alone++;
          return AnswerOutcome.ok;
        },
        unanswered: (_) async {},
      );

      expect(outcome, AnswerOutcome.ok);
      expect(alone, 0);
    });

    test('answers alone when the app is not running', () async {
      NotificationAnswer? sent;

      final outcome = await routeAnswer(
        _action(kAllowOnceAction),
        lookup: () => null,
        alone: (answer) async {
          sent = answer;
          return AnswerOutcome.expired;
        },
        unanswered: (_) async {},
      );

      expect(outcome, AnswerOutcome.expired);
      expect(sent!.request.requestId, 'r1');
      expect(sent!.target.profile, 'work');
    });

    test('tells the user when the app never says how it went', () async {
      final app = ReceivePort();
      addTearDown(app.close);
      NotificationAnswer? unanswered;

      final outcome = await routeAnswer(
        _action(kAllowOnceAction),
        lookup: () => app.sendPort,
        alone: (_) async => AnswerOutcome.ok,
        unanswered: (answer) async => unanswered = answer,
        timeout: const Duration(milliseconds: 20),
      );

      expect(outcome, AnswerOutcome.failed);
      expect(unanswered!.title, 'Cleanup');
    });

    test('does nothing for a button that answers nothing', () async {
      var alone = 0;

      await routeAnswer(
        _action(kOpenAction),
        lookup: () => null,
        alone: (_) async {
          alone++;
          return AnswerOutcome.ok;
        },
        unanswered: (_) async {},
      );

      expect(alone, 0);
    });
  });

  group('the running app', () {
    test('sends what its notification service reports', () async {
      final answers = RequestAnswers(sender, service: notifications)..start();
      addTearDown(answers.dispose);

      notifications.answer(_approval);
      await pumpEventQueue();

      expect(transport.openAnswers.single.$1, 'r1');
    });

    test('answers what the background isolate hands it', () async {
      final answers = RequestAnswers(sender)..start();
      addTearDown(answers.dispose);

      final outcome = await routeAnswer(
        _action(kAllowOnceAction),
        alone: (_) async => AnswerOutcome.failed,
        unanswered: (_) async {},
      );

      expect(outcome, AnswerOutcome.ok);
      expect(transport.openAnswers.single.$1, 'r1');
    });
  });
}
