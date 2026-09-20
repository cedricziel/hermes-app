import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/mock_chat_data.dart';
import 'package:hermes_app/src/chat/widgets/welcome_view.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  Future<double> cardWidth(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(body: WelcomeView(greetingName: null, onPick: (_) {})),
      ),
    );
    return tester
        .getSize(
          find.ancestor(
            of: find.text(kStarterPrompts.first),
            matching: find.byType(InkWell),
          ),
        )
        .width;
  }

  testWidgets('starter prompts fill the column on a phone', (tester) async {
    expect(await cardWidth(tester, 390), 390 - 48);
  });

  testWidgets('starter prompts sit two to a row on a wide screen', (
    tester,
  ) async {
    expect(await cardWidth(tester, 1200), 290);
  });
}
