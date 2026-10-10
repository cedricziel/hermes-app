import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/shrink_to_fit_text.dart';

// The test font draws every character 10 wide at size 10.
const _style = TextStyle(fontSize: 10);

Future<void> _pump(WidgetTester tester, double width) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: width,
        height: 30,
        child: const ShrinkToFitText('Weekly', style: _style),
      ),
    ),
  ),
);

RenderParagraph _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(find.text('Weekly'));

/// How wide the label is drawn on screen.
double _drawnWidth(WidgetTester tester) {
  final rect = tester.getRect(find.text('Weekly'));
  return rect.width;
}

void main() {
  testWidgets('a label that fits is drawn whole at its size', (tester) async {
    await _pump(tester, 100);

    expect(_drawnWidth(tester), 60);
    expect(_paragraph(tester).didExceedMaxLines, isFalse);
  });

  testWidgets('a label a little too wide shrinks to fit', (tester) async {
    await _pump(tester, 54);

    expect(_drawnWidth(tester), closeTo(54, 0.01));
    expect(_paragraph(tester).didExceedMaxLines, isFalse);
  });

  testWidgets('a label far too wide stops shrinking and is cut', (
    tester,
  ) async {
    await _pump(tester, 30);

    final drawnScale = _drawnWidth(tester) / _paragraph(tester).size.width;
    expect(drawnScale, ShrinkToFitText.defaultMinScale);
    expect(_paragraph(tester).didExceedMaxLines, isTrue);
  });

  testWidgets('the label sits centred in its space', (tester) async {
    await _pump(tester, 100);

    expect(
      tester.getCenter(find.text('Weekly')),
      tester.getCenter(find.byType(ShrinkToFitText)),
    );
  });

  testWidgets('a tap on a shrunk label reaches it', (tester) async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
    await _pump(tester, 54);

    await tester.tap(find.text('Weekly'));
  });
}
