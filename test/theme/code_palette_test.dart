import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/theme/hermes_code_colors.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final x = _luminance(a);
  final y = _luminance(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

/// Every role of [p], by name.
Map<String, Color> _roles(HermesCodeColors p) => {
  'key': p.key,
  'keyword': p.keyword,
  'string': p.string,
  'comment': p.comment,
  'number': p.number,
  'function': p.function,
  'typeName': p.typeName,
};

/// The card of the Claude Design canvas, which code sits on in tool cards; the
/// app's own surfaces are read from the theme.
const _canvasCardLight = Color(0xFFFBFBFB);
const _canvasCardDark = Color(0xFF151517);

void main() {
  for (final (name, palette, theme, card) in [
    (
      'light',
      HermesCodeColors.light,
      buildHermesLightTheme(),
      _canvasCardLight,
    ),
    ('dark', HermesCodeColors.dark, buildHermesDarkTheme(), _canvasCardDark),
  ]) {
    group('code palette, $name', () {
      final scheme = theme.colorScheme;
      // The canvas card, the page, the raised surface (zinc 100 / 800) and the
      // chat's code panel.
      final backgrounds = {
        'card': card,
        'page': scheme.surface,
        'surface-high': scheme.surfaceContainerHighest,
        // What a fenced block of a chat reply sits on.
        'chat code block': buildMaterialUiTheme(scheme)
            .colorScheme
            .surfaceContainer,
      };

      for (final role in _roles(palette).entries) {
        for (final background in backgrounds.entries) {
          test('${role.key} is at least 4.5:1 on the ${background.key}', () {
            expect(
              _contrast(role.value, background.value),
              greaterThanOrEqualTo(4.5),
              reason: '${role.value} on ${background.value}',
            );
          });
        }
      }

      test('no role is red or green, which mean status and diff', () {
        for (final role in _roles(palette).entries) {
          final hue = HSLColor.fromColor(role.value).hue;
          expect(hue <= 20 || hue >= 345, isFalse, reason: '${role.key} red');
          // Strings are teal (hue about 175), clear of green.
          expect(hue >= 75 && hue <= 160, isFalse, reason: '${role.key} green');
        }
      });

      test('comments take the muted text colour', () {
        expect(
          palette.comment,
          theme.extension<HermesChatColors>()!.subtleText,
        );
      });
    });
  }

  test('the values are the canvas tokens', () {
    expect(
      [
        HermesCodeColors.light.key,
        HermesCodeColors.light.string,
        HermesCodeColors.light.number,
        HermesCodeColors.light.keyword,
      ],
      [
        const Color(0xFF1D4ED8),
        const Color(0xFF0F766E),
        const Color(0xFF7E22CE),
        const Color(0xFFBE185D),
      ],
    );
    expect(
      [
        HermesCodeColors.dark.key,
        HermesCodeColors.dark.string,
        HermesCodeColors.dark.number,
        HermesCodeColors.dark.keyword,
      ],
      [
        const Color(0xFF93C5FD),
        const Color(0xFF5EEAD4),
        const Color(0xFFD8B4FE),
        const Color(0xFFF9A8D4),
      ],
    );
  });
}
