import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/app_icons.dart';

Future<void> _pump(WidgetTester tester, TargetPlatform platform) =>
    tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: const Column(
          children: [
            AppIcon(AppIcons.add),
            AppIcon(AppIcons.delete, size: 30),
            AppIcon(AppIcons.chat),
          ],
        ),
      ),
    );

IconData _glyph(WidgetTester tester, int index) =>
    tester.widget<Icon>(find.byType(Icon).at(index)).icon!;

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets('AppIcon shows the Cupertino glyph on $platform', (
      tester,
    ) async {
      await _pump(tester, platform);

      expect(_glyph(tester, 0), CupertinoIcons.add);
      expect(_glyph(tester, 1), CupertinoIcons.delete);
      expect(_glyph(tester, 2), CupertinoIcons.chat_bubble);
    });
  }

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('AppIcon keeps the Material glyph on $platform', (
      tester,
    ) async {
      await _pump(tester, platform);

      expect(_glyph(tester, 0), Icons.add);
      expect(_glyph(tester, 1), Icons.delete_outline);
      expect(_glyph(tester, 2), Icons.chat_bubble_outline);
    });
  }

  testWidgets('AppIcon passes size through', (tester) async {
    await _pump(tester, TargetPlatform.iOS);

    expect(tester.widget<Icon>(find.byType(Icon).at(1)).size, 30);
  });
}
