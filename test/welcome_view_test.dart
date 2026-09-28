import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/starter_prompts.dart';
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
        home: Scaffold(
          body: WelcomeView(
            greetingName: null,
            prompts: buildStarterPrompts(const StarterContext()),
            onPick: (_) {},
          ),
        ),
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

  testWidgets('shows each prompt with its source icon and hands a tap back', (
    tester,
  ) async {
    final prompts = buildStarterPrompts(
      const StarterContext(
        failedJob: 'Nightly backup',
        recentChat: StarterChat(id: 't1', title: 'Telegram pairing'),
      ),
    );
    StarterPrompt? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: WelcomeView(
            greetingName: null,
            prompts: prompts,
            onPick: (prompt) => picked = prompt,
          ),
        ),
      ),
    );

    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(InkWell),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data);
    expect(texts, prompts.map((p) => p.text));
    expect(find.byIcon(Icons.schedule), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb_outline), findsNWidgets(2));

    await tester.tap(find.text("Pick up 'Telegram pairing'"));
    expect(picked, same(prompts[1]));
  });

  testWidgets('scrolls to the last starter prompt on a short screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final prompts = buildStarterPrompts(const StarterContext());
    StarterPrompt? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: WelcomeView(
            greetingName: 'Ada',
            prompts: prompts,
            bottomPadding: 120,
            onPick: (prompt) => picked = prompt,
          ),
        ),
      ),
    );

    final last = find.text(prompts.last.label);
    await tester.scrollUntilVisible(last, 100);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(last).dy, lessThan(500 - 120));
    await tester.tap(last);
    expect(picked, same(prompts.last));
  });
}
