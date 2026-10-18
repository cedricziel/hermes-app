import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/new_chat_fab.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/accessibility.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'New chat is named and tappable in ${dark ? 'dark' : 'light'}',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark
                ? buildHermesDarkTheme(platform: TargetPlatform.iOS)
                : buildHermesLightTheme(platform: TargetPlatform.iOS),
            home: Scaffold(
              floatingActionButton: NewChatFab(onPressed: () => taps++),
            ),
          ),
        );

        final button = find.byType(FloatingActionButton);
        expect(tester.getSemantics(button), namedButton('New chat'));
        expect(tester.getSize(button), const Size(56, 56));
        expect(tester, meetsGuideline(iOSTapTargetGuideline));
        expect(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.tap(button);
        expect(taps, 1);
        semantics.dispose();
      },
    );
  }
}
