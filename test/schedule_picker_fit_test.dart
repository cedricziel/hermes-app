import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/schedules/schedule_picker.dart';
import 'package:hermes_app/src/schedules/schedule_spec.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/shrink_to_fit_text.dart';

import 'support/screenshot_recorder.dart';

/// Every label of [spec]'s picker at [width] and [scale], in the real font:
/// never drawn below [ShrinkToFitText.defaultMinScale] of its size, and
/// whole up to text scale 1.3.
Future<void> _expectReadable(
  WidgetTester tester, {
  required TargetPlatform platform,
  required double width,
  required double scale,
  ScheduleSpec spec = const WeeklySpec({1, 3, 5}, 8, 30),
}) async {
  // Loads Roboto: the test font is far wider than any real one.
  await ScreenshotRecorder('picker-fit').start(tester, Size(width, 900));
  await tester.pumpWidget(
    MaterialApp(
      theme: withScreenshotFont(buildHermesLightTheme(platform: platform)),
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
      final drawn = tester.getRect(
        find.byElementPredicate((e) => e == element),
      );
      final drawnScale = drawn.width / paragraph.size.width;
      expect(
        drawnScale,
        greaterThanOrEqualTo(ShrinkToFitText.defaultMinScale - 0.001),
        reason: '"$label" is drawn at $drawnScale of its size',
      );
      if (scale <= 1.3) {
        expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      }
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
      testWidgets(
        '$platform at 320 and text scale $scale keeps every label readable',
        (tester) async {
          await _expectReadable(
            tester,
            platform: platform,
            width: 320,
            scale: scale,
          );
        },
      );
    }
  }
}
