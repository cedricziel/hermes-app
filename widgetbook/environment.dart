import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:widgetbook/widgetbook.dart';

/// The looks the catalog offers. `main.dart` turns them into addons and
/// `test/widgetbook_test.dart` builds every use case in each of them, so the
/// two cannot drift apart.
final themes = {
  'Light': buildHermesLightTheme(),
  'Dark': buildHermesDarkTheme(),
};

const phone = ViewportData(
  name: 'Phone',
  width: 390,
  height: 844,
  pixelRatio: 3,
  platform: TargetPlatform.iOS,
);

const desktop = ViewportData(
  name: 'Desktop',
  width: 1000,
  height: 800,
  pixelRatio: 2,
  platform: TargetPlatform.macOS,
);
