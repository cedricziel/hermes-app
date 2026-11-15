import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  group('on iOS', () {
    final theme = buildHermesLightTheme(platform: TargetPlatform.iOS);

    test('presses leave no ink splash', () {
      expect(theme.splashFactory, NoSplash.splashFactory);
    });

    test('buttons are at least 44 tall', () {
      final size = theme.filledButtonTheme.style!.minimumSize!.resolve({});
      expect(size!.height, 44);
    });

    test('fields are filled without an outline', () {
      expect(theme.inputDecorationTheme.filled, isTrue);
      final border = theme.inputDecorationTheme.border! as OutlineInputBorder;
      expect(border.borderSide, BorderSide.none);
    });
  });

  group('on macOS', () {
    final theme = buildHermesLightTheme(platform: TargetPlatform.macOS);

    test('presses leave no ink splash', () {
      expect(theme.splashFactory, NoSplash.splashFactory);
    });

    testWidgets('buttons are 28 tall once the density is applied', (
      tester,
    ) async {
      final button = TextButton(onPressed: () {}, child: const Text('Go'));
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(body: Center(child: button)),
        ),
      );
      expect(tester.getSize(find.byWidget(button)).height, 28);
    });

    test('popup menus use the smaller Mac radius', () {
      final shape = theme.popupMenuTheme.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(6));
    });
  });

  group('on Android', () {
    final theme = buildHermesDarkTheme(platform: TargetPlatform.android);

    test('keeps Material ripples and outlined fields', () {
      expect(theme.splashFactory, isNot(NoSplash.splashFactory));
      expect(theme.inputDecorationTheme.filled, isFalse);
      final border = theme.inputDecorationTheme.border! as OutlineInputBorder;
      expect(border.borderSide.color, theme.colorScheme.outline);
    });

    test('keeps Material button sizes', () {
      expect(theme.filledButtonTheme.style!.minimumSize, isNull);
    });
  });
}
