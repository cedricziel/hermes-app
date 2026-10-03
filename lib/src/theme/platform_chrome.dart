import 'package:flutter/material.dart';

/// Which platform's conventions a screen follows for bars, controls, sheets
/// and hit targets. Apple platforms follow the Human Interface Guidelines;
/// everything else stays Material.
enum PlatformChrome {
  material,
  ios,
  macos;

  bool get isApple => this != material;
}

/// The chrome for [context], read from [ThemeData.platform] so tests can
/// switch it with `ThemeData(platform: ...)`.
PlatformChrome platformChromeOf(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.iOS => PlatformChrome.ios,
      TargetPlatform.macOS => PlatformChrome.macos,
      _ => PlatformChrome.material,
    };

/// The smallest tap area on iOS and iPadOS, in logical pixels.
const double kAppleMinTapTarget = 44;

/// The height of an iOS navigation bar, without the status bar.
const double kAppleNavBarHeight = 44;
