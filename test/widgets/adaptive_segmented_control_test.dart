import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/adaptive_segmented_control.dart';
import 'package:hermes_app/src/widgets/adaptive_tab_bar.dart';

const _segments = {false: 'Text', true: 'Tree'};
final _control = find.byType(AdaptiveSegmentedControl<bool>);

Future<List<bool>> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
  bool dark = false,
  bool tree = false,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
}) async {
  final picks = <bool>[];
  final base = dark ? buildHermesDarkTheme() : buildHermesLightTheme();
  await tester.pumpWidget(
    MaterialApp(
      theme: base.copyWith(platform: platform),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: Directionality(textDirection: direction, child: child!),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: AdaptiveSegmentedControl<bool>(
            value: tree,
            segments: _segments,
            semanticLabel: 'Show result as',
            onChanged: picks.add,
          ),
        ),
      ),
    ),
  );
  return picks;
}

void main() {
  const heights = {
    TargetPlatform.iOS: 44.0,
    TargetPlatform.macOS: 28.0,
    TargetPlatform.android: 48.0,
    TargetPlatform.windows: 48.0,
    TargetPlatform.linux: 48.0,
  };
  const looks = {
    TargetPlatform.iOS: 28.0,
    TargetPlatform.macOS: 22.0,
    TargetPlatform.android: 28.0,
    TargetPlatform.windows: 28.0,
    TargetPlatform.linux: 28.0,
  };

  for (final platform in heights.keys) {
    group('on $platform', () {
      testWidgets('its tap area is ${heights[platform]} high', (tester) async {
        await _pump(tester, platform: platform);
        expect(tester.getSize(_control).height, heights[platform]);
      });

      testWidgets('it looks ${looks[platform]} high', (tester) async {
        await _pump(tester, platform: platform);
        final drawn = switch (platform) {
          TargetPlatform.iOS => find.byType(
            CupertinoSlidingSegmentedControl<bool>,
          ),
          TargetPlatform.android => find.byType(SegmentedButton<bool>),
          _ => find.byType(PillSegmentedControl<bool>),
        };
        expect(tester.getSize(drawn).height, looks[platform]);
      });

      testWidgets('a tap above or below a segment picks it', (tester) async {
        final picks = await _pump(tester, platform: platform);
        final box = tester.getRect(_control);
        final tree = tester.getRect(find.text('Tree')).center.dx;
        final text = tester.getRect(find.text('Text')).center.dx;
        await tester.tapAt(Offset(tree, box.top + 0.5));
        await tester.tapAt(Offset(tree, box.bottom - 0.5));
        await tester.tapAt(Offset(text, box.top + 0.5));
        expect(picks, [true, true, false]);
      });

      testWidgets('a tap on a segment picks it once', (tester) async {
        final picks = await _pump(tester, platform: platform);
        await tester.tap(find.text('Tree'));
        await tester.pumpAndSettle();
        expect(picks, [true]);
      });

      testWidgets('it holds at 2x text', (tester) async {
        await _pump(tester, platform: platform, textScale: 2);
        expect(tester.takeException(), isNull);
        expect(tester.getSize(_control).height, heights[platform]);
      });
    });
  }

  testWidgets('the group is named for a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, platform: TargetPlatform.iOS, tree: true);
    expect(find.bySemanticsLabel('Show result as'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Android shows a check in the selected segment only', (
    tester,
  ) async {
    await _pump(tester, platform: TargetPlatform.android, tree: true);
    expect(find.byIcon(Icons.check), findsOneWidget);
    final check = tester.getCenter(find.byIcon(Icons.check));
    expect(
      (check - tester.getCenter(find.text('Tree'))).distance,
      lessThan((check - tester.getCenter(find.text('Text'))).distance),
    );
  });

  testWidgets('the selected label on Apple is semibold, the other is not', (
    tester,
  ) async {
    await _pump(tester, platform: TargetPlatform.iOS, tree: true);
    FontWeight? weight(String t) =>
        tester.widget<Text>(find.text(t)).style?.fontWeight;
    expect(weight('Tree'), FontWeight.w600);
    expect(weight('Text'), FontWeight.w400);
  });

  testWidgets('in dark mode the thumb is lighter than the track', (
    tester,
  ) async {
    await _pump(tester, platform: TargetPlatform.iOS, dark: true);
    final apple = tester.widget<CupertinoSlidingSegmentedControl<bool>>(
      find.byType(CupertinoSlidingSegmentedControl<bool>),
    );
    expect(
      apple.thumbColor.computeLuminance(),
      greaterThan(apple.backgroundColor.computeLuminance()),
    );
  });

  testWidgets('a right-to-left row maps the area to the mirrored segment', (
    tester,
  ) async {
    final picks = await _pump(
      tester,
      platform: TargetPlatform.windows,
      direction: TextDirection.rtl,
    );
    final box = tester.getRect(_control);
    // The Text segment leads, so it is at the right in RTL.
    final text = tester.getRect(find.text('Text')).center.dx;
    expect(text, greaterThan(tester.getRect(find.text('Tree')).center.dx));
    await tester.tapAt(Offset(text, box.top + 0.5));
    expect(picks, [false]);
  });

  group('PillSegmentedControl default look', () {
    testWidgets('is 36 high with a 3 pt track and 14 pt labels', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: Scaffold(
            body: PillSegmentedControl<int>(
              value: 0,
              segments: const {0: 'One', 1: 'Two', 2: 'Three'},
              onChanged: (_) {},
            ),
          ),
        ),
      );
      final pill = find.byType(PillSegmentedControl<int>);
      expect(tester.getSize(pill).height, 36);
      expect(tester.getSize(pill).width, 800);
      final one = tester.widget<Text>(find.text('One'));
      expect(one.style?.fontSize, 14);
      expect(one.style?.fontWeight, FontWeight.w600);
      // The segments share the width evenly inside the 3 pt padding.
      expect(tester.getSize(find.byType(InkWell).first).width, (800 - 6) / 3);
    });
  });
}
