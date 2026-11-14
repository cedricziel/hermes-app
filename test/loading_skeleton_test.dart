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

void main() {
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
