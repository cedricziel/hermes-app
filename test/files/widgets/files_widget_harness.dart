import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

ServerPath serverPath(String text) => ServerPath.tryParse(text)!;

/// Mounts [child] in the app's theme on [platform], in [locale], at
/// [textScale], in a window of [size] logical pixels.
Future<void> pumpFiles(
  WidgetTester tester,
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  Locale locale = const Locale('en'),
  double textScale = 1,
  Size size = const Size(390, 844),
  bool reduceMotion = false,
  Brightness brightness = Brightness.light,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // Built for [platform], so a Mac gets the compact density a real Mac build
  // has: `copyWith(platform:)` would leave the density of the test host.
  final base = brightness == Brightness.dark
      ? buildHermesDarkTheme(platform: platform)
      : buildHermesLightTheme(platform: platform);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: base,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: app!,
      ),
      home: Scaffold(body: child),
    ),
  );
}

/// The localizations of the app's widgets under [locale].
AppLocalizations l10nFor(String languageCode) =>
    lookupAppLocalizations(Locale(languageCode));
