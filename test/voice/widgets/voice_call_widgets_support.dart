import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps [child] at [size], text [scale] and [platform], in a bare
/// MaterialApp (strings fall back to English).
Future<void> pumpVoice(
  WidgetTester tester,
  Widget child, {
  double scale = 1,
  Size size = const Size(390, 844),
  TargetPlatform platform = TargetPlatform.android,
  bool dark = false,
  bool disableAnimations = false,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        platform: platform,
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
      builder: (context, home) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: disableAnimations,
        ),
        child: home!,
      ),
      home: Scaffold(body: child),
    ),
  );
}
