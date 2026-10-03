import 'package:flutter/material.dart';

/// Body text in a chat message: Apple's 17 point Body on iOS, where the user's
/// Dynamic Type setting scales it, and the compact size everywhere else.
const double kIosMessageFontSize = 17;
const double kDefaultMessageFontSize = 14.5;

double messageFontSizeFor(TargetPlatform platform) =>
    platform == TargetPlatform.iOS
    ? kIosMessageFontSize
    : kDefaultMessageFontSize;

/// [base] with sizes and weights from Apple's text styles, mapped onto the
/// Material roles the widgets already ask for: Body (17) is `bodyLarge`,
/// Subheadline (15) `bodyMedium`, Footnote (13) `bodySmall` and Caption (12)
/// `labelSmall`. Colors and the font family stay as they are.
TextTheme iosTextTheme(TextTheme base) {
  TextStyle? style(
    TextStyle? from,
    double size, {
    FontWeight weight = FontWeight.w400,
  }) => from?.copyWith(fontSize: size, fontWeight: weight);

  return base.copyWith(
    displayLarge: style(base.displayLarge, 34),
    displayMedium: style(base.displayMedium, 34),
    displaySmall: style(base.displaySmall, 28),
    headlineLarge: style(base.headlineLarge, 34),
    headlineMedium: style(base.headlineMedium, 28),
    headlineSmall: style(base.headlineSmall, 22),
    titleLarge: style(base.titleLarge, 22),
    titleMedium: style(base.titleMedium, 17, weight: FontWeight.w600),
    titleSmall: style(base.titleSmall, 15, weight: FontWeight.w600),
    bodyLarge: style(base.bodyLarge, 17),
    bodyMedium: style(base.bodyMedium, 15),
    bodySmall: style(base.bodySmall, 13),
    labelLarge: style(base.labelLarge, 16, weight: FontWeight.w500),
    labelMedium: style(base.labelMedium, 13, weight: FontWeight.w500),
    labelSmall: style(base.labelSmall, 12, weight: FontWeight.w500),
  );
}
