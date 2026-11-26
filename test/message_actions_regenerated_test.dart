import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/widgets/message_actions.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:material_ui/material_ui.dart';

import 'support/test_localizations.dart';
import 'support/tooltip_finder.dart';

/// The "Regenerated" label keeps its whole word at every text size, on a line
/// above the actions.
void main() {
  Future<void> pump(WidgetTester tester, double scale) => tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
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
            width: 320,
            child: MessageActions(
              text: 'The build finished.',
              regenerated: true,
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

  final label = find.text('Regenerated');

  /// The word is laid out whole: on one line, not cut to an ellipsis.
  void expectWholeWord(WidgetTester tester) {
    final paragraph = tester.renderObject<RenderParagraph>(label);
    expect(
      paragraph.size.width,
      greaterThanOrEqualTo(
        paragraph.getMaxIntrinsicWidth(double.infinity) - 0.5,
      ),
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('at ${scale}x text it keeps its whole word on a line above '
        'the actions', (tester) async {
      await pump(tester, scale);

      expectWholeWord(tester);
      expect(
        tester.getBottomLeft(label).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.tooltip('Copy')).dy),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
