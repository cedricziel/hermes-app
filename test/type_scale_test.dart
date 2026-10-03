import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_theme.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  Future<TextTheme> resolved(
    WidgetTester tester,
    TargetPlatform platform,
  ) async {
    late TextTheme text;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(platform: platform),
        home: Builder(
          builder: (context) {
            text = Theme.of(context).textTheme;
            return const SizedBox();
          },
        ),
      ),
    );
    return text;
  }

  group('theme text styles', () {
    testWidgets('follow the iOS type ramp on iOS', (tester) async {
      final text = await resolved(tester, TargetPlatform.iOS);

      expect(text.bodyLarge!.fontSize, 17);
      expect(text.bodyMedium!.fontSize, 15);
      expect(text.bodySmall!.fontSize, 13);
      expect(text.labelSmall!.fontSize, 12);
      expect(text.titleMedium!.fontSize, 17);
      expect(text.titleMedium!.fontWeight, FontWeight.w600);
      expect(text.headlineLarge!.fontSize, 34);
    });

    testWidgets('keep the Material sizes on Android and macOS', (tester) async {
      for (final platform in [TargetPlatform.android, TargetPlatform.macOS]) {
        final text = await resolved(tester, platform);
        expect(text.bodyLarge!.fontSize, 16, reason: '$platform');
        expect(text.bodyMedium!.fontSize, 14, reason: '$platform');
        expect(text.bodySmall!.fontSize, 12, reason: '$platform');
      }
    });

    test('the app bar title is a 17 point headline on iOS only', () {
      expect(
        buildHermesLightTheme(platform: TargetPlatform.iOS)
            .appBarTheme
            .titleTextStyle!
            .fontSize,
        17,
      );
      expect(
        buildHermesLightTheme(platform: TargetPlatform.android)
            .appBarTheme
            .titleTextStyle!
            .fontSize,
        16,
      );
    });
  });

  group('chat message text', () {
    double size(TargetPlatform platform) =>
        buildChatTheme(buildHermesLightTheme(platform: platform))
            .typography
            .bodyMedium
            .fontSize!;

    test('is 17 on iOS and 14.5 elsewhere', () {
      expect(size(TargetPlatform.iOS), 17);
      expect(size(TargetPlatform.macOS), 14.5);
      expect(size(TargetPlatform.android), 14.5);
    });
  });
}
