import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

/// The smallest target on each platform: 44 pt on iOS, 48 dp on Android, 28 pt
/// on a Mac.
const soulTargets = {
  TargetPlatform.iOS: 44.0,
  TargetPlatform.android: 48.0,
  TargetPlatform.macOS: 28.0,
};

Widget soulHost(
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  Locale? locale,
  bool dark = false,
  TextScaler? textScaler,
}) => MaterialApp(
  theme: dark
      ? buildHermesDarkTheme(platform: platform)
      : buildHermesLightTheme(platform: platform),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: locale,
  builder: textScaler == null
      ? null
      : (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Future<void> pumpSoul(
  WidgetTester tester,
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  Locale? locale,
  TextScaler? textScaler,
}) => tester.pumpWidget(
  soulHost(child, platform: platform, locale: locale, textScaler: textScaler),
);
