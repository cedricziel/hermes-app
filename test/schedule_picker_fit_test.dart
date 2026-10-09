import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/schedules/schedule_picker.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

/// Every label of [spec]'s picker at [width] and [scale], each whole.
Future<void> _expectWhole(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double width,
  required double scale,
  ScheduleSpec spec = const WeeklySpec({1, 3, 5}, 8, 30),
}) async {
  tester.view
    ..physicalSize = Size(width, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: platform),
      home: MediaQuery.withClampedTextScaling(
        minScaleFactor: scale,
        maxScaleFactor: scale,
        child: Scaffold(
          body: ListView(
            children: [
              SchedulePicker(
                spec: spec,
                now: DateTime(2026, 9, 20, 12),
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);

  for (final label in [
    for (final mode in WhenMode.values) mode.label,
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ]) {
    for (final element in find.text(label).evaluate()) {
      final paragraph = element.renderObject! as RenderParagraph;
      final whole = paragraph.getMaxIntrinsicWidth(double.infinity);
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(whole - 0.5),
        reason: '"$label" is cut at ${paragraph.size.width} of $whole',
      );
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
    }
  }
}

void main() {
  for (final platform in [
    TargetPlatform.iOS,
    TargetPlatform.android,
    TargetPlatform.macOS,
  ]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('$platform at 320 and text scale $scale shows every label', (
        tester,
      ) async {
        await _expectWhole(
          tester,
          platform: platform,
          width: 320,
          scale: scale,
        );
      });
    }
  }
}
