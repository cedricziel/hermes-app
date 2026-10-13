import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/chat/billing_verification_controller.dart';

import 'billing_fixtures.dart';

void main() {
  late ActivityRpcServer server;
  late BillingVerificationController controller;
  late BillingVerificationScope scope;
  late DateTime now;
  setUp(() {
    server = ActivityRpcServer();
    now = DateTime.utc(2030);
    scope = BillingVerificationScope(
      connection: Object(),
      attachment: Object(),
      sessionId: 'runtime-a',
      profile: 'private-profile',
    );
    controller = BillingVerificationController(
      now: () => now,
      openBrowser: (_) async => true,
      copyCode: (_) async {},
    );
    controller.bind(
      scope,
      request: (params) => server.client.request('billing.step_up', params),
    );
  });
  tearDown(() async {
    controller.dispose();
    await server.close();
  });
  test(
    'billing starts only explicitly and blocks duplicate pending requests',
    () async {
      expect(server.requests, isEmpty);
      final request = controller.start();
      await pumpEventQueue();
      expect(server.requests.single['method'], 'billing.step_up');
      expect(server.requests.single['params'], {
        'session_id': 'runtime-a',
        'profile': 'private-profile',
      });
      await controller.start();
      expect(server.requests, hasLength(1));
      controller.acceptVerification(
        billingVerificationFixture,
        attachment: scope.attachment,
      );
      await controller.openVerification();
      expect(controller.status, BillingVerificationStatus.pending);
      server.answer(0, {'ok': true, 'granted': true});
      await request;
      expect(controller.status, BillingVerificationStatus.granted);
      expect(controller.verification, isNull);
    },
  );
  test(
    'unsafe verification URL disables opening while preserving in-app code',
    () {
      controller.acceptVerification({
        ...billingVerificationFixture,
        'verification_url': 'https://user:token@unsafe.invalid',
      }, attachment: scope.attachment);
      expect(controller.verification!.userCode, 'PRIVATE-CODE');
      expect(controller.canOpenVerification, isFalse);
      expect(controller.status, BillingVerificationStatus.idle);
    },
  );
  test('method-not-found marks connection unavailable without speculative rediscovery', () async {
    final request = controller.start();
    await pumpEventQueue();
    server.refuse(0, -32601);
    await request;
    expect(controller.status, BillingVerificationStatus.unavailable);
    expect(controller.canStart, isFalse);
    final other = BillingVerificationScope(
      connection: scope.connection,
      attachment: Object(),
      sessionId: 'runtime-b',
    );
    controller.bind(
      other,
      request: (params) => server.client.request('billing.step_up', params),
    );
    await controller.start();
    expect(server.requests, hasLength(1));
  });
  test(
    'downscope/refusal never claims granted and respects retry_after',
    () async {
      final request = controller.start();
      await pumpEventQueue();
      server.answer(0, {
        'ok': false,
        'granted': false,
        'retry_after': 60,
        'message': 'Synthetic refusal',
      });
      await request;
      expect(controller.status, BillingVerificationStatus.refused);
      expect(controller.canStart, isFalse);
      now = now.add(const Duration(seconds: 60));
      expect(controller.canStart, isTrue);
    },
  );
  for (final result in [
    <String, Object?>{'ok': true},
    {'ok': true, 'granted': false},
    {'ok': false, 'granted': true},
  ]) {
    test('grant needs both confirmed booleans $result', () async {
      final request = controller.start();
      await pumpEventQueue();
      server.answer(0, result);
      await request;
      expect(controller.status, isNot(BillingVerificationStatus.granted));
    });
  }

  test('App Lock clears transient code and unlocking never restores it', () {
    controller.acceptVerification(
      billingVerificationFixture,
      attachment: scope.attachment,
    );
    controller.setLocked(true);
    expect(controller.verification, isNull);
    controller.acceptVerification(
      billingVerificationFixture,
      attachment: scope.attachment,
    );
    controller.setLocked(false);
    expect(controller.verification, isNull);
  });
  test(
    'scope replacement clears code and rejects late grant results',
    () async {
      final request = controller.start();
      await pumpEventQueue();
      controller.acceptVerification(
        billingVerificationFixture,
        attachment: scope.attachment,
      );
      controller.bind(null);
      server.answer(0, {'ok': true, 'granted': true});
      await request;
      expect(controller.verification, isNull);
      expect(controller.status, BillingVerificationStatus.idle);
      expect(controller.canStart, isFalse);
    },
  );
  test(
    'privacy logging records fixed outcomes and survives telemetry failure',
    () async {
      controller.dispose();
      final exported = <String>[];
      controller = BillingVerificationController(
        events: (name, [attributes = const {}]) {
          exported.add('$name $attributes');
          throw StateError('Telemetry unavailable');
        },
      );
      controller.bind(
        scope,
        request: (params) => server.client.request('billing.step_up', params),
      );
      final request = controller.start();
      await pumpEventQueue();
      controller.acceptVerification(
        billingVerificationFixture,
        attachment: scope.attachment,
      );
      server.answer(0, {'ok': true, 'granted': true});
      await request;
      expect(controller.status, BillingVerificationStatus.granted);
      final serialized = exported.join(' ');
      expect(serialized, isNot(contains('PRIVATE-CODE')));
      expect(serialized, isNot(contains('billing.invalid')));
      expect(serialized, isNot(contains('private-profile')));
      expect(serialized, isNot(contains('runtime-a')));
    },
  );
  test('an uncorrelated verification after completion never inherits an old grant claim', () async {
    final request = controller.start();
    await pumpEventQueue();
    server.answer(0, {'ok': true, 'granted': true});
    await request;
    controller.acceptVerification(
      billingVerificationFixture,
      attachment: scope.attachment,
    );
    expect(controller.verification, isNotNull);
    expect(controller.status, BillingVerificationStatus.idle);
  });
  test(
    'old verification callbacks cannot open or copy replacement details',
    () async {
      var opened = false, copied = false;
      controller.dispose();
      controller = BillingVerificationController(
        openBrowser: (_) async {
          opened = true;
          return true;
        },
        copyCode: (_) async {
          copied = true;
        },
      );
      controller.bind(scope);
      controller.acceptVerification(
        billingVerificationFixture,
        attachment: scope.attachment,
      );
      final old = controller.verification!;
      controller.acceptVerification({
        ...billingVerificationFixture,
        'user_code': 'NEW-CODE',
      }, attachment: scope.attachment);
      await controller.openVerification(expectedDetails: old);
      await controller.copyVerificationCode(expectedDetails: old);
      expect(opened, isFalse);
      expect(copied, isFalse);
    },
  );

  for (final lock in [false, true]) {
    test(
      'pending listener ${lock ? 'App Lock' : 'signout'} prevents billing dispatch',
      () async {
        var retired = false;
        controller.addListener(() {
          if (retired ||
              controller.status != BillingVerificationStatus.pending) {
            return;
          }
          retired = true;
          if (lock) {
            controller.setLocked(true);
          } else {
            controller.bind(null);
          }
        });

        final request = controller.start();
        await pumpEventQueue();
        if (server.requests.isNotEmpty) {
          server.answer(0, {'ok': true, 'granted': true});
        }
        await request;

        expect(retired, isTrue);
        expect(server.requests, isEmpty);
        if (lock) {
          controller.setLocked(false);
          expect(controller.canStart, isTrue);
        }
      },
    );
  }

  test('locking an already dispatched billing request keeps duplicate starts blocked', () async {
    final request = controller.start();
    await pumpEventQueue();
    expect(server.requests, hasLength(1));

    controller.setLocked(true);
    controller.setLocked(false);
    await controller.start();

    expect(controller.status, BillingVerificationStatus.pending);
    expect(controller.canStart, isFalse);
    expect(server.requests, hasLength(1));
    server.answer(0, {'ok': true, 'granted': true});
    await request;
    expect(controller.status, BillingVerificationStatus.granted);
  });

  test(
    'an old browser failure cannot annotate replacement verification details',
    () async {
      controller.dispose();
      final opened = Completer<bool>();
      controller = BillingVerificationController(
        openBrowser: (_) => opened.future,
      )..bind(scope);
      controller.acceptVerification(
        billingVerificationFixture,
        attachment: scope.attachment,
      );
      final old = controller.verification!;
      final opening = controller.openVerification(expectedDetails: old);
      controller.acceptVerification({
        ...billingVerificationFixture,
        'user_code': 'REPLACEMENT-CODE',
      }, attachment: scope.attachment);
      opened.complete(false);
      await opening;

      expect(controller.verification!.userCode, 'REPLACEMENT-CODE');
      expect(controller.message, isNull);
    },
  );
  test(
    'an old copy failure cannot annotate replacement verification details',
    () async {
      controller.dispose();
      final copied = Completer<void>();
      controller = BillingVerificationController(copyCode: (_) => copied.future)
        ..bind(scope);
      controller.acceptVerification(
        billingVerificationFixture,
        attachment: scope.attachment,
      );
      final copying = controller.copyVerificationCode();
      controller.acceptVerification({
        ...billingVerificationFixture,
        'user_code': 'REPLACEMENT-CODE',
      }, attachment: scope.attachment);
      copied.completeError(StateError('Copy unavailable'));
      await copying;
      expect(controller.verification!.userCode, 'REPLACEMENT-CODE');
      expect(controller.message, isNull);
    },
  );
  test('verify breadcrumb retirement cannot notify a disposed controller or send billing bytes', () async {
    late BillingVerificationController retired;
    final trail = _LockingTrail('verify', () => retired.dispose());
    retired = BillingVerificationController(breadcrumbs: Breadcrumbs.of(trail))
      ..bind(
        scope,
        request: (params) => server.client.request('billing.step_up', params),
      );
    await expectLater(retired.start(), completes);
    expect(server.requests, isEmpty);
  });
  test('unresolved profile authority disables billing mutation', () {
    controller.bind(
      BillingVerificationScope(
        connection: scope.connection,
        attachment: Object(),
        sessionId: scope.sessionId,
      ),
      request: (params) => server.client.request('billing.step_up', params),
    );
    expect(controller.canStart, isFalse);
  });
  test('details logging retirement cannot report a stale accepted code', () {
    controller.dispose();
    controller = BillingVerificationController(
      events: (name, [attributes = const {}]) {
        if (attributes['outcome'] == 'details') controller.bind(null);
      },
    )..bind(scope);
    expect(
      controller.acceptVerification(
        billingVerificationFixture,
        attachment: scope.attachment,
      ),
      isFalse,
    );
    expect(controller.verification, isNull);
  });
  for (final action in ['browser', 'copy_code']) {
    test(
      'lock during $action breadcrumb prevents sensitive side effect',
      () async {
        controller.dispose();
        var opened = false, copied = false;
        final trail = _LockingTrail(action, () => controller.setLocked(true));
        controller = BillingVerificationController(
          breadcrumbs: Breadcrumbs.of(trail),
          openBrowser: (_) async {
            opened = true;
            return true;
          },
          copyCode: (_) async {
            copied = true;
          },
        )..bind(scope);
        controller.acceptVerification(
          billingVerificationFixture,
          attachment: scope.attachment,
        );
        if (action == 'browser') {
          await controller.openVerification();
        } else {
          await controller.copyVerificationCode();
        }
        expect(opened, isFalse);
        expect(copied, isFalse);
        expect(controller.verification, isNull);
      },
    );
  }
}

class _LockingTrail extends BreadcrumbTrail {
  _LockingTrail(this.action, this.lock);
  final String action;
  final void Function() lock;
  @override
  void record(String name, [Map<String, Object> attributes = const {}]) {
    if (attributes['action'] == action) lock();
    super.record(name, attributes);
  }
}
