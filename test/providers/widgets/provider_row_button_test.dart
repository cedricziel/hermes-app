import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/providers/widgets/provider_row_actions.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

void main() {
  for (final (platform, height) in [
    (TargetPlatform.macOS, 28.0),
    (TargetPlatform.iOS, 44.0),
    (TargetPlatform.android, 48.0),
  ]) {
    for (final (name, filled, outlined) in [
      ('filled', true, false),
      ('outlined', false, true),
      ('text', false, false),
    ]) {
      testWidgets('a $name button is at least $height tall on $platform', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesLightTheme(platform: platform),
            home: Scaffold(
              body: Center(
                child: ProviderRowButton(
                  label: 'Connect',
                  filled: filled,
                  outlined: outlined,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );

        expect(
          tester.getSize(find.byType(ProviderRowButton)).height,
          greaterThanOrEqualTo(height),
        );
        expect(
          tester
              .getSize(
                find.descendant(
                  of: find.byType(ProviderRowButton),
                  matching: find.byWidgetPredicate(
                    (w) => w is ButtonStyleButton,
                  ),
                ),
              )
              .height,
          greaterThanOrEqualTo(height),
        );
      });
    }
  }
}
