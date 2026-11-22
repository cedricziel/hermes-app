import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

/// The app theme built for [platform], in the brightness of the surrounding
/// theme. Platform previews use this instead of
/// `Theme.of(context).copyWith(platform: …)`, which keeps the base theme's
/// tap-target size, density and platform-specific component themes.
ThemeData platformTheme(BuildContext context, TargetPlatform platform) =>
    Theme.of(context).brightness == Brightness.dark
    ? buildHermesDarkTheme(platform: platform)
    : buildHermesLightTheme(platform: platform);
