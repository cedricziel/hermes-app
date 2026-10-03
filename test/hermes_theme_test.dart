import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  for (final (name, theme) in [
    ('light', buildHermesLightTheme()),
    ('dark', buildHermesDarkTheme()),
  ]) {
    test('$name: a plain text field has a visible outline and padding', () {
      final input = theme.inputDecorationTheme;

      expect(input.border, isA<OutlineInputBorder>());
      expect(input.border!.borderSide.color, theme.colorScheme.outline);
      expect(input.focusedBorder, isA<OutlineInputBorder>());
      expect(input.contentPadding, isNot(EdgeInsets.zero));
    });
  }

  for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
    for (final actions in [0, 1, 3]) {
      testWidgets(
        'on ${platform.name}, a title with $actions actions starts at the left',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHermesLightTheme().copyWith(platform: platform),
              home: Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('Schedules'),
                  actions: [
                    for (var i = 0; i < actions; i++)
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.refresh),
                      ),
                  ],
                ),
              ),
            ),
          );

          expect(
            tester.getTopLeft(find.text('Schedules')).dx,
            NavigationToolbar.kMiddleSpacing,
          );
        },
      );
    }
  }
}
