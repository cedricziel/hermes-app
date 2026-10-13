import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/moa_progress_state.dart';
import 'package:hermes_app/src/chat/widgets/moa_progress_card.dart';

void main() {
  testWidgets(
    'advisor progress expands references without turning them into main answer',
    (tester) async {
      var expanded = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MoaProgressCard(
              progress: MoaProgress(
                turn: 'turn',
                phase: 'Aggregating',
                aggregator: 'Reported model',
                done: 2,
                total: 3,
                references: const [
                  MoaReference(
                    eventIdentity: 'one',
                    label: 'Advisor',
                    text: 'Reference text',
                  ),
                ],
              ),
              onDetails: () => expanded++,
            ),
          ),
        ),
      );
      expect(find.textContaining('Reported model'), findsOneWidget);
      expect(find.textContaining('2 / 3'), findsOneWidget);
      expect(find.text('Reference text'), findsNothing);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SelectableText, 'Reference text'),
        findsOneWidget,
      );
      expect(expanded, 1);
    },
  );
  testWidgets(
    'completed missing references have no live indicator and explain unavailable details',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: MoaProgressCard(
                progress: MoaProgress(
                  turn: 'turn',
                  live: false,
                  referencesAvailable: false,
                  references: [
                    MoaReference(
                      eventIdentity: 'old',
                      label: 'Advisor',
                      text: 'Retired reference',
                    ),
                  ],
                ),
                initiallyOpen: true,
              ),
            ),
          ),
        );
        expect(find.text('Reference details unavailable.'), findsOneWidget);
        expect(find.text('Retired reference'), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.button == true,
          ),
          findsWidgets,
        );
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets('reported progress fits a narrow reduced-motion view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: MoaProgressCard(
              progress: MoaProgress(
                turn: 'turn',
                phase: 'A lengthy reported phase',
                aggregator: 'A lengthy reported aggregator',
                done: 1,
                total: 3,
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
