import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/connector_operation_state.dart';
import 'package:hermes_app/src/chat/widgets/connector_operation_card.dart';

import 'connector_fixtures.dart';

void main() {
  testWidgets(
    'connector details show reported state and browser destination before explicit action',
    (tester) async {
      var opened = false;
      final operation = ConnectorOperationSnapshot.fromUpdate(
        connectionUpdateFixture,
      )!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectorOperationCard(
              operation: operation,
              initiallyOpen: true,
              onOpen: (_) => opened = true,
              canOpen: (_) => true,
              canSkip: (_) => true,
              onSkip: (_) {},
              onContinue: () {},
            ),
          ),
        ),
      );
      expect(find.text('synthetic-connector'), findsOneWidget);
      expect(find.textContaining('initiated'), findsOneWidget);
      expect(find.textContaining('connect.invalid'), findsOneWidget);
      expect(opened, isFalse);
      await tester.tap(find.text('Open connection'));
      expect(opened, isTrue);
    },
  );
  testWidgets(
    'compact empty operation exposes an accessible disclosure on a narrow layout',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final operation = ConnectorOperationSnapshot.fromUpdate({
        ...connectionUpdateFixture,
        'targets': [],
      })!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ConnectorOperationCard(operation: operation)),
        ),
      );
      expect(find.text('No connection targets reported.'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.expanded == false,
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(find.text('No connection targets reported.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets(
    'deadline fallback and unsupported targets show no invented settlement',
    (tester) async {
      final operation = ConnectorOperationSnapshot.fromUpdate({
        ...connectionUpdateFixture,
        'targets': [
          {
            'name': 'future target',
            'kind': 'future',
            'action': 'install',
            'state': 'pending',
          },
        ],
      })!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectorOperationCard(
              operation: operation,
              initiallyOpen: true,
              awaitingFinalStatus: true,
            ),
          ),
        ),
      );
      expect(find.text('Awaiting final status'), findsOneWidget);
      expect(
        find.text('This target cannot be completed in this app.'),
        findsOneWidget,
      );
      expect(find.text('Open connection'), findsNothing);
      expect(find.textContaining('connected successfully'), findsNothing);
    },
  );
  testWidgets(
    'read-only operation details expose no browser destination or response controls',
    (tester) async {
      final operation = ConnectorOperationSnapshot.fromUpdate(
        connectionUpdateFixture,
      )!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectorOperationCard(
              operation: operation,
              readOnly: true,
              initiallyOpen: true,
              onOpen: (_) {},
              onSkip: (_) {},
              onContinue: () {},
              canOpen: (_) => true,
              canSkip: (_) => true,
            ),
          ),
        ),
      );
      expect(find.text('synthetic-connector'), findsOneWidget);
      expect(find.textContaining('connect.invalid'), findsNothing);
      expect(find.text('Open connection'), findsNothing);
      expect(find.text('Skip'), findsNothing);
      expect(find.text('Continue'), findsNothing);
    },
  );
}
