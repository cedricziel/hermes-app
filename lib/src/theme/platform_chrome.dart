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

/// The smallest tap area Material asks for on Android, in logical pixels.
const double kMaterialMinTapTarget = 48;

/// Whether [context] runs on a phone-class platform (iOS or Android) rather
/// than a desktop, so controls take a finger-sized hit area.
bool isTouchPlatform(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.android => true,
      _ => false,
    };

/// The smallest tap area for the platform of [context]: 44 on iOS, 48 on
/// Android, and [desktop] elsewhere.
double minTapTargetOf(BuildContext context, {double desktop = 32}) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.iOS => kAppleMinTapTarget,
      TargetPlatform.android => kMaterialMinTapTarget,
      _ => desktop,
    };

/// Whether [context] runs on Android specifically, not on Windows or Linux,
/// which share [PlatformChrome.material] but keep desktop sizes.
bool isAndroid(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.android;
