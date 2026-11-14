import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/server_care/widgets/usage_chart.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

// 30 days ending 12 Nov: 8.4M in all, 812K on the 12th with 9 conversations,
// the highest day 5 Nov at 1.2M.
List<UsageChartDay> _days() {
  const thousands = [
    160, 190, 0, 0, 250, 328, 280, 210, 240, 0, //
    110, 270, 310, 290, 230, 180, 0, 130, 240, 300, //
    280, 380, 1200, 470, 330, 280, 0, 410, 520, 812,
  ];
  return [
    for (var i = 0; i < 30; i++)
      UsageChartDay(
        day: DateTime(2026, 11, 12 - (29 - i)),
        value: thousands[i] * 1000.0,
        conversations: i == 29 ? 9 : 2,
      ),
  ];
}

Widget _host(
  Widget chart, {
  double textScale = 1,
  bool reduceMotion = false,
  double width = 390,
  Locale? locale,
  ThemeData? theme,
}) => MaterialApp(
  locale: locale,
  theme: theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 800),
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(width: width, child: chart),
      ),
    ),
  ),
);

UsageChart _chart({
  List<UsageChartDay>? days,
  UsageChartMetric metric = UsageChartMetric.tokens,
  UsageChartWindow window = UsageChartWindow.days30,
  ValueChanged<int>? onSelected,
}) => UsageChart(
  days: days ?? _days(),
  metric: metric,
  window: window,
  onSelected: onSelected,
);

/// The labelled nodes under [node] in reading order; the chart wraps its bars
/// in one unlabelled node.
List<String> _dayLabels(SemanticsNode node) {
  final labels = <String>[];
  void walk(SemanticsNode n) {
    n.visitChildren((child) {
      if (child.label.isNotEmpty) labels.add(child.label);
      walk(child);
      return true;
    });
  }

  walk(node);
  return labels;
}

