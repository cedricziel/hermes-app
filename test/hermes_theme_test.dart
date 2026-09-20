import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  for (final (name, theme) in [
    ('light', buildHermesLightTheme()),
    ('dark', buildHermesDarkTheme()),
  ]) {
    test('$name: a plain text field has a visible outline and padding', () {
      final input = theme.inputDecorationTheme;

      expect(input.border, isA<OutlineInputBorder>());
      expect(input.border!.borderSide.color, theme.colorScheme.outline);
      expect(input.focusedBorder, isA<OutlineInputBorder>());
      expect(input.contentPadding, isNot(EdgeInsets.zero));
    });
  }
}
