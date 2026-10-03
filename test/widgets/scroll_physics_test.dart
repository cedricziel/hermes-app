import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

ScrollPhysics _physicsOf(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position.physics;

Future<void> _pump(WidgetTester tester, TargetPlatform platform) =>
    tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme().copyWith(platform: platform),
        home: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [for (var i = 0; i < 3; i++) Text('row $i')],
        ),
      ),
    );

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('lists bounce on $platform', (tester) async {
      await _pump(tester, platform);
      expect(_physicsOf(tester).parent, isA<BouncingScrollPhysics>());
    });
  }

  testWidgets('lists clamp on Android', (tester) async {
    await _pump(tester, TargetPlatform.android);
    expect(_physicsOf(tester).parent, isA<ClampingScrollPhysics>());
  });
}
