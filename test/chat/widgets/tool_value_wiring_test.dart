import 'dart:convert';

import 'package:material_ui/material_ui.dart';
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

import '../../support/test_localizations.dart';

String _object(int keys) => jsonEncode({
  for (var i = 0; i < keys; i++) 'key_$i': i.isEven ? 'value $i' : i,
});

Widget _host(Widget child, {bool dark = false, double width = 360}) =>
    MaterialApp(
      theme: dark ? buildHermesDarkTheme() : buildHermesLightTheme(),
      localizationsDelegates: kTestLocalizationsDelegates,
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
          theme: buildHermesLightTheme(platform: platform),
          localizationsDelegates: kTestLocalizationsDelegates,
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
          theme: buildHermesLightTheme(platform: platform),
          localizationsDelegates: kTestLocalizationsDelegates,
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
      // Nothing coloured, nothing tagged: only the card that was coloured has
      // the language tag.
      expect(find.byKey(const ValueKey('tool-value-tag')), findsOneWidget);
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

  group('structured arguments', () {
    Widget host(ToolCall call, {ToolValueBudget? budget}) {
      final card = ToolCallCard(call: call, initiallyOpen: true);
      return _host(
        budget == null
            ? card
            : ToolValueBudgetScope(budget: budget, child: card),
      );
    }

    testWidgets('follow the call when its arguments change', (tester) async {
      ToolCall call(String v) => ToolCall(
        name: 'custom',
        summary: '',
        args: {
          'payload': {'a': v},
        },
      );
      await tester.pumpWidget(host(call('OLDVALUE')));
      expect(
        find.textContaining('OLDVALUE', findRichText: true),
        findsOneWidget,
      );
      await tester.pumpWidget(host(call('NEWVALUE')));
      expect(
        find.textContaining('NEWVALUE', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('OLDVALUE', findRichText: true), findsNothing);
    });

    testWidgets('an unchanged value is not parsed again on a rebuild', (
      tester,
    ) async {
      ToolCall call() => ToolCall(
        name: 'custom',
        summary: '',
        args: {'payload': List.generate(20, (i) => 'item $i')},
      );
      await tester.pumpWidget(host(call()));
      final parses = debugToolValueParses;
      expect(parses, greaterThan(0));
      await tester.pumpWidget(host(call()));
      expect(debugToolValueParses, parses);
    });

    testWidgets('share the colouring budget and say so when it is spent', (
      tester,
    ) async {
      final budget = ToolValueBudget(maxChars: 10);
      await tester.pumpWidget(
        host(
          ToolCall(
            name: 'custom',
            summary: '',
            args: {'payload': List.generate(50, (i) => 'item $i')},
          ),
          budget: budget,
        ),
      );
      expect(budget.used, 0);
      expect(find.byKey(const ValueKey('tool-value-notice')), findsOneWidget);

      final roomy = ToolValueBudget();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        host(
          ToolCall(
            name: 'custom',
            summary: '',
            args: {'payload': List.generate(50, (i) => 'item $i')},
          ),
          budget: roomy,
        ),
      );
      expect(roomy.holders, 1);
      expect(find.byKey(const ValueKey('tool-value-notice')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(roomy.holders, 0);
    });
  });

  testWidgets('a notice sits between the label row and the body', (
    tester,
  ) async {
    final text = '{"a": "${'x' * (kToolJsonSniffMaxChars + 10)}"}';
    await tester.pumpWidget(
      _host(ToolValuePanel(label: 'Result', text: text, language: 'json')),
    );
    final header = tester.getRect(find.byType(ToolValueHeader));
    final notice = tester.getRect(
      find.byKey(const ValueKey('tool-value-notice')),
    );
    final body = tester.getRect(find.byType(ToolValueView));
    expect(notice.top, greaterThanOrEqualTo(header.bottom));
    expect(notice.bottom, lessThanOrEqualTo(body.top));
  });

  testWidgets('a tree-offering text has its notice below the switch row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ToolValueBudgetScope(
          budget: ToolValueBudget(maxChars: 10),
          child: ToolValuePanel(
            label: 'Result',
            text: _object(20),
            language: 'json',
          ),
        ),
      ),
    );
    final header = tester.getRect(find.byType(ToolValueHeader));
    final notice = tester.getRect(
      find.byKey(const ValueKey('tool-value-notice')),
    );
    expect(notice.top, greaterThanOrEqualTo(header.bottom));
    expect(
      tester.getRect(find.byType(ToolValueView)).top,
      greaterThanOrEqualTo(notice.bottom),
    );
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

    testWidgets(
      'the notice is between the label row and the body, with an info mark',
      (tester) async {
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
      },
    );

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
    String plain(RichText w) => w.text.toPlainText().replaceAll('\uFFFC', ' ');
    final rows = tester
        .widgetList<RichText>(
          find.descendant(
            of: find.byType(ToolJsonTree),
            matching: find.byType(RichText),
          ),
        )
        .map(plain)
        .toList();
    expect(rows, contains('0 10'), reason: 'an index has no colon');
    expect(rows, contains('list: 2 items'), reason: 'a key keeps its colon');
    expect(rows.any((r) => r.contains('0: ')), isFalse);
    // The count is in the UI font, not the code font of the row.
    TextSpan? count;
    for (final row in tester.widgetList<RichText>(
      find.descendant(
        of: find.byType(ToolJsonTree),
        matching: find.byType(RichText),
      ),
    )) {
      row.text.visitChildren((span) {
        if (span is TextSpan && span.text == '2 items') count = span;
        return true;
      });
    }
    expect(count, isNotNull);
    expect(count!.style?.inherit, isFalse);
    expect(count!.style?.fontFamily, isNot('monospace'));
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
