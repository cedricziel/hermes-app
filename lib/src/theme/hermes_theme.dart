import 'package:flutter/material.dart';

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

ThemeData buildHermesLightTheme() {
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
    subtleText: HermesColors.zinc500,
  );
}

ThemeData buildHermesDarkTheme() {
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
  );
}

ThemeData _buildTheme({
  required ColorScheme scheme,
  required Color scaffoldBackground,
  required Color sidebarBackground,
  required Color subtleText,
}) {
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: scaffoldBackground,
    extensions: [
      HermesChatColors(sidebar: sidebarBackground, subtleText: subtleText),
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBackground,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
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
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: EdgeInsets.zero,
      hintStyle: TextStyle(color: subtleText),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
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
/// timestamps and hints throughout the thread view).
class HermesChatColors extends ThemeExtension<HermesChatColors> {
  const HermesChatColors({required this.sidebar, required this.subtleText});

  final Color sidebar;
  final Color subtleText;

  @override
  HermesChatColors copyWith({Color? sidebar, Color? subtleText}) {
    return HermesChatColors(
      sidebar: sidebar ?? this.sidebar,
      subtleText: subtleText ?? this.subtleText,
    );
  }

  @override
  HermesChatColors lerp(ThemeExtension<HermesChatColors>? other, double t) {
    if (other is! HermesChatColors) return this;
    return HermesChatColors(
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
    );
  }
}

extension HermesThemeX on BuildContext {
  HermesChatColors get hermesColors =>
      Theme.of(this).extension<HermesChatColors>()!;
}
