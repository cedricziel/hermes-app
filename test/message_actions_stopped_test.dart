import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/message_actions.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_localizations.dart';
import 'support/tooltip_finder.dart';

/// A stopped reply says so in the screen's language, and the label with all
/// five actions fits a 320 pt screen at the largest text size.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    double scale = 1,
    Locale locale = const Locale('en'),
    double width = 320,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      locale: locale,
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: MessageActions(
              text: 'The build finished.',
              stopped: true,
              onRetry: () {},
              onEdit: () {},
              onBranch: () {},
              readAloud: ReadAloudState.idle,
              onReadAloud: () {},
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('the label is German on a German screen', (tester) async {
    await pump(tester, locale: const Locale('de'));

    expect(find.text('Gestoppt'), findsOneWidget);
    expect(find.text('Stopped'), findsNothing);
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('at ${scale}x text on 320 pt nothing overflows, the label '
        'keeps its whole word and every action stays inside the screen', (
      tester,
    ) async {
      await pump(tester, scale: scale);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Stopped'),
      );
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5,
        ),
      );
      for (final label in [
        'Copy',
        'Read aloud',
        'Try again',
        'Edit prompt',
        'Branch in new chat',
      ]) {
        final action = find.tooltip(label);
        expect(action, findsOneWidget, reason: label);
        expect(
          tester.getTopRight(action).dx,
          lessThanOrEqualTo(320),
          reason: label,
        );
        expect(tester.getTopLeft(action).dx, greaterThanOrEqualTo(0));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
