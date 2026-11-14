import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/generated/app_localizations.dart';
import 'package:hermes_app/src/chat/subagents/widgets/confirm_stop_agent.dart';

import '../../widgetbook/host.dart';

void main() {
  testWidgets('a dialog follows an iOS caller theme under the root navigator', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Theme(
          data: ThemeData(platform: TargetPlatform.iOS),
          child: Builder(
            builder: (c) => openOnShow((c) => confirmStopAgent(c, goal: 'x')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
  });
}
