import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/profiles/soul/widgets/soul_editor.dart';
import 'package:hermes_app/src/widgets/grouped_list.dart';
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
        testWidgets('wrapped at 2x it sits at the trailing edge '
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
              scale: 2,
            ),
          );
          final card = _card(tester);
          final countFinder = find.textContaining(RegExp(r'\d+ (char|Zeich)'));
          final box = tester.getRect(countFinder);
          // The glyphs, not the Text's box: a Text that wrapped itself is as
          // wide as the card and ends at the trailing edge wherever it sits.
          final paragraph = tester.renderObject<RenderParagraph>(countFinder);
          final glyphs = paragraph
              .getBoxesForSelection(
                TextSelection(
                  baseOffset: 0,
                  extentOffset: paragraph.text.toPlainText().length,
                ),
              )
              .map((b) => b.toRect().shift(box.topLeft))
              .reduce((a, b) => a.expandToInclude(b));
          // A line's trailing space hangs past the paragraph's edge.
          final count = Rect.fromLTRB(
            math.max(glyphs.left, box.left),
            box.top,
            math.min(glyphs.right, box.right),
            box.bottom,
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

  group('the footer size', () {
    for (final locale in const [Locale('en'), Locale('de')]) {
      for (final dir in [TextDirection.ltr, TextDirection.rtl]) {
        for (final scale in [2.0, 3.0]) {
          testWidgets('IntrinsicHeight matches the real height '
              '($locale, $dir, ${scale}x)', (tester) async {
            final controller = SoulTextController(text: 'You are Mara.');
            addTearDown(controller.dispose);
            final key = GlobalKey();
            await tester.pumpWidget(
              _app(
                Directionality(
                  textDirection: dir,
                  child: Center(
                    child: SizedBox(
                      width: 360,
                      child: IntrinsicHeight(
                        child: KeyedSubtree(
                          key: key,
                          child: _editor(controller),
                        ),
                      ),
                    ),
                  ),
                ),
                locale: locale,
                scale: scale,
              ),
            );
            expect(tester.takeException(), isNull);
            final box = tester.renderObject<RenderBox>(find.byKey(key));
            final real = box.size.height;
            expect(box.getMinIntrinsicHeight(360), closeTo(real, 0.5));
            expect(box.getMaxIntrinsicHeight(360), closeTo(real, 0.5));
          });
        }
      }
    }

    testWidgets('reports a width for intrinsic-width parents', (tester) async {
      final controller = SoulTextController(text: 'You are Mara.');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(Center(child: SizedBox(width: 360, child: _editor(controller)))),
      );
      final footer = tester.renderObject<RenderBox>(
        find.descendant(
          of: find.byType(SoulEditor),
          matching: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_FooterRow',
          ),
        ),
      );
      expect(footer.getMaxIntrinsicWidth(double.infinity), greaterThan(0));
      expect(
        footer.getMinIntrinsicWidth(double.infinity),
        lessThanOrEqualTo(footer.getMaxIntrinsicWidth(double.infinity)),
      );
    });
  });

  group('the page layout', () {
    for (final locale in const [Locale('en'), Locale('de')]) {
      testWidgets('keeps twelve lines at 3x, footer wrapped ($locale)', (
        tester,
      ) async {
        final controller = SoulTextController(text: 'You are Mara.');
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _app(
            SizedBox(
              width: 360,
              height: 800,
              child: SoulPageLayout(editor: _editor(controller, expands: true)),
            ),
            locale: locale,
            scale: 3,
          ),
        );
        expect(tester.takeException(), isNull);
        final context = tester.element(find.byType(TextField));
        final line =
            MediaQuery.textScalerOf(context)
                .scale(GroupedMetrics.of(context).titleSize) *
            1.35;
        final field = tester.getSize(find.byType(TextField));
        expect(field.height, greaterThanOrEqualTo(line * 12 - 0.5));
      });
    }

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
