import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'platform_chrome.dart';

/// The neutral, high-contrast palette behind the chat UI's look and feel —
/// modeled on assistant-ui's default (itself shadcn/ui's "neutral" theme):
/// near-monochrome grays, a near-black/near-white accent instead of a hue,
/// and 1px borders instead of shadows for surface separation.
class HermesColors {
  const HermesColors._();

  static const zinc50 = Color(0xFFFAFAFA);
  static const zinc100 = Color(0xFFF4F4F5);
  static const zinc200 = Color(0xFFE4E4E7);
  static const zinc300 = Color(0xFFD4D4D8);
  static const zinc400 = Color(0xFFA1A1AA);
  static const zinc500 = Color(0xFF71717A);
  static const zinc600 = Color(0xFF52525B);
  static const zinc700 = Color(0xFF3F3F46);
  static const zinc800 = Color(0xFF27272A);
  static const zinc900 = Color(0xFF18181B);
  static const zinc950 = Color(0xFF09090B);
}

/// Border radius used throughout the chat UI (composer, message chips,
/// suggestion cards, sidebar rows) — assistant-ui leans on one consistent
/// "rounded-xl" everywhere rather than mixing radii.
const double kHermesRadius = 14;

/// Opacity of the on-surface color for de-emphasized text such as Kanban task
/// ids.
const double kHermesMutedAlpha = 0.7;

/// A push button's height on macOS, tighter than a touch target.
const double _kMacButtonHeight = 28;

/// [platform] defaults to the running platform; tests pass one to build the
/// Apple or Material variant.
ThemeData buildHermesLightTheme({TargetPlatform? platform}) {
  const c = HermesColors.zinc900;
  final scheme = const ColorScheme.light(
    brightness: Brightness.light,
    primary: c,
    onPrimary: Colors.white,
    secondary: HermesColors.zinc700,
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: HermesColors.zinc900,
    surfaceContainerHighest: HermesColors.zinc100,
    error: Color(0xFFB91C1C),
    onError: Colors.white,
    outline: HermesColors.zinc200,
    outlineVariant: HermesColors.zinc100,
  );
  return _buildTheme(
    scheme: scheme,
    scaffoldBackground: Colors.white,
    sidebarBackground: HermesColors.zinc50,
    subtleText: const Color(0xFF6B6B74),
    success: const Color(0xFF166534),
    warning: const Color(0xFF92400E),
    platform: platform,
  );
}

ThemeData buildHermesDarkTheme({TargetPlatform? platform}) {
  final scheme = const ColorScheme.dark(
    brightness: Brightness.dark,
    primary: HermesColors.zinc50,
    onPrimary: HermesColors.zinc900,
    secondary: HermesColors.zinc300,
    onSecondary: HermesColors.zinc900,
    surface: HermesColors.zinc950,
    onSurface: HermesColors.zinc50,
    surfaceContainerHighest: HermesColors.zinc800,
    error: Color(0xFFF87171),
    onError: HermesColors.zinc950,
    outline: HermesColors.zinc800,
    outlineVariant: HermesColors.zinc900,
  );
  return _buildTheme(
    scheme: scheme,
    scaffoldBackground: HermesColors.zinc950,
    sidebarBackground: HermesColors.zinc900,
    subtleText: HermesColors.zinc400,
    success: const Color(0xFF4ADE80),
    warning: const Color(0xFFFBBF24),
    platform: platform,
  );
}

