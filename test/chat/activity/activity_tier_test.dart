import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/activity/activity_tier.dart';
import 'package:hermes_app/src/chat/billing_verification_controller.dart';
import 'package:hermes_app/src/chat/chat_session_state.dart';
import 'package:hermes_app/src/chat/connector_operation_controller.dart';
import 'package:hermes_app/src/chat/connector_operation_state.dart';

import '../billing_fixtures.dart' show billingVerificationFixture;
import '../connector_fixtures.dart';

void main() {
  test('fixed kinds have one tier each', () {
    expect(
      {for (final kind in ActivityKind.values) kind: kind.tier},
      {
        ActivityKind.status: ActivityTier.working,
        ActivityKind.control: ActivityTier.working,
        ActivityKind.plan: ActivityTier.working,
        ActivityKind.process: ActivityTier.working,
        ActivityKind.moa: ActivityTier.working,
        ActivityKind.resume: ActivityTier.working,
        ActivityKind.usage: ActivityTier.reference,
        ActivityKind.sideResult: ActivityTier.reference,
        ActivityKind.notice: ActivityTier.reference,
        ActivityKind.acknowledgement: ActivityTier.reference,
      },
    );
  });

  group('connector operations', () {
    late ActivityRpcServer server;
    late ConnectorOperationController controller;
    late Object attachment;
    setUp(() {
      server = ActivityRpcServer();
      attachment = Object();
      controller = ConnectorOperationController(
        now: () => DateTime.utc(2030),
        openBrowser: (_) async => true,
      );
      controller.bind(
        attachment,
        profile: 'private-profile',
        respond: (params) =>
            server.client.request('connection.respond', params),
      );
    });
    tearDown(() async {
      controller.dispose();
      await server.close();
    });

    test(
      'need the user while actionable and become reference once settled',
      () {
        controller.accept(
          ConnectorOperationSnapshot.fromUpdate(connectionUpdateFixture)!,
          attachment: attachment,
        );
        expect(
          connectorTier(controller.operations.single, controller),
          ActivityTier.needsYou,
        );
        controller.accept(
          ConnectorOperationSnapshot.fromUpdate({
            ...connectionUpdateFixture,
            'seq': 5,
            'settled': true,
          })!,
          attachment: attachment,
        );
        expect(
          connectorTier(controller.operations.single, controller),
          ActivityTier.reference,
        );
      },
    );

    test('connection-wide activity is always reference', () {
      controller.accept(
        ConnectorOperationSnapshot.fromUpdate(connectionUpdateFixture)!,
        attachment: attachment,
      );
      expect(
        connectorTier(
          controller.operations.single,
          controller,
          connectionWide: true,
        ),
        ActivityTier.reference,
      );
    });
  });

  test('billing needs the user only while it holds verification details', () {
    final controller = BillingVerificationController();
    addTearDown(controller.dispose);
    final attachment = Object();
    controller.bind(
      BillingVerificationScope(
        connection: Object(),
        attachment: attachment,
        sessionId: 'runtime-a',
        profile: 'private-profile',
      ),
    );
    expect(billingTier(controller), ActivityTier.reference);
    controller.acceptVerification(
      billingVerificationFixture,
      attachment: attachment,
    );
    expect(billingTier(controller), ActivityTier.needsYou);
  });

  test('a reclaimed session needs the user, other session state works', () {
    final state = ChatSessionState()..waits['status'] = 'Recalled 5 memories';
    expect(sessionStateTier(state), ActivityTier.working);
    state.reclaimedReason = 'Opened elsewhere';
    expect(sessionStateTier(state), ActivityTier.needsYou);
  });
}
