import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import '../theme/hermes_theme.dart';

/// Derives the Flyer Chat theme from the app [theme], so the package's
/// bubbles and composer match the hand-rolled chat UI in light and dark.
///
/// Built by hand instead of `ChatTheme.fromThemeData`: that factory takes
/// `material_ui`'s `ThemeData`, a different type from the one in Flutter's
/// material library.
///
/// The package paints sent bubbles with `colors.primary` and their text with
/// `colors.onPrimary`; the old user chip was a muted surface with regular
/// text, so those two roles are remapped rather than taking the (near-black)
/// accent from the [ColorScheme].
ChatTheme buildChatTheme(ThemeData theme) {
  final scheme = theme.colorScheme;
  final text = theme.textTheme;
  return ChatTheme(
    colors: ChatColors(
      primary: Color.alphaBlend(
        scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        scheme.surface,
      ),
      onPrimary: scheme.onSurface,
      surface: scheme.surface,
      onSurface: scheme.onSurface,
      surfaceContainer: scheme.surfaceContainer,
      surfaceContainerLow: scheme.surface,
      surfaceContainerHigh: scheme.surfaceContainerHigh,
    ),
    typography: ChatTypography(
      bodyLarge: text.bodyLarge!,
      bodyMedium: text.bodyMedium!.copyWith(fontSize: 14.5, height: 1.4),
      bodySmall: text.bodySmall!,
      labelLarge: text.labelLarge!,
      labelMedium: text.labelMedium!,
      labelSmall: text.labelSmall!,
    ),
    shape: BorderRadius.circular(kHermesRadius),
  );
}