ThemeData _buildTheme({
  required ColorScheme scheme,
  required Color scaffoldBackground,
  required Color sidebarBackground,
  required Color subtleText,
  required Color success,
  required Color warning,
  TargetPlatform? platform,
}) {
  final target = platform ?? defaultTargetPlatform;
  final isIos = target == TargetPlatform.iOS;
  final isMac = target == TargetPlatform.macOS;
  final apple = isIos || isMac;
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    platform: target,
  );
  final appleButtonSize = apple
      ? Size(0, isIos ? kAppleMinTapTarget : _kMacButtonHeight)
      : null;
  final macMenuText = isMac
      ? base.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          fontSize: 13,
        )
      : null;
  final fieldRadius = BorderRadius.circular(10);
  final appleFieldBorder = OutlineInputBorder(
    borderRadius: fieldRadius,
    borderSide: BorderSide.none,
  );
  return base.copyWith(
    scaffoldBackgroundColor: scaffoldBackground,
    splashFactory: apple ? NoSplash.splashFactory : null,
    adaptations: [_AppleSwitchAdaptation(scheme)],
    extensions: [
      HermesChatColors(
        sidebar: sidebarBackground,
        subtleText: subtleText,
        success: success,
        warning: warning,
      ),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBackground,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kHermesRadius),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outline,
      thickness: 1,
      space: 1,
    ),
    // A plain field gets an outline, so it reads as something to type in. A
    // field that wants none sets its own `border`; it still shows the focus
    // outline. The chat composer's field turns all of its borders off.
    inputDecorationTheme: InputDecorationTheme(
      filled: apple,
      fillColor: apple ? scheme.surfaceContainerHighest : null,
      border: apple
          ? appleFieldBorder
          : OutlineInputBorder(
              borderRadius: fieldRadius,
              borderSide: BorderSide(color: scheme.outline),
            ),
      focusedBorder: isIos
          ? appleFieldBorder
          : OutlineInputBorder(
              borderRadius: fieldRadius,
              borderSide: BorderSide(color: scheme.onSurface, width: 1.5),
            ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      hintStyle: TextStyle(color: subtleText),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: appleButtonSize,
        foregroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: appleButtonSize,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: appleButtonSize,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      menuPadding: isMac ? const EdgeInsets.symmetric(vertical: 4) : null,
      textStyle: macMenuText,
      labelTextStyle: macMenuText == null
          ? null
          : WidgetStatePropertyAll(macMenuText),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isMac ? 6 : 10),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.onSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(color: scheme.surface, fontSize: 12),
    ),
  );
}

/// Chat-specific colors that don't map onto [ColorScheme]'s fixed roles
/// (a distinct sidebar tint, a de-emphasized "muted" text color used for
/// timestamps and hints throughout the thread view, and the status colors for
/// something that went well or needs a look).
class HermesChatColors extends ThemeExtension<HermesChatColors> {
  const HermesChatColors({
    required this.sidebar,
    required this.subtleText,
    required this.success,
    required this.warning,
  });

  final Color sidebar;
  final Color subtleText;
  final Color success;
  final Color warning;

  @override
  HermesChatColors copyWith({
    Color? sidebar,
    Color? subtleText,
    Color? success,
    Color? warning,
  }) {
    return HermesChatColors(
      sidebar: sidebar ?? this.sidebar,
      subtleText: subtleText ?? this.subtleText,
      success: success ?? this.success,
      warning: warning ?? this.warning,
    );
  }

  @override
  HermesChatColors lerp(ThemeExtension<HermesChatColors>? other, double t) {
    if (other is! HermesChatColors) return this;
    return HermesChatColors(
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension HermesThemeX on BuildContext {
  /// Falls back to the Hermes theme's own values under a theme without them,
  /// such as a test's plain `MaterialApp`.
  HermesChatColors get hermesColors {
    final theme = Theme.of(this);
    return theme.extension<HermesChatColors>() ??
        (theme.brightness == Brightness.dark
                ? buildHermesDarkTheme()
                : buildHermesLightTheme())
            .extension<HermesChatColors>()!;
  }
}

/// Keeps the iOS/macOS toggle's native shape and motion but swaps its green
/// for the zinc primary; the thumb takes `onPrimary` so it stays visible on
/// the near-white dark-mode track.
class _AppleSwitchAdaptation extends Adaptation<SwitchThemeData> {
  const _AppleSwitchAdaptation(this.scheme);

  final ColorScheme scheme;

  @override
  SwitchThemeData adapt(ThemeData theme, SwitchThemeData defaultValue) {
    switch (theme.platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return SwitchThemeData(
          trackColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? scheme.primary : null,
          ),
          thumbColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? scheme.onPrimary : null,
          ),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return defaultValue;
    }
  }
}
