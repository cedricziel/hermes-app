import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_theme.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  for (final (name, theme) in [
    ('light', buildHermesLightTheme()),
    ('dark', buildHermesDarkTheme()),
  ]) {
    group('buildChatTheme ($name)', () {
      final scheme = theme.colorScheme;
      final chat = buildChatTheme(theme);

      test('sent bubble is the muted user chip with readable text', () {
        final expected = Color.alphaBlend(
          scheme.surfaceContainerHighest.withValues(alpha: 0.6),
          scheme.surface,
        );
        expect(chat.colors.primary, expected);
        expect(chat.colors.onPrimary, scheme.onSurface);
      });

      test('surface colors follow the color scheme', () {
        expect(chat.colors.surface, scheme.surface);
        expect(chat.colors.onSurface, scheme.onSurface);
        expect(chat.colors.surfaceContainerLow, scheme.surface);
        expect(chat.colors.surfaceContainer, scheme.surfaceContainer);
        expect(chat.colors.surfaceContainerHigh, scheme.surfaceContainerHigh);
      });

      test('bubbles use the app radius', () {
        expect(chat.shape, BorderRadius.circular(kHermesRadius));
      });

      test('message text matches the old bubble typography', () {
        expect(chat.typography.bodyMedium.fontSize, 14.5);
        expect(chat.typography.bodyMedium.height, 1.4);
      });

      test('font family is carried over from the app theme', () {
        final themed = buildChatTheme(
          theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: 'Inter')),
        );
        expect(themed.typography.bodyMedium.fontFamily, 'Inter');
        expect(themed.typography.labelSmall.fontFamily, 'Inter');
      });
    });
  }
}
