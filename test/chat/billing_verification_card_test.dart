import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/billing_verification_controller.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/widgets/billing_verification_card.dart';

import 'billing_fixtures.dart';

void main() {
  testWidgets(
    'code stays in expandable details and browser destination requires explicit action',
    (tester) async {
      final controller = BillingVerificationController(
        openBrowser: (_) async => true,
        copyCode: (_) async {},
      );
      addTearDown(controller.dispose);
      final attachment = Object();
      controller.bind(
        BillingVerificationScope(
          connection: Object(),
          attachment: attachment,
          sessionId: 'runtime-a',
        ),
      );
      controller.acceptVerification(
        billingVerificationFixture,
        attachment: attachment,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BillingVerificationCard(controller: controller)),
        ),
      );
      expect(find.text('PRIVATE-CODE'), findsNothing);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SelectableText, 'PRIVATE-CODE'),
        findsOneWidget,
      );
      expect(find.textContaining('billing.invalid'), findsWidgets);
      expect(find.text('Copy code'), findsOneWidget);
      expect(find.text('Open verification'), findsOneWidget);
      expect(controller.status, BillingVerificationStatus.idle);
      controller.setLocked(true);
      await tester.pump();
      expect(find.text('PRIVATE-CODE'), findsNothing);
    },
  );
  testWidgets(
    'invalid browser URL leaves a private code and disabled open action on a narrow layout',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final controller = BillingVerificationController();
      addTearDown(controller.dispose);
      final attachment = Object();
      controller.bind(
        BillingVerificationScope(
          connection: Object(),
          attachment: attachment,
          sessionId: 'runtime-a',
        ),
      );
      controller.acceptVerification({
        ...billingVerificationFixture,
        'verification_url': 'https://user:private@billing.invalid',
      }, attachment: attachment);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BillingVerificationCard(
                controller: controller,
                initiallyOpen: true,
              ),
            ),
          ),
        ),
      );
      expect(find.text('PRIVATE-CODE'), findsOneWidget);
      expect(find.text('Browser opening unavailable.'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Open verification'),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('user:private'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.expanded == true,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets(
    'unavailable billing action is explicit and never starts by rendering',
    (tester) async {
      final controller = BillingVerificationController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BillingVerificationCard(controller: controller)),
        ),
      );
      expect(find.text('Verify billing access'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Verify billing access'),
            )
            .onPressed,
        isNull,
      );
      expect(controller.status, BillingVerificationStatus.idle);
    },
  );
  testWidgets('billing a server does not offer draws nothing', (tester) async {
    final controller = BillingVerificationController();
    addTearDown(controller.dispose);
    controller.bind(
      BillingVerificationScope(
        connection: Object(),
        attachment: Object(),
        sessionId: 'runtime-a',
        profile: 'private-profile',
      ),
      request: (_) async =>
          throw const GatewayRpcException(-32601, 'Unsupported'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: BillingVerificationCard(controller: controller)),
      ),
    );
    expect(find.text('Verify billing access'), findsOneWidget);
    await controller.start();
    await tester.pump();
    expect(controller.supported, isFalse);
    expect(find.byType(Text), findsNothing);
  });
}
