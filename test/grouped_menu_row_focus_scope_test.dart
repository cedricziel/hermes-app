import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/material_ui_bridge.dart';
import 'package:hermes_app/src/widgets/grouped_form.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';

import 'support/test_localizations.dart';

/// Where the keyboard focus ring does not show on a Mac `GroupedMenuRow`: the
/// focus rests on something other than a row (the route's focus scope, an outer
/// `Focus`), and a key is pressed. These cases focus that on purpose, so they
/// call `requestFocus` and are not geometry cases (the shape of the ring is in
/// `focus_ring_geometry_test.dart`, reached by Tab).

final _ringFinder = find.byWidgetPredicate(
  (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
);

Future<void> _pump(
  WidgetTester tester,
  TargetPlatform platform,
  Widget body,
) async {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
  resetFocusRingInput();
  tester.view
    ..physicalSize = const Size(800, 1400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildHermesLightTheme(platform: platform),
      builder: (_, child) => AppThemeScopes(child: child!),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(padding: const EdgeInsets.all(24), child: body),
        ),
      ),
    ),
  );
}

void main() {
  setUp(resetFocusRingInput);

  group('two Mac GroupedMenuRows in one section: only the focused one', () {
    // Reachable by requestFocus, not by Tab, so Tab starts at the first row.
    FocusNode outerNode() =>
        FocusNode(debugLabel: 'outer', skipTraversal: true);

    Future<void> pumpTwo(WidgetTester tester, FocusNode outer) => _pump(
      tester,
      TargetPlatform.macOS,
      Focus(
        focusNode: outer,
        child: SizedBox(
          width: 360,
          child: GroupedSection(
            children: [
              for (final title in ['First', 'Second'])
                GroupedMenuRow<String>(
                  title: title,
                  options: const ['a', 'b'],
                  labelOf: (option) => option,
                  selected: 'a',
                  onSelected: (_) {},
                ),
            ],
          ),
        ),
      ),
    );

    /// The pop-up face of the row at [index], round its value text.
    Finder faceOf(int index) => find
        .ancestor(of: find.text('a').at(index), matching: find.byType(Material))
        .first;

    testWidgets('the route scope focused and a key pressed: no ring', (
      tester,
    ) async {
      await pumpTwo(tester, outerNode());
      FocusScope.of(tester.element(find.text('First'))).requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(_ringFinder, findsNothing);
    });

    testWidgets('a plain Focus above the rows focused: no ring', (
      tester,
    ) async {
      final outer = outerNode();
      addTearDown(outer.dispose);
      await pumpTwo(tester, outer);
      outer.requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus, outer);
      expect(_ringFinder, findsNothing);
    });

    testWidgets('Tab moves the one ring from the first row to the second', (
      tester,
    ) async {
      final outer = outerNode();
      addTearDown(outer.dispose);
      await pumpTwo(tester, outer);
      for (final (index, title) in ['First', 'Second'].indexed) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(_ringFinder, findsOneWidget, reason: '$title is focused');
        expect(
          tester.getRect(_ringFinder),
          tester.getRect(faceOf(index)),
          reason: 'the ring is on $title',
        );
      }
    });
  });
}
