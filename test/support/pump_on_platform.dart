import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';

import 'test_localizations.dart';

Future<void> pumpOnPlatform(
  WidgetTester tester,
  Widget child, {
  required TargetPlatform platform,
  Widget? bottom,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildHermesLightTheme().copyWith(platform: platform),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: padding),
        child: AppThemeScopes(child: app!),
      ),
      home: Scaffold(body: child, bottomNavigationBar: bottom),
    ),
  );
}
