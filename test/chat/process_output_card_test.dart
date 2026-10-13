import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/process_output_state.dart';
import 'package:hermes_app/src/chat/widgets/process_output_card.dart';

void main() {
  testWidgets(
    'compact process card expands inert output with omission and closed status',
    (tester) async {
      var expanded = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProcessOutputCard(
              output: const ProcessOutput(
                processId: 'worker',
                text: '\u001b[31mhttps://example.invalid',
                closed: true,
                omitted: true,
              ),
              omittedCards: true,
              onDetails: () => expanded++,
            ),
          ),
        ),
      );
      expect(find.textContaining('Closed'), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(
          SelectableText,
          '\u001b[31mhttps://example.invalid',
        ),
        findsOneWidget,
      );
      expect(find.text('Earlier output omitted.'), findsOneWidget);
      expect(find.text('Earlier process cards omitted.'), findsOneWidget);
      expect(expanded, 1);
      expect(find.textContaining('Success'), findsNothing);
    },
  );
  testWidgets(
    'empty and unavailable output remain explicit with disclosure semantics',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ProcessOutputCard(
                output: ProcessOutput(processId: 'worker', closed: true),
                initiallyOpen: true,
              ),
            ),
          ),
        );
        expect(find.text('No output received.'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.button == true,
          ),
          findsWidgets,
        );
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: ProcessOutputCard(output: null)),
          ),
        );
        expect(find.text('Process output unavailable'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'expanded long output leaves a usable adjacent transcript viewport',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ProcessOutputCard(
                  output: ProcessOutput(
                    processId: 'long',
                    text: List.filled(2000, 'Received output line').join('\n'),
                  ),
                  initiallyOpen: true,
                ),
                const Expanded(
                  child: SizedBox(key: ValueKey('transcript-area')),
                ),
                const SizedBox(height: 80, child: Text('Composer area')),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('transcript-area'))).height,
        greaterThan(200),
      );
      expect(
        tester.getSize(find.byType(ProcessOutputCard)).height,
        lessThanOrEqualTo(300),
      );
    },
  );
}
