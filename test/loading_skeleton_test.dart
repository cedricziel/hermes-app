import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/loading_skeleton.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: buildHermesLightTheme(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(body: child),
  ),
);

double _contrast(Color a, Color b) {
  final hi = a.computeLuminance() > b.computeLuminance() ? a : b;
  final lo = identical(hi, a) ? b : a;
  return (hi.computeLuminance() + 0.05) / (lo.computeLuminance() + 0.05);
}

void main() {
  for (final (brightness, theme, floor) in [
    (Brightness.light, buildHermesLightTheme(), 1.45),
    (Brightness.dark, buildHermesDarkTheme(), 1.8),
  ]) {
    test('the ${brightness.name} bars stand $floor:1 off the page', () {
      final page = theme.scaffoldBackgroundColor;
      final bar = skeletonBarColor(brightness);
      expect(_contrast(bar, page), greaterThanOrEqualTo(floor));
      // At the pulse's trough the bar is 80% over the page.
      final trough = Color.alphaBlend(bar.withValues(alpha: 0.8), page);
      expect(_contrast(trough, page), greaterThanOrEqualTo(1.3));
    });
  }

  testWidgets('draws only the whole lines that fit, and never overflows', (
    tester,
  ) async {
    for (final scale in [1.0, 2.0, 3.1]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  height: 70,
                  child: LoadingSkeleton(label: 'Loading', lines: 6),
                ),
              ),
            ),
          ),
        ),
      );
      // 16 + 2 * 8 = 32 per line at 1x, so two fit 70; larger text, one.
      expect(
        find.byType(FractionallySizedBox),
        findsNWidgets(scale == 1 ? 2 : 1),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('draws every line when the height is unbounded', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: LoadingSkeleton(label: 'Loading', lines: 6),
          ),
        ),
      ),
    );
    expect(find.byType(FractionallySizedBox), findsNWidgets(6));
  });

  testWidgets('the pulse never drops below 80% opacity', (tester) async {
    await tester.pumpWidget(_host(const LoadingSkeleton(label: 'Loading')));
    var lowest = 1.0;
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final opacity = tester
          .widget<Opacity>(
            find
                .descendant(
                  of: find.byType(LoadingSkeleton),
                  matching: find.byType(Opacity),
                )
                .first,
          )
          .opacity;
      if (opacity < lowest) lowest = opacity;
    }
    expect(lowest, greaterThanOrEqualTo(0.8));
    expect(lowest, lessThan(1));
  });

  testWidgets('is one node named by its label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const LoadingSkeleton(label: 'Loading logs', lines: 4)),
    );
    expect(find.bySemanticsLabel('Loading logs'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Loading logs')).label,
      'Loading logs',
    );
    handle.dispose();
  });

  testWidgets('draws one block per line', (tester) async {
    await tester.pumpWidget(
      _host(const LoadingSkeleton(label: 'Loading', lines: 5)),
    );
    expect(find.byType(FractionallySizedBox), findsNWidgets(5));
  });

  testWidgets('pulses, and stands still under reduced motion', (tester) async {
    await tester.pumpWidget(_host(const LoadingSkeleton(label: 'Loading')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());

    await tester.pumpWidget(
      _host(const LoadingSkeleton(label: 'Loading'), reduceMotion: true),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.hasRunningAnimations, isFalse);
  });
}
