import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget row, {
  double scale = 1,
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(platform: TargetPlatform.iOS),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: GroupedListView(
          children: [
            GroupedSection(children: [row]),
          ],
        ),
      ),
    ),
  );
}

bool _beside(WidgetTester tester, String title, String value) =>
    (tester.getTopLeft(find.text(title)).dy -
                tester.getTopLeft(find.text(value)).dy)
            .abs() <
        8 &&
    tester.getTopLeft(find.text(value)).dx >
        tester.getTopRight(find.text(title)).dx;

void main() {
  const longValue = 'Running, some channels offline and one restarting';

  for (final scale in [1.5, 2.0]) {
    testWidgets('a short value stays beside the title at ${scale}x', (
      tester,
    ) async {
      await _pump(
        tester,
        const GroupedRow(title: 'Telegram', value: 'Set up', onTap: _noop),
        scale: scale,
        // The test font is wider than the real one: a width that holds the
        // row the way a phone's does.
        width: 640,
      );
      expect(_beside(tester, 'Telegram', 'Set up'), isTrue);
    });
  }

  testWidgets('a value too long to fit stacks under the title at 2x', (
    tester,
  ) async {
    await _pump(
      tester,
      const GroupedRow(title: 'State', value: longValue, subtitle: 'Gateway'),
      scale: 2,
    );
    final title = tester.getTopLeft(find.text('State'));
    final value = tester.getTopLeft(find.text(longValue));
    final subtitle = tester.getTopLeft(find.text('Gateway'));
    expect(value.dy, greaterThan(title.dy));
    expect(value.dx, title.dx);
    // Title, then value, then subtitle.
    expect(subtitle.dy, greaterThan(value.dy));
  });

  testWidgets('a stacked value is set apart from the subtitle', (tester) async {
    await _pump(
      tester,
      const GroupedRow(title: 'State', value: longValue, subtitle: 'Gateway'),
      scale: 2,
    );
    final value = tester.widget<Text>(find.text(longValue)).style!;
    final subtitle = tester.widget<Text>(find.text('Gateway')).style!;
    expect(value.fontWeight, isNot(subtitle.fontWeight));
    expect(value.color, isNot(subtitle.color));
  });

  testWidgets('at the default size a long value is cut beside the title, as '
      'it was', (tester) async {
    await _pump(tester, const GroupedRow(title: 'State', value: longValue));
    expect(_beside(tester, 'State', longValue), isTrue);
  });

  testWidgets('a row with a switch never stacks', (tester) async {
    await _pump(
      tester,
      GroupedRow(
        title: 'State',
        value: longValue,
        trailing: Switch(value: true, onChanged: (_) {}),
      ),
      scale: 2,
    );
    expect(_beside(tester, 'State', longValue), isTrue);
  });

  testWidgets('a row without a value is untouched', (tester) async {
    await _pump(
      tester,
      const GroupedRow(title: 'Telegram', subtitle: 'Connected', onTap: _noop),
      scale: 2,
    );
    expect(find.byKey(const Key('grouped-row-chevron')), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
  });
}

void _noop() {}
