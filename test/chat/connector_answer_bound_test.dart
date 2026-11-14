import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/connector_operation_controller.dart';
import 'package:hermes_app/src/chat/connector_operation_state.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

import 'connector_fixtures.dart';

/// The 10 second bound on a connection response, on a fake clock: the
/// responder is a [Completer] the test settles when it wants the transport to
/// answer.
void main() {
  late List<Map<String, Object?>> sent;
  late List<Completer<Map<String, Object?>>> replies;
  late List<String> outcomes;
  late Object attachment;
  late ConnectorOperationController controller;
  late ConnectorOperationSnapshot operation;

  void inFakeAsync(void Function(FakeAsync async) body) => fakeAsync((async) {
    sent = [];
    replies = [];
    outcomes = [];
    attachment = Object();
    controller = ConnectorOperationController(
      now: () => DateTime.utc(2030),
      openBrowser: (_) async => true,
      events: (name, [attributes = const {}]) {
        if (name == 'gateway.visibility_outcome') {
          outcomes.add(attributes['outcome']! as String);
        }
      },
    );
    controller.bind(
      attachment,
      profile: 'private-profile',
      respond: (params) {
        sent.add(params);
        final reply = Completer<Map<String, Object?>>();
        replies.add(reply);
        return reply.future;
      },
    );
    controller.accept(
      ConnectorOperationSnapshot.fromUpdate(connectionUpdateFixture)!,
      attachment: attachment,
    );
    outcomes.clear();
    operation = controller.operations.single;
    try {
      body(async);
    } finally {
      controller.dispose();
    }
  });

  void continueOn() => unawaited(
    controller.continueOperation(operation, attachment: attachment),
  );

  test('a response with no result after 10 seconds is unconfirmed and '
      'the actions come back', () {
    inFakeAsync((async) {
      continueOn();
      async.flushMicrotasks();
      expect(controller.answerFor(operation.key), ConnectorAnswer.sending);
      expect(controller.canRespond(operation.key), isFalse);
      expect(controller.offersRespond(operation.key), isTrue);

      async.elapse(const Duration(seconds: 9, milliseconds: 900));
      expect(controller.answerFor(operation.key), ConnectorAnswer.sending);

      async.elapse(const Duration(milliseconds: 200));
      expect(controller.answerFor(operation.key), ConnectorAnswer.unconfirmed);
      expect(controller.pendingFor(operation.key), isFalse);
      expect(controller.canRespond(operation.key), isTrue);
      expect(
        controller.canSkip(operation.key, operation.targets.single.name),
        isTrue,
      );
      expect(outcomes, ['unconfirmed']);
      expect(sent, hasLength(1), reason: 'nothing is resent');
    });
  });

  test('a thrown error is unconfirmed too', () {
    inFakeAsync((async) {
      continueOn();
      async.flushMicrotasks();
      replies.single.completeError(const GatewayConnectionClosed());
      async.flushMicrotasks();
      expect(controller.answerFor(operation.key), ConnectorAnswer.unconfirmed);
      expect(controller.canRespond(operation.key), isTrue);
      expect(outcomes, ['unconfirmed']);
      expect(sent, hasLength(1));
    });
  });

  test('a status other than ok is a refusal, not an unconfirmed answer', () {
    inFakeAsync((async) {
      continueOn();
      async.flushMicrotasks();
      replies.single.complete({'status': 'denied', 'settled': false});
      async.flushMicrotasks();
      expect(controller.answerFor(operation.key), ConnectorAnswer.refused);
      expect(
        controller.errorFor(operation.key),
        'The server refused your answer.',
      );
      expect(controller.canRespond(operation.key), isTrue);
      expect(outcomes, ['refused']);
    });
  });

  test('method-not-found keeps responses unavailable', () {
    inFakeAsync((async) {
      continueOn();
      async.flushMicrotasks();
      replies.single.completeError(
        const GatewayRpcException(kGatewayMethodNotFound, 'Method not found'),
      );
      async.flushMicrotasks();
      expect(controller.answerFor(operation.key), ConnectorAnswer.idle);
      expect(controller.canRespond(operation.key), isFalse);
      expect(controller.offersRespond(operation.key), isFalse);
      expect(
        controller.errorFor(operation.key),
        'Connection responses are unavailable on this server.',
      );
      expect(outcomes, ['unsupported']);
    });
  });

  test(
    'the transport error 30 seconds in changes nothing and logs nothing',
    () {
      inFakeAsync((async) {
        continueOn();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));
        expect(
          controller.answerFor(operation.key),
          ConnectorAnswer.unconfirmed,
        );
        final error = controller.errorFor(operation.key);
        var notified = 0;
        controller.addListener(() => notified++);

        async.elapse(const Duration(seconds: 20));
        replies.single.completeError(TimeoutException('requestTimeout'));
        async.flushMicrotasks();

        expect(
          controller.answerFor(operation.key),
          ConnectorAnswer.unconfirmed,
        );
        expect(controller.errorFor(operation.key), error);
        expect(outcomes, ['unconfirmed']);
        expect(sent, hasLength(1));
        expect(notified, 0);
      });
    },
  );

  test('a settlement after the report still settles the operation', () {
    inFakeAsync((async) {
      continueOn();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      controller.accept(
        ConnectorOperationSnapshot.fromUpdate({
          ...connectionUpdateFixture,
          'seq': 9,
          'settled': true,
        })!,
        attachment: attachment,
      );
      expect(controller.operations.single.settled, isTrue);
      expect(controller.canRespond(controller.operations.single.key), isFalse);
    });
  });

  test('a late ok result that settled the operation settles it without a '
      'second outcome', () {
    inFakeAsync((async) {
      continueOn();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      replies.single.complete({'status': 'ok', 'settled': true});
      async.flushMicrotasks();
      expect(controller.operations.single.settled, isTrue);
      expect(controller.errorFor(operation.key), isNull);
      expect(controller.answerFor(operation.key), ConnectorAnswer.idle);
      expect(outcomes, ['unconfirmed']);
    });
  });

  test('a late ok that settled nothing clears the unconfirmed line', () {
    inFakeAsync((async) {
      continueOn();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      expect(controller.answerFor(operation.key), ConnectorAnswer.unconfirmed);
      replies.single.complete({'status': 'ok', 'settled': false});
      async.flushMicrotasks();
      expect(controller.answerFor(operation.key), ConnectorAnswer.idle);
      expect(controller.errorFor(operation.key), isNull);
      expect(outcomes, ['unconfirmed']);
    });
  });

  test('a settlement from the snapshot clears the line too', () {
    inFakeAsync((async) {
      continueOn();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      controller.accept(
        ConnectorOperationSnapshot.fromUpdate({
          ...connectionUpdateFixture,
          'seq': 9,
          'settled': true,
        })!,
        attachment: attachment,
      );
      expect(controller.errorFor(operation.key), isNull);
      expect(controller.answerFor(operation.key), ConnectorAnswer.idle);
    });
  });

  test('a second answer is the user\'s own and a late error of the first '
      'does not end it', () {
    inFakeAsync((async) {
      continueOn();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      expect(controller.answerFor(operation.key), ConnectorAnswer.unconfirmed);

      continueOn();
      async.flushMicrotasks();
      expect(sent, hasLength(2));
      expect(controller.answerFor(operation.key), ConnectorAnswer.sending);

      replies.first.completeError(TimeoutException('requestTimeout'));
      async.flushMicrotasks();
      expect(controller.answerFor(operation.key), ConnectorAnswer.sending);

      replies.last.complete({'status': 'ok', 'settled': false});
      async.flushMicrotasks();
      expect(controller.answerFor(operation.key), ConnectorAnswer.idle);
      expect(outcomes, ['unconfirmed', 'responded']);
    });
  });
}