void main() {
  testWidgets('one summary node, then one child per day in date order', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_chart()));
    await tester.pumpAndSettle();

    const summary =
        'Tokens per day, last 30 days. Total 8.4 million. '
        'Highest 1.2 million on 5 November.';
    final node = tester.getSemantics(find.bySemanticsLabel(summary));
    final labels = _dayLabels(node);

    expect(labels, hasLength(30));
    expect(labels.first, '14 October: 160 thousand tokens, 2 conversations');
    expect(labels[22], '5 November: 1.2 million tokens, 2 conversations');
    expect(labels.last, '12 November: 812 thousand tokens, 9 conversations');
    expect(
      [for (final l in labels) int.parse(l.split(' ').first)],
      [...List.generate(18, (i) => 14 + i), ...List.generate(12, (i) => 1 + i)],
    );
    handle.dispose();
  });

  testWidgets('cost is described in dollars', (tester) async {
    final handle = tester.ensureSemantics();
    final days = [
      for (var i = 0; i < 7; i++)
        UsageChartDay(
          day: DateTime(2026, 11, 6 + i),
          value: i == 2 ? 1.77 : 0.4,
          conversations: 1,
        ),
    ];
    await tester.pumpWidget(
      _host(
        _chart(
          days: days,
          metric: UsageChartMetric.cost,
          window: UsageChartWindow.days7,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel(
        'Estimated cost per day, last 7 days. Total \$4.17. '
        'Highest \$1.77 on 8 November.',
      ),
      findsOneWidget,
    );
    expect(
      _dayLabels(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Estimated'))),
      ),
      contains('8 November: \$1.77, 1 conversation'),
    );
    handle.dispose();
  });

  testWidgets('the label above the chart follows the selection', (
    tester,
  ) async {
    final picked = <int>[];
    await tester.pumpWidget(_host(_chart(onSelected: picked.add)));
    await tester.pumpAndSettle();
    expect(find.text('12 Nov · 812K tokens · 9 conversations'), findsOneWidget);

    // The plot starts after the y axis gutter; tap the sixth bar.
    final plot = tester.getTopLeft(find.byType(CustomPaint).last);
    final slot =
        (390 - (plot.dx - tester.getTopLeft(find.byType(UsageChart)).dx)) / 30;
    await tester.tapAt(plot + Offset(slot * 22.5, 100));
    await tester.pump();
    expect(picked, [22]);
    expect(find.text('5 Nov · 1.2M tokens · 2 conversations'), findsOneWidget);
  });

  testWidgets('arrow keys work right after a click on a bar', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(_host(_chart(onSelected: picked.add)));
    await tester.pumpAndSettle();
    final plot = tester.getTopLeft(find.byType(CustomPaint).last);
    final slot =
        (390 - (plot.dx - tester.getTopLeft(find.byType(UsageChart)).dx)) / 30;
    await tester.tapAt(plot + Offset(slot * 22.5, 100));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    expect(picked, [22, 21]);
  });

  testWidgets('arrow keys move between bars', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(_host(_chart(onSelected: picked.add)));
    await tester.pumpAndSettle();

    final focusNode = Focus.of(tester.element(find.byType(CustomPaint).last));
    focusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);

    expect(picked, [28, 27, 28, 0, 29]);
    expect(find.text('12 Nov · 812K tokens · 9 conversations'), findsOneWidget);
  });

  testWidgets('bars rise once, but not under reduced motion', (tester) async {
    await tester.pumpWidget(_host(_chart()));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host(_chart(), reduceMotion: true));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the x axis is dropped at the largest text size', (tester) async {
    Future<Map<int, String>> xLabels(double scale) async {
      await tester.pumpWidget(_host(_chart(), textScale: scale));
      await tester.pumpAndSettle();
      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is UsageChartPlotPainter,
        ),
      );
      return (paint.painter! as UsageChartPlotPainter).xLabels;
    }

    // Mondays of the 30 days: 19 and 26 Oct, 2 and 9 Nov.
    expect((await xLabels(1)).values, ['19 Oct', '26 Oct', '2 Nov', '9 Nov']);
    expect(await xLabels(2), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '90 days scrolls with 44 point bars and opens at the newest day',
    (tester) async {
      final days = [
        for (var i = 0; i < 90; i++)
          UsageChartDay(
            day: DateTime(2026, 11, 12 - (89 - i)),
            value: 100000.0 * (i % 7),
            conversations: 1,
          ),
      ];
      await tester.pumpWidget(
        _host(_chart(days: days, window: UsageChartWindow.days90)),
      );
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).last,
      );
      expect(scrollable.position.pixels, 0); // reversed: 0 is the newest day
      expect(scrollable.position.maxScrollExtent, greaterThan(90 * 44 - 390));
      expect(tester.getSize(find.byType(CustomPaint).last).width, 90 * 44);
    },
  );

  testWidgets('German locale: summary, label and bar labels', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(_chart(), locale: const Locale('de')));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('^Tokens pro Tag, letzte 30 Tage')),
    );
    expect(
      node.label,
      'Tokens pro Tag, letzte 30 Tage. Gesamt 8,4 Millionen. '
      'Höchster Wert 1,2 Millionen am 5. November.',
    );
    expect(
      _dayLabels(node).last,
      '12. November: 812 Tausend Tokens, 9 Unterhaltungen',
    );
    expect(find.textContaining('12. Nov ·'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('selecting the bar that is already selected brings it back '
      'into view in the 90 day window', (tester) async {
    final days = [
      for (var i = 0; i < 90; i++)
        UsageChartDay(
          day: DateTime(2026, 11, 12 - (89 - i)),
          value: 100000.0 * (i % 7),
          conversations: 1,
        ),
    ];
    await tester.pumpWidget(
      _host(_chart(days: days, window: UsageChartWindow.days90)),
    );
    await tester.pumpAndSettle();
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).last,
    );
    expect(scrollable.position.pixels, 0);

    // The newest day stays selected while the view moves to the oldest.
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    final focusNode = Focus.of(tester.element(find.byType(CustomPaint).last));
    focusNode.requestFocus();
    await tester.pump();
    // End selects the last bar again: no change of selection, but it reveals.
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pump();

    expect(scrollable.position.pixels, 0);
  });

  for (final (name, theme) in [
    ('light', buildHermesLightTheme()),
    ('dark', buildHermesDarkTheme()),
  ]) {
    testWidgets('the selected day is outlined in the text colour ($name)', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_chart(), theme: theme));
      await tester.pumpAndSettle();
      final scheme = Theme.of(tester.element(find.byType(UsageChart)))
          .colorScheme;
      final plot = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is UsageChartPlotPainter,
      );
      final box = tester.renderObject<RenderBox>(plot);
      // One 2 px outline, drawn after the bars, around the selected slot;
      // there is no tinted column any more.
      // The 25 days with use draw a rounded bar each, then the outline.
      final pattern = paints;
      for (var i = 0; i < 25; i++) {
        pattern.rrect();
      }
      pattern.rrect(
        color: scheme.onSurface,
        style: PaintingStyle.stroke,
        strokeWidth: 2,
      );
      expect(box, pattern);
      expect(
        box,
        isNot(paints..rect(color: scheme.primary.withValues(alpha: 0.12))),
      );
      // The line stands out from the plot by far more than 3:1.
      double lum(Color c) => c.computeLuminance();
      final fg = lum(scheme.onSurface);
      final bg = lum(scheme.surface);
      final ratio = (math.max(fg, bg) + 0.05) / (math.min(fg, bg) + 0.05);
      expect(ratio, greaterThan(3));
    });
  }
}
