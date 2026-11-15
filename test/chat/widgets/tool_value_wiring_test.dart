import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/tool_value_budget.dart';
import 'package:hermes_app/src/chat/tool_value_language.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_hidden_chars.dart';
import 'package:hermes_app/src/chat/widgets/tool_json_tree.dart';
import 'package:hermes_app/src/chat/widgets/tool_value_view.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

String _object(int keys) => jsonEncode({
  for (var i = 0; i < keys; i++) 'key_$i': i.isEven ? 'value $i' : i,
});

Widget _host(Widget child, {bool dark = false, double width = 360}) =>
    MaterialApp(
      theme: dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

int _elements(WidgetTester tester, Finder within) => find
    .descendant(
      of: within,
      matching: find.byWidgetPredicate((_) => true),
      skipOffstage: false,
    )
    .evaluate()
    .length;

ToolCall _call(String result, {Map<String, Object?>? args}) =>
    ToolCall(name: 'custom', summary: '', args: args, result: result);

void main() {
  setUp(() => debugToolValueParses = 0);

  // Heights measured on origin/main with the same fixtures: the collapsed
  // card is exactly as it was, on every platform.
  const mainCollapsed = {
    TargetPlatform.iOS: 46.0,
    TargetPlatform.android: 38.0,
    TargetPlatform.macOS: 38.0,
    TargetPlatform.windows: 38.0,
  };
  for (final MapEntry(key: platform, value: collapsed)
      in mainCollapsed.entries) {
    testWidgets('the collapsed card is as high as on main ($platform)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme().copyWith(platform: platform),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 600,
                  child: ToolCallCard(call: _call(_object(5))),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(ToolCallCard)).height, collapsed);
    });
  }

  // The label row is as high as the tap area and no higher.
  const rowHeights = {
    TargetPlatform.iOS: 44.0,
    TargetPlatform.android: 48.0,
    TargetPlatform.macOS: 28.0,
    TargetPlatform.windows: 48.0,
    TargetPlatform.linux: 48.0,
  };
  for (final MapEntry(key: platform, value: row) in rowHeights.entries) {
    testWidgets('the label row is $row high on $platform', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme().copyWith(platform: platform),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 600,
                child: ToolValuePanel(
                  label: 'Result',
                  text: '{"a": 1}',
                  language: 'json',
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(ToolValueHeader)).height, row);
    });
  }

  testWidgets('a collapsed card builds and parses no value view', (
    tester,
  ) async {
    final call = _call(_object(70), args: {'a': 1, 'b': _object(70)});
    await tester.pumpWidget(_host(ToolCallCard(call: call)));
    expect(find.byType(ToolValuePanel), findsNothing);
    expect(find.byType(ToolValueView), findsNothing);
    expect(find.byType(ToolJsonView), findsNothing);
    expect(debugToolValueParses, 0, reason: 'nothing is parsed while closed');
    // The header alone is a handful of widgets.
    final closed = _elements(tester, find.byType(ToolCallCard));
    expect(closed, lessThan(100));
  });

  testWidgets('opening a card with a 70-key object builds a bounded view', (
    tester,
  ) async {
    await tester.pumpWidget(_host(ToolCallCard(call: _call(_object(70)))));
    final closed = _elements(tester, find.byType(ToolCallCard));
    await tester.tap(find.text('custom'));
    await tester.pumpAndSettle();
    final text = _elements(tester, find.byType(ToolCallCard));
    debugPrint('70 keys: closed $closed, open as text $text elements');
    expect(find.byType(ToolValueView), findsOneWidget);
    expect(find.byType(ToolJsonTree), findsNothing, reason: 'text by default');
    expect(debugToolValueParses, greaterThan(0));

    await tester.tap(find.text('Tree'));
    await tester.pumpAndSettle();
    final tree = _elements(tester, find.byType(ToolCallCard));
    debugPrint('70 keys: open as tree $tree elements');
    final rows = find.descendant(
      of: find.byType(ToolJsonTree),
      matching: find.byType(Text),
    );
    debugPrint('70 keys: ${rows.evaluate().length} tree rows built of 70');
    expect(rows.evaluate().length, lessThan(15));
    expect(text, lessThan(_kTextBound));
    expect(tree, lessThan(_kTreeBound));
  });

  testWidgets('a running call is plain and never coloured', (tester) async {
    final call = ToolCall(
      name: 'custom',
      summary: '',
      status: ToolCallStatus.running,
      result: _object(10),
    );
    await tester.pumpWidget(
      _host(ToolCallCard(call: call, initiallyOpen: true)),
    );
    expect(find.byKey(const ValueKey('tool-json-toggle')), findsNothing);
    expect(find.byKey(const ValueKey('tool-value-tag')), findsNothing);
  });

  group('the chat-wide colouring budget', () {
    testWidgets('the budget grants, refuses and gives back', (tester) async {
      final budget = ToolValueBudget(maxChars: 100);
      final a = Object();
      final b = Object();
      expect(budget.admit(a, 60), isTrue);
      expect(budget.admit(b, 60), isFalse);
      expect(budget.admit(a, 90), isTrue, reason: 'judged in place of itself');
      budget.release(a);
      expect(budget.admit(b, 60), isTrue);
      expect(budget.used, 60);
      expect(kToolValueColourBudgetChars, 100000);
    });

    testWidgets('texts over the shared budget stay plain and say so', (
      tester,
    ) async {
      final budget = ToolValueBudget(maxChars: 3000);
      String big(int i) => _object(100); // about 1.6 KB each
      final cards = [
        for (var i = 0; i < 4; i++)
          ToolCallCard(
            key: ValueKey(i),
            call: ToolCall(name: 'tool$i', summary: '', result: big(i)),
            initiallyOpen: true,
          ),
      ];
      await tester.pumpWidget(
        _host(
          ToolValueBudgetScope(
            budget: budget,
            child: Column(children: cards),
          ),
        ),
      );
      // One 1.6 KB text fits the 3 KB budget, the others do not.
      expect(find.byKey(const ValueKey('tool-value-notice')), findsNWidgets(3));
      expect(
        find.text(
          'Not coloured while many long texts are open. Shown as plain text.',
        ),
        findsNWidgets(3),
      );
      expect(budget.holders, 1);
      // Closing the card that holds a share gives it back.
      await tester.pumpWidget(_host(const SizedBox()));
      expect(budget.holders, 0);
    });

    testWidgets('without a budget a text is coloured within its own limits', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(ToolCallCard(call: _call(_object(100)), initiallyOpen: true)),
      );
      expect(find.byKey(const ValueKey('tool-value-notice')), findsNothing);
    });
  });

  group('the label row and notices (canvas fixes)', () {
    testWidgets('over 512 KB the text is plain and has no language tag', (
      tester,
    ) async {
      final huge = '{"a": "${'x' * (kToolValueColourMaxChars + 10)}"}';
      await tester.pumpWidget(
        _host(ToolValuePanel(label: 'Result', text: huge, language: 'json')),
      );
      expect(find.byKey(const ValueKey('tool-value-tag')), findsNothing);
      expect(find.byKey(const ValueKey('tool-value-notice')), findsOneWidget);
    });

    testWidgets('the notice is above the body, with an info mark', (
      tester,
    ) async {
      final text = '{"a": "${'x' * (kToolJsonSniffMaxChars + 10)}"}';
      await tester.pumpWidget(
        _host(ToolValuePanel(label: 'Result', text: text, language: 'json')),
      );
      final notice = tester.getRect(
        find.byKey(const ValueKey('tool-value-notice')),
      );
      final body = tester.getRect(find.byType(ToolValueView));
      expect(notice.bottom, lessThanOrEqualTo(body.top));
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel('Too long for the tree view.'),
        findsOneWidget,
      );
      expect(find.byType(ExcludeSemantics), findsWidgets);
      handle.dispose();
    });

    testWidgets(
      'the copy button has no border and says Copied in full colour',
      (tester) async {
        await tester.pumpWidget(
          _host(
            ToolCopyProbe(
              child: ToolValueCopyButton(
                label: 'Copy result',
                onPressed: () {},
                copied: true,
              ),
            ),
          ),
        );
        final box = tester.widget<Container>(
          find.descendant(
            of: find.byKey(const ValueKey('tool-value-copy')),
            matching: find.byType(Container),
          ),
        );
        expect((box.decoration as BoxDecoration).border, isNull);
        final scheme = Theme.of(tester.element(find.text('Copied')))
            .colorScheme;
        expect(
          tester.widget<Text>(find.text('Copied')).style?.color,
          scheme.onSurface,
        );
      },
    );

    testWidgets('code text has ligatures and alternates off', (tester) async {
      expect(
        kToolMonoStyle.fontFeatures,
        containsAll([
          const FontFeature.disable('liga'),
          const FontFeature.disable('calt'),
        ]),
      );
      await tester.pumpWidget(
        _host(const ToolValueView(text: 'a -> b != c', language: 'python')),
      );
      final rich = tester.widget<RichText>(
        find.descendant(
          of: find.byType(ToolValueView),
          matching: find.byType(RichText),
        ),
      );
      final inner = (rich.text as TextSpan).children!.single as TextSpan;
      expect(inner.style?.fontFeatures, kToolMonoStyle.fontFeatures);
    });

    for (final dark in [false, true]) {
      testWidgets(
        'hidden-character text is readable on the card (dark: $dark)',
        (tester) async {
          await tester.pumpWidget(
            _host(
              ToolValueView(text: 'a${String.fromCharCode(0x202E)}b'),
              dark: dark,
            ),
          );
          final context = tester.element(find.byType(HiddenCharBox));
          final scheme = Theme.of(context).colorScheme;
          final text = tester.widget<Text>(
            find.descendant(
              of: find.byType(HiddenCharBox),
              matching: find.byType(Text),
            ),
          );
          final colour = text.style!.color!;
          // The card is the high surface at 40% over the page; a section sits
          // on the card, a screen on the high surface itself.
          final card = Color.alphaBlend(
            scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            scheme.surface,
          );
          for (final ground in [card, scheme.surfaceContainerHighest]) {
            expect(_contrast(colour, ground), greaterThanOrEqualTo(4.5));
          }
        },
      );
    }
  });

  testWidgets('the tree has no root row, indexes, plain counts and guides', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ToolJsonTree(text: '{"list": [10, 20], "o": {"k": {"z": 1}}}'),
      ),
    );
    expect(find.textContaining('2 keys', findRichText: true), findsNothing);
    expect(find.textContaining('{', findRichText: true), findsNothing);
    expect(find.textContaining('0: 10', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('list: 2 items', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(CustomPaint), findsWidgets);
  });
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Gives the copy button the platform metrics it reads.
class ToolCopyProbe extends StatelessWidget {
  const ToolCopyProbe({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

const int _kTextBound = 350;
const int _kTreeBound = 550;
