import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

/// The smallest target on each platform: 44 pt on iOS, 48 dp on Android, 28 pt
/// on a Mac.
const waTargets = {
  TargetPlatform.iOS: 44.0,
  TargetPlatform.android: 48.0,
  TargetPlatform.macOS: 28.0,
};

/// An invented code text. It encodes nothing.
const waPayload =
    'DEMO-NOT-A-REAL-QR,2@invented-segment-one-0001,'
    'invented-segment-two-0002==,invented-segment-three-0003=';

Widget waHost(
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  Locale? locale,
  bool dark = false,
  TextScaler? textScaler,
  bool scroll = true,
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
  home: Scaffold(body: scroll ? SingleChildScrollView(child: child) : child),
);

Future<void> pumpWa(
  WidgetTester tester,
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  Locale? locale,
  bool dark = false,
  TextScaler? textScaler,
  bool scroll = true,
}) => tester.pumpWidget(
  waHost(
    child,
    platform: platform,
    locale: locale,
    dark: dark,
    textScaler: textScaler,
    scroll: scroll,
  ),
);
