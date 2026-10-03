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

    test('buttons are compact', () {
      final size = theme.textButtonTheme.style!.minimumSize!.resolve({});
      expect(size!.height, 28);
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
