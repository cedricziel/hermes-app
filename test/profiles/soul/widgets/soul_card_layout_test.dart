import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_editor.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_page_layout.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_save_actions.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Widget _app(
  Widget body, {
  bool dark = false,
  Locale? locale,
  double scale = 1,
}) => MaterialApp(
  theme: dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: locale,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: body)),
);

SoulEditor _editor(
  SoulTextController controller, {
  FocusNode? focusNode,
  bool expands = false,
}) => SoulEditor(
  controller: controller,
  profile: 'work',
  focusNode: focusNode,
  expands: expands,
  footerAction: SoulSaveActions.revertButton(
    dirty: true,
    busy: false,
    onRevert: () {},
  ),
);

Rect _card(WidgetTester tester) => tester.getRect(
  find
      .ancestor(of: find.byType(TextField), matching: find.byType(DecoratedBox))
      .first,
);

void main() {
  group('the card divider', () {
    for (final dark in [false, true]) {
      testWidgets('differs from the card fill (${dark ? 'dark' : 'light'})', (
        tester,
      ) async {
        final controller = SoulTextController(text: 'You are Mara.');
        addTearDown(controller.dispose);
        await tester.pumpWidget(_app(_editor(controller), dark: dark));
        final box = tester.widget<DecoratedBox>(
          find
              .ancestor(
                of: find.byType(TextField),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final fill = (box.decoration as BoxDecoration).color;
        final divider = tester.widget<Divider>(
          find.descendant(
            of: find.byWidget(box),
            matching: find.byType(Divider),
          ),
        );
        expect(fill, isNotNull);
        expect(divider.color, isNot(fill));
      });
    }
  });

  group('the footer count', () {
    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
        testWidgets('wrapped at 3x it sits at the trailing edge '
            '($locale, $dir)', (tester) async {
          final controller = SoulTextController(text: 'You are Mara.');
          addTearDown(controller.dispose);
          await tester.pumpWidget(
            _app(
              Directionality(
                textDirection: dir,
                child: SizedBox(width: 360, child: _editor(controller)),
              ),
              locale: locale,
              scale: 3,
            ),
          );
          final card = _card(tester);
          final count = tester.getRect(
            find.textContaining(RegExp(r'\d+ (char|Zeich)')),
          );
          final revert = tester.getRect(find.byType(TextButton));
          // Wrapped: the count is on its own line below Revert.
          expect(count.top, greaterThanOrEqualTo(revert.bottom - 0.5));
          const pad = 16.0;
          if (dir == TextDirection.ltr) {
            expect(count.right, closeTo(card.right - pad, 1));
          } else {
            expect(count.left, closeTo(card.left + pad, 1));
          }
        });
      }
    }
  });

  group('the page layout', () {
    testWidgets('a banner coming and going keeps the editor state, focus', (
      tester,
    ) async {
      final controller = SoulTextController(text: 'You are Mara.');
      addTearDown(controller.dispose);
      final node = FocusNode();
      addTearDown(node.dispose);
      Widget page({Widget? banner}) => _app(
        SizedBox(
          height: 700,
          child: SoulPageLayout(
            banner: banner,
            editor: _editor(controller, focusNode: node, expands: true),
          ),
        ),
      );
      await tester.pumpWidget(page());
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final state = tester.state<EditableTextState>(find.byType(EditableText));
      expect(node.hasFocus, isTrue);

      await tester.pumpWidget(page(banner: const Text('Paused')));
      expect(find.text('Paused'), findsOneWidget);
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(state),
      );
      expect(node.hasFocus, isTrue);

      await tester.pumpWidget(page());
      expect(find.text('Paused'), findsNothing);
      expect(
        tester.state<EditableTextState>(find.byType(EditableText)),
        same(state),
      );
      expect(node.hasFocus, isTrue);
    });
  });
}
