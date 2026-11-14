import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/transcript_outcome_line.dart';

Widget _app(double scale) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: const Scaffold(
      body: SizedBox(
        width: 360,
        child: TranscriptOutcomeLine(text: 'Conversation compressed · 42 → 9'),
      ),
    ),
  ),
);

void main() {
  testWidgets('draws hairlines at normal size and drops them at large text', (
    tester,
  ) async {
    await tester.pumpWidget(_app(1));
    expect(find.byType(Divider), findsNWidgets(2));
    await tester.pumpWidget(_app(3));
    expect(find.byType(Divider), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a screen reader hears the sentence once', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(1));
    expect(
      find.bySemanticsLabel('Conversation compressed · 42 → 9'),
      findsOneWidget,
    );
    handle.dispose();
  });
}
