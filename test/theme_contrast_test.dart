import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/theme/hermes_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void _expectReadable(Color fg, Color bg) {
  final shown = Color.alphaBlend(fg, bg);
  expect(_contrast(shown, bg), greaterThanOrEqualTo(4.5));
}

void main() {
  for (final (name, theme) in [
    ('light', buildHermesLightTheme()),
    ('dark', buildHermesDarkTheme()),
  ]) {
    final scheme = theme.colorScheme;
    final colors = theme.extension<HermesChatColors>()!;
    final surfaces = {
      'scaffold': theme.scaffoldBackgroundColor,
      'sidebar': colors.sidebar,
      'card': scheme.surface,
      'fill': scheme.surfaceContainerHighest,
    };
    final muted = scheme.onSurface.withValues(alpha: kHermesMutedAlpha);

    for (final MapEntry(key: surface, value: bg) in surfaces.entries) {
      for (final (label, fg) in [
        ('success', colors.success),
        ('warning', colors.warning),
        ('subtle text', colors.subtleText),
        ('error', scheme.error),
        ('muted text', muted),
      ]) {
        test('$name: $label on $surface meets 4.5:1', () {
          _expectReadable(fg, bg);
        });
      }
    }

    // Tint opacities as the banners, chips and cards use them.
    for (final (label, fg, tint, alpha) in [
      ('success', colors.success, colors.success, 0.1),
      ('warning', colors.warning, colors.warning, 0.15),
      ('error', scheme.error, scheme.error, 0.12),
      ('muted text', muted, scheme.onSurface, 0.1),
    ]) {
      test('$name: $label on its own tint meets 4.5:1', () {
        final bg = Color.alphaBlend(
          tint.withValues(alpha: alpha),
          scheme.surface,
        );
        _expectReadable(fg, bg);
      });
    }
  }
}
