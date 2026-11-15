import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';
import 'package:hermes_app/src/chat/tool_value_language.dart';
import 'package:hermes_app/src/chat/widgets/tool_hidden_chars.dart';
import 'package:hermes_app/src/chat/widgets/tool_value_view.dart';
import 'package:hermes_app/src/files/code_highlight.dart';
import 'package:hermes_app/src/theme/hermes_code_colors.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import '../../support/screenshot_recorder.dart';

Widget _host(
  Widget child, {
  TargetPlatform? platform,
  double textScale = 1,
  Locale? locale,
  double width = 390,
  bool realFonts = false,
}) {
  final light = buildHermesLightTheme();
  final base = realFonts ? withScreenshotFont(light) : light;
  return MaterialApp(
    theme: platform == null ? base : base.copyWith(platform: platform),
    themeAnimationDuration: Duration.zero,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  );
}

/// The spans of the one selectable text on screen.
List<InlineSpan> _spans(WidgetTester tester) {
  final text = tester.widget<SelectableText>(find.byType(SelectableText));
  return text.textSpan!.children!;
}

String _shown(List<InlineSpan> spans) =>
    spans.whereType<TextSpan>().map((s) => s.text).join();

bool _coloured(List<InlineSpan> spans) =>
    spans.whereType<TextSpan>().any((span) => span.style?.color != null);

Future<void> _workersGone(WidgetTester tester) => tester.runAsync(() async {
  for (var i = 0; i < 100 && CodeHighlightWorker.alive > 0; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
});

/// What reaches the clipboard and the screen reader while [body] runs.
class _Channels {
  String? copied;
  final announced = <String>[];
}

_Channels _listen(WidgetTester tester) {
  final channels = _Channels();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        channels.copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    },
  );
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      if (message is Map && message['type'] == 'announce') {
        channels.announced.add((message['data'] as Map)['message'] as String);
      }
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      null,
    );
  });
  return channels;
}

final _large = List.generate(
  200,
  (i) => 'def f$i(x):\n    return "v$i" + x\n',
).join('\n');

const _python = 'def hello(name):\n    return "hi " + name\n';
const _json = '{"a": 1, "b": [true, null]}';
const _toggle = ValueKey('tool-json-toggle');
const _copyKey = ValueKey('tool-value-copy');
const _treeKey = ValueKey('tool-json-tree');
const _noticeKey = ValueKey('tool-value-notice');
const _tagKey = ValueKey('tool-value-tag');

String _char(int code) => String.fromCharCode(code);

/// The semantics label of the [index]th hidden-character box.
String _boxLabel(WidgetTester tester, int index) =>
    tester.getSemantics(find.byType(HiddenCharBox).at(index)).label;

Finder _label(String label) => find.bySemanticsLabel(label);

/// A row of the tree, whether or not the 220 pt box has scrolled it into view.
Finder _rich(String text) =>
    find.textContaining(text, findRichText: true, skipOffstage: false);

void main() {
  group('ToolValueView', () {
    testWidgets('colours a settled text and keeps its characters', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const ToolValueView(text: _python, language: 'python')),
      );
      final spans = _spans(tester);
      expect(_coloured(spans), isTrue);
      expect(_shown(spans), _python);
    });

    testWidgets('reads its colours from the code palette', (tester) async {
      await tester.pumpWidget(
        _host(
          const ToolValueView(text: '{"a": 1, "b": "x"}', language: 'json'),
        ),
      );
      final palette = tester.element(find.byType(SelectableText)).codeColors;
      Color? colourOf(String text) =>
          _spans(tester)
              .whereType<TextSpan>()
              .firstWhere((s) => s.text == text)
              .style
              ?.color;
      expect(colourOf('"a"'), palette.key);
      expect(colourOf('1'), palette.number);
      expect(colourOf('"x"'), palette.string);
      expect(palette.key, isNot(palette.string));
    });

    testWidgets('shows a running call plain, then colours when it settles', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ToolValueView(
            text: _python,
            language: 'python',
            settled: false,
          ),
        ),
      );
      expect(_shown(_spans(tester)), _python);
      expect(_coloured(_spans(tester)), isFalse);
      await tester.pumpWidget(
        _host(const ToolValueView(text: _python, language: 'python')),
      );
      expect(_coloured(_spans(tester)), isTrue);
    });

    testWidgets('boxes hidden characters in coloured and plain text', (
      tester,
    ) async {
      final text = 'a${_char(0x202E)}b${_char(0x1B)}c${_char(0xFEFF)}d';
      for (final settled in [true, false]) {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(ToolValueView(text: text, language: 'bash', settled: settled)),
        );
        final spans = _spans(tester);
        expect(_shown(spans), 'abcd', reason: 'settled: $settled');
        expect(find.byType(HiddenCharBox), findsNWidgets(3));
        for (final code in ['U+202E', 'U+001B', 'U+FEFF']) {
          expect(find.text(code), findsOneWidget);
        }
        expect(
          // The boxes are one run of the text for a screen reader.
          _boxLabel(tester, 0),
          [
            'hidden character U+202E',
            'hidden character U+001B',
            'hidden character U+FEFF',
          ].join('\n'),
        );
        handle.dispose();
      }
    });

    testWidgets('boxes sit in the text and carry the subtle border', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(ToolValueView(text: 'x${_char(0x200B)}y', language: 'bash')),
      );
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(HiddenCharBox),
          matching: find.byType(Container),
        ),
      );
      final decoration = box.decoration! as BoxDecoration;
      final subtle = tester
          .element(find.byType(HiddenCharBox))
          .hermesColors
          .subtleText;
      expect((decoration.border! as Border).top.color, subtle);
      expect((decoration.border! as Border).top.width, greaterThan(0));
    });

    testWidgets('tab and line breaks are not hidden; CRLF is one break', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const ToolValueView(text: 'a\tb\r\nc\nd', language: 'bash')),
      );
      expect(find.byType(HiddenCharBox), findsNothing);
      expect(_shown(_spans(tester)), 'a\tb\nc\nd');
      await tester.pumpWidget(
        _host(const ToolValueView(text: 'a\rb', language: 'bash')),
      );
      expect(find.text('U+000D'), findsOneWidget);
    });

    testWidgets('10,000 hidden characters build a bounded number of boxes', (
      tester,
    ) async {
      final text = 'x${_char(0x200B)}' * 10000;
      for (final settled in [true, false]) {
        await tester.pumpWidget(
          _host(ToolValueView(text: text, language: 'bash', settled: settled)),
        );
        expect(tester.takeException(), isNull);
        final spans = _spans(tester);
        expect(
          find.byType(HiddenCharBox).evaluate().length,
          lessThanOrEqualTo(kToolHiddenBoxMax),
        );
        expect(spans.whereType<WidgetSpan>().length, kToolHiddenBoxMax);
        // The rest is plain `<U+200B>` text, in few spans.
        expect(spans.length, lessThan(kToolHiddenBoxMax * 2 + 5));
        final tail = spans.whereType<TextSpan>().last.text!;
        expect(tail, contains('x<U+200B>x<U+200B>'));
        expect(
          '<U+200B>'.allMatches(_shown(spans)).length,
          10000 - kToolHiddenBoxMax,
        );
      }
    });

    testWidgets('a text over the limits stays plain and starts no worker', (
      tester,
    ) async {
      final unbreakable = 'x' * (kCodeHighlightMaxUnbreakable + 1);
      await tester.pumpWidget(
        _host(ToolValueView(text: unbreakable, language: 'python')),
      );
      expect(_coloured(_spans(tester)), isFalse);
      expect(CodeHighlightWorker.alive, 0);
    });

    testWidgets('a large text is coloured off the UI isolate, none is left', (
      tester,
    ) async {
      expect(isInlineSafe(_large), isFalse);
      await tester.pumpWidget(
        _host(ToolValueView(text: _large, language: 'python')),
      );
      expect(_coloured(_spans(tester)), isFalse);
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && !_coloured(_spans(tester)); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      expect(_coloured(_spans(tester)), isTrue);
      await tester.pumpWidget(_host(const SizedBox()));
      await _workersGone(tester);
      expect(CodeHighlightWorker.alive, 0);
    });

    testWidgets('leaving while the worker runs ends it', (tester) async {
      await tester.pumpWidget(
        _host(ToolValueView(text: _large, language: 'python')),
      );
      await tester.pumpWidget(_host(const SizedBox()));
      await _workersGone(tester);
      expect(CodeHighlightWorker.alive, 0);
    });

    testWidgets('a running call never starts a worker', (tester) async {
      await tester.pumpWidget(
        _host(ToolValueView(text: _large, language: 'python', settled: false)),
      );
      expect(CodeHighlightWorker.alive, 0);
      expect(_coloured(_spans(tester)), isFalse);
    });
  });

  group('ToolValuePanel label row', () {
    testWidgets('shows the label and a tag naming the content', (tester) async {
      Future<void> pump(Widget panel) => tester.pumpWidget(_host(panel));
      String? tag() => find.byKey(_tagKey).evaluate().isEmpty
          ? null
          : tester.widget<Text>(find.byKey(_tagKey)).data;

      await pump(
        const ToolValuePanel(label: 'Input', text: _json, language: 'json'),
      );
      expect(find.text('Input'), findsOneWidget);
      expect(tag(), 'JSON');

      await pump(
        const ToolValuePanel(
          label: 'Content',
          text: _python,
          language: 'python',
        ),
      );
      expect(tag(), 'Python');

      await pump(
        const ToolValuePanel(label: 'Result', text: 'x', language: 'dart'),
      );
      expect(tag(), 'Dart');
      await pump(
        const ToolValuePanel(label: 'Result', text: 'x', language: 'bash'),
      );
      expect(tag(), 'Shell');
    });

    testWidgets('plain text, invalid JSON and a running call have no tag', (
      tester,
    ) async {
      for (final panel in const [
        ToolValuePanel(label: 'Output', text: 'done'),
        ToolValuePanel(label: 'Result', text: '{"a": 1', language: 'json'),
        ToolValuePanel(
          label: 'Result',
          text: _json,
          language: 'json',
          settled: false,
        ),
      ]) {
        await tester.pumpWidget(_host(panel));
        expect(find.byKey(_tagKey), findsNothing);
      }
    });

    testWidgets('names the tag in German', (tester) async {
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(
            label: 'Eingabe',
            text: _json,
            language: 'json',
            section: ToolValueSection.input,
          ),
          locale: const Locale('de'),
        ),
      );
      expect(find.text('JSON'), findsOneWidget);
      expect(_rich('Text | Baum'), findsOneWidget);
    });

    testWidgets('fits one row at 1.5x on a phone and wraps from 2x', (
      tester,
    ) async {
      // The test font is as wide as it is tall; the real one decides what
      // fits.
      await tester.runAsync(loadTestFonts);
      Future<(Rect, Rect, Rect)> rects(double scale) async {
        await tester.pumpWidget(
          _host(
            const ToolValuePanel(
              label: 'Result',
              text: _json,
              language: 'json',
            ),
            textScale: scale,
            realFonts: true,
          ),
        );
        return (
          tester.getRect(find.text('Result')),
          tester.getRect(find.byKey(_toggle)),
          tester.getRect(find.byKey(_copyKey)),
        );
      }

      final (label15, toggle15, copy15) = await rects(1.5);
      expect(toggle15.top, lessThan(label15.bottom), reason: 'one row');
      expect(copy15.top, lessThan(label15.bottom));
      expect(copy15.right, lessThanOrEqualTo(390));

      final (label2, toggle2, copy2) = await rects(2.5);
      expect(
        toggle2.top,
        greaterThanOrEqualTo(label2.bottom - 0.5),
        reason: 'under the label',
      );
      expect(copy2.right, lessThanOrEqualTo(390));
      expect(toggle2.right, lessThanOrEqualTo(390));
      expect(tester.takeException(), isNull);
    });

    testWidgets('names the section for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      for (final (section, copy, group) in [
        (ToolValueSection.input, 'Copy input', 'Show input as'),
        (ToolValueSection.result, 'Copy result', 'Show result as'),
        (ToolValueSection.error, 'Copy error', 'Show error as'),
      ]) {
        await tester.pumpWidget(
          _host(
            ToolValuePanel(
              label: 'x',
              text: _json,
              language: 'json',
              section: section,
            ),
          ),
        );
        expect(_label(copy), findsOneWidget);
        expect(
          tester.getSemantics(find.byKey(_toggle)).label,
          startsWith(group),
        );
      }
      handle.dispose();
    });

    testWidgets('a failed call with a JSON body is coloured and has the tree', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(
            label: 'Error',
            text: '{"error": "nope", "code": 404}',
            language: 'json',
            section: ToolValueSection.error,
          ),
        ),
      );
      expect(find.byKey(_toggle), findsOneWidget);
      expect(_coloured(_spans(tester)), isTrue);
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('a plain error text is plain monospace with no switch', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(
            label: 'Error',
            text: 'FileNotFoundError: a.dart',
            section: ToolValueSection.error,
          ),
        ),
      );
      expect(find.byKey(_toggle), findsNothing);
      expect(find.byKey(_tagKey), findsNothing);
      expect(_coloured(_spans(tester)), isFalse);
    });
  });

  group('ToolValuePanel copy', () {
    testWidgets('copies the original, hidden characters and CRLF included', (
      tester,
    ) async {
      final original = 'a${_char(0x202E)}b${_char(0x200B)}\r\nline\rend­';
      final channels = _listen(tester);
      await tester.pumpWidget(
        _host(ToolValuePanel(label: 'Result', text: original)),
      );
      await tester.tap(find.byKey(_copyKey));
      await tester.pump();
      expect(channels.copied, original);
      expect(channels.copied, contains('\r\n'));
      expect(channels.copied, isNot(contains('<U+')));
    });

    testWidgets('copies the same text in the tree view', (tester) async {
      const original = '{\n  "name": "a\\u202eb",\r\n  "n": 1}';
      final channels = _listen(tester);
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(
            label: 'Result',
            text: original,
            language: 'json',
            initiallyTree: true,
          ),
        ),
      );
      expect(find.byKey(_treeKey), findsOneWidget);
      await tester.tap(find.byKey(_copyKey));
      await tester.pump();
      expect(channels.copied, original);
    });

    testWidgets('says Copied for two seconds, then goes back', (tester) async {
      final channels = _listen(tester);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const ToolValuePanel(label: 'Result', text: 'hello')),
      );
      expect(find.text('Copied'), findsNothing);
      expect(_label('Copy result'), findsOneWidget);
      await tester.tap(find.byKey(_copyKey));
      await tester.pump();
      expect(find.text('Copied'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(channels.announced, ['Copied']);

      await tester.pump(const Duration(milliseconds: 1900));
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Copied'), findsNothing);
      expect(_label('Copy result'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a second tap restarts the two seconds', (tester) async {
      _listen(tester);
      await tester.pumpWidget(
        _host(const ToolValuePanel(label: 'Result', text: 'hello')),
      );
      await tester.tap(find.byKey(_copyKey));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.tap(find.byKey(_copyKey));
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Copied'), findsNothing);
    });

    testWidgets('leaving while Copied leaves no timer behind', (tester) async {
      _listen(tester);
      await tester.pumpWidget(
        _host(const ToolValuePanel(label: 'Result', text: 'hello')),
      );
      await tester.tap(find.byKey(_copyKey));
      await tester.pump();
      await tester.pumpWidget(_host(const SizedBox()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('showCopy false leaves the button out', (tester) async {
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(
            label: 'Input',
            text: _json,
            language: 'json',
            showCopy: false,
          ),
        ),
      );
      expect(find.byKey(_copyKey), findsNothing);
      // The switch stays.
      expect(find.byKey(_toggle), findsOneWidget);
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(label: 'Input', text: 'plain', showCopy: false),
        ),
      );
      expect(find.byKey(_copyKey), findsNothing);
      expect(find.text('Input'), findsOneWidget);
    });

    testWidgets('looks 28 pt high (22 on a Mac) in a target of 44, 48, 28', (
      tester,
    ) async {
      for (final (platform, target, look) in [
        (TargetPlatform.iOS, 44.0, 28.0),
        (TargetPlatform.android, 48.0, 28.0),
        (TargetPlatform.macOS, 28.0, 22.0),
        (TargetPlatform.windows, 48.0, 28.0),
        (TargetPlatform.linux, 48.0, 28.0),
      ]) {
        await tester.pumpWidget(
          _host(
            const ToolValuePanel(
              label: 'Result',
              text: _json,
              language: 'json',
            ),
            platform: platform,
          ),
        );
        final area = tester.getSize(find.byKey(_copyKey));
        expect(area.height, target, reason: '$platform height');
        expect(area.width, target, reason: '$platform width');
        final pill = tester.getSize(
          find.descendant(
            of: find.byKey(_copyKey),
            matching: find.byType(Container),
          ),
        );
        expect(pill.height, look, reason: '$platform look');
        final toggle = tester.getSize(find.byKey(_toggle));
        expect(toggle.height, greaterThanOrEqualTo(target));
      }
    });

    testWidgets('the Copied pill widens and keeps the target', (tester) async {
      _listen(tester);
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(label: 'Result', text: 'x'),
          platform: TargetPlatform.iOS,
        ),
      );
      await tester.tap(find.byKey(_copyKey));
      await tester.pump();
      final area = tester.getSize(find.byKey(_copyKey));
      expect(area.height, 44);
      expect(area.width, greaterThan(44));
      expect(area.width, lessThan(160), reason: 'a pill, not the row');
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('ToolValueCopyButton', () {
    testWidgets('draws the Copied state from its flag', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          ToolValueCopyButton(
            label: 'Copy result',
            copied: true,
            onPressed: () => taps++,
          ),
        ),
      );
      expect(find.text('Copied'), findsOneWidget);
      await tester.tap(find.byKey(_copyKey));
      expect(taps, 1);
    });
  });

  group('ToolValuePanel notices', () {
    testWidgets('over 512 KB is plain, says so and has no switch', (
      tester,
    ) async {
      final text = 'x = 1\n' * 90000;
      expect(text.length, greaterThan(kToolValueColourMaxChars));
      await tester.pumpWidget(
        _host(ToolValuePanel(label: 'Result', text: text, language: 'python')),
      );
      expect(
        tester.widget<Text>(find.byKey(_noticeKey)).data,
        'Too long to colour. Shown as plain text.',
      );
      expect(find.byKey(_toggle), findsNothing);
      expect(_coloured(_spans(tester)), isFalse);
      expect(CodeHighlightWorker.alive, 0);
    });

    testWidgets('JSON between 64 KB and 512 KB is flat, no switch, says so', (
      tester,
    ) async {
      final text = '[${List.filled(20000, '"item-0000"').join(',')}]';
      expect(text.length, greaterThan(kToolJsonSniffMaxChars));
      expect(text.length, lessThan(kToolValueColourMaxChars));
      await tester.pumpWidget(
        _host(
          ToolValuePanel(
            label: 'Result',
            text: text,
            language: toolValueLanguage(text),
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.byKey(_noticeKey)).data,
        'Too long for the tree view.',
      );
      expect(find.byKey(_toggle), findsNothing);
      expect(find.byKey(_treeKey), findsNothing);
      expect(tester.widget<Text>(find.byKey(_tagKey)).data, 'JSON');
      await tester.pumpWidget(_host(const SizedBox()));
      await _workersGone(tester);
    });

    testWidgets('deeply nested JSON is flat, no switch, says so', (
      tester,
    ) async {
      final text = '[' * 65 + ']' * 65;
      await tester.pumpWidget(
        _host(ToolValuePanel(label: 'Result', text: text, language: 'json')),
      );
      expect(
        tester.widget<Text>(find.byKey(_noticeKey)).data,
        'Too deeply nested for the tree view.',
      );
      expect(find.byKey(_toggle), findsNothing);
      expect(find.byKey(_treeKey), findsNothing);
    });

    testWidgets('nothing is said for text inside the limits', (tester) async {
      for (final panel in const [
        ToolValuePanel(label: 'Result', text: _json, language: 'json'),
        ToolValuePanel(label: 'Result', text: _python, language: 'python'),
        ToolValuePanel(label: 'Result', text: 'plain'),
        ToolValuePanel(label: 'Result', text: '{"a":', language: 'json'),
      ]) {
        await tester.pumpWidget(_host(panel));
        expect(find.byKey(_noticeKey), findsNothing);
      }
    });

    testWidgets('the lines are in German', (tester) async {
      await tester.pumpWidget(
        _host(
          ToolValuePanel(
            label: 'Ergebnis',
            text: '[' * 65 + ']' * 65,
            language: 'json',
          ),
          locale: const Locale('de'),
        ),
      );
      expect(
        tester.widget<Text>(find.byKey(_noticeKey)).data,
        'Zu tief verschachtelt für die Baumansicht.',
      );
    });
  });

  group('plural strings', () {
    test('items and keys in English and German', () {
      final en = lookupAppLocalizations(const Locale('en'));
      final de = lookupAppLocalizations(const Locale('de'));
      expect(en.chatWidgetsToolValueItems(1), '1 item');
      expect(en.chatWidgetsToolValueItems(3), '3 items');
      expect(en.chatWidgetsToolValueKeys(1), '1 key');
      expect(en.chatWidgetsToolValueKeys(0), '0 keys');
      expect(de.chatWidgetsToolValueItems(1), '1 Element');
      expect(de.chatWidgetsToolValueItems(3), '3 Elemente');
      expect(de.chatWidgetsToolValueKeys(1), '1 Schlüssel');
      expect(de.chatWidgetsToolValueKeys(2), '2 Schlüssel');
      expect(
        de.chatWidgetsToolValueHiddenChar('U+202E'),
        'Verstecktes Zeichen U+202E',
      );
    });
  });

  group('ToolJsonView switch', () {
    testWidgets(
      'starts on the text as sent, coloured, with the switch on Text',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const ToolValuePanel(label: 'Input', text: _json, language: 'json'),
          ),
        );
        expect(_rich('Text | Tree'), findsOneWidget);
        expect(find.byKey(_treeKey), findsNothing);
        expect(_shown(_spans(tester)), _json);
        expect(_coloured(_spans(tester)), isTrue);
      },
    );

    testWidgets('switches to the tree and back', (tester) async {
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(label: 'Input', text: _json, language: 'json'),
        ),
      );
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      expect(find.byKey(_treeKey), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      expect(find.byKey(_treeKey), findsNothing);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('targets are 48 dp, 44 pt on iOS, 28 pt on a Mac', (
      tester,
    ) async {
      for (final (platform, size) in [
        (TargetPlatform.android, 48.0),
        (TargetPlatform.iOS, 44.0),
        (TargetPlatform.macOS, 28.0),
      ]) {
        await tester.pumpWidget(
          _host(
            const ToolValuePanel(label: 'Input', text: _json, language: 'json'),
            platform: platform,
          ),
        );
        final box = tester.getSize(find.byKey(_toggle));
        expect(box.height, greaterThanOrEqualTo(size), reason: '$platform');
        final copy = tester.getSize(find.byKey(_copyKey));
        expect(copy.height, greaterThanOrEqualTo(size), reason: '$platform');
        expect(copy.width, greaterThanOrEqualTo(size), reason: '$platform');
      }
    });

    testWidgets('keeps the tree when the parent rebuilds', (tester) async {
      Widget build(String note) => _host(
        Column(
          children: [
            Text(note),
            const ToolValuePanel(label: 'Input', text: _json, language: 'json'),
          ],
        ),
      );
      await tester.pumpWidget(build('one'));
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      await tester.pumpWidget(build('two'));
      expect(find.byKey(_treeKey), findsOneWidget);
    });

    testWidgets(
      'has no switch for invalid JSON, plain text or a running call',
      (tester) async {
        for (final panel in const [
          ToolValuePanel(label: 'Result', text: '{"a": 1', language: 'json'),
          ToolValuePanel(label: 'Result', text: 'done'),
          ToolValuePanel(
            label: 'Result',
            text: _json,
            language: 'json',
            settled: false,
          ),
          ToolValuePanel(label: 'Result', text: _python, language: 'python'),
        ]) {
          await tester.pumpWidget(_host(panel));
          expect(find.byKey(_toggle), findsNothing);
          expect(find.byKey(_treeKey), findsNothing);
        }
      },
    );

    testWidgets('a running call is plain even when the text is JSON', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(
            label: 'Input',
            text: _json,
            language: 'json',
            settled: false,
          ),
        ),
      );
      expect(_shown(_spans(tester)), _json);
      expect(_coloured(_spans(tester)), isFalse);
      expect(find.byKey(_tagKey), findsNothing);
      expect(CodeHighlightWorker.alive, 0);
    });

    testWidgets('the switch says which view is active', (tester) async {
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(label: 'Input', text: _json, language: 'json'),
        ),
      );
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byKey(_toggle)),
        isSemantics(
          label: 'Show result as\nShow as tree',
          isButton: true,
          hasToggledState: true,
          isToggled: false,
        ),
      );
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      expect(
        tester.getSemantics(find.byKey(_toggle)),
        isSemantics(
          label: 'Show result as\nShow as text',
          hasToggledState: true,
          isToggled: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('caps the body at 220 and scrolls inside it', (tester) async {
      final tall = List.generate(200, (i) => 'line $i').join('\n');
      await tester.pumpWidget(
        _host(ToolValuePanel(label: 'Output', text: tall)),
      );
      final body = tester.getSize(find.byType(SingleChildScrollView).last);
      expect(body.height, 220);
    });

    testWidgets('the tree caps at 220 too, and builds rows lazily', (
      tester,
    ) async {
      final text = '[${List.generate(5000, (i) => '$i').join(',')}]';
      expect(text.length, lessThan(kToolJsonSniffMaxChars));
      await tester.pumpWidget(
        _host(
          ToolValuePanel(
            label: 'Result',
            text: text,
            language: 'json',
            initiallyTree: true,
          ),
        ),
      );
      expect(tester.getSize(find.byKey(_treeKey)).height, 220);
      expect(find.text('4999'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long lines wrap, there is no horizontal scrolling', (
      tester,
    ) async {
      final line = List.filled(60, 'word').join(' ');
      await tester.pumpWidget(
        _host(ToolValuePanel(label: 'Output', text: line)),
      );
      expect(tester.takeException(), isNull);
      final text = tester.getSize(find.byType(SelectableText));
      expect(text.width, lessThanOrEqualTo(390));
      expect(text.height, greaterThan(40));
      for (final scroll in tester.widgetList<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      )) {
        expect(scroll.scrollDirection, Axis.vertical);
      }
    });
  });

  group('ToolJsonTree', () {
    testWidgets('summarises objects and arrays and folds on tap', (
      tester,
    ) async {
      const text = '{"a": [1, 2], "o": {"p": {"k": 1}}, "one": [true]}';
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(
            label: 'Result',
            text: text,
            language: 'json',
            initiallyTree: true,
          ),
        ),
      );
      expect(_rich('{ 3 keys }'), findsOneWidget);
      expect(_rich('a: [ 2 items ]'), findsOneWidget);
      expect(_rich('one: [ 1 item ]'), findsOneWidget);
      expect(_rich('o: { 1 key }'), findsOneWidget);
      expect(
        _rich('k: 1'),
        findsNothing,
        reason: 'the third level starts folded',
      );
      await tester.tap(_rich('p: { 1 key }'));
      await tester.pump();
      expect(_rich('k: 1'), findsOneWidget);
      // Folding the root hides everything under it.
      await tester.tap(_rich('{ 3 keys }'));
      await tester.pump();
      expect(_rich('o: '), findsNothing);
      expect(_rich('{ 3 keys }'), findsOneWidget);
    });

    testWidgets('colours keys, strings, numbers and literals as the text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(
            label: 'Result',
            text: '{"k": "v", "n": 1, "t": true, "z": null}',
            language: 'json',
            initiallyTree: true,
          ),
        ),
      );
      final palette = tester.element(find.byKey(_treeKey)).codeColors;
      Color? colour(String text) {
        for (final widget in tester.widgetList<Text>(
          find.byType(Text, skipOffstage: false),
        )) {
          final span = widget.textSpan;
          if (span is! TextSpan) continue;
          for (final child in span.children ?? const <InlineSpan>[]) {
            if (child is TextSpan && child.text == text) {
              return child.style?.color;
            }
          }
        }
        return null;
      }

      expect(colour('k'), palette.key);
      expect(colour('v'), palette.string);
      expect(colour('1'), palette.number);
      expect(colour('true'), palette.number);
      expect(colour('null'), palette.number);
    });

    testWidgets('draws hidden characters as boxes and a line break as \\n', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      const text = '{"name":"a\\u202eb","k\\u001bey":{"x":"l1\\nl2"}}';
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(
            label: 'Input',
            text: text,
            language: 'json',
            initiallyTree: true,
          ),
        ),
      );
      expect(find.text('U+202E'), findsOneWidget);
      expect(find.text('U+001B'), findsOneWidget);
      expect(find.text(r'\n'), findsOneWidget);
      final spoken = [
        for (var i = 0; i < find.byType(HiddenCharBox).evaluate().length; i++)
          _boxLabel(tester, i),
      ].join('\n');
      expect(spoken, contains('hidden character U+202E'));
      expect(spoken, contains('hidden character U+001B'));
      expect(spoken, contains('line break'));
      bool has(String needle) => find
          .byWidgetPredicate(
            (w) =>
                w is Text &&
                w.textSpan != null &&
                w.textSpan!.toPlainText().contains(needle),
          )
          .evaluate()
          .isNotEmpty;
      expect(has(_char(0x202E)), isFalse);
      expect(has(_char(0x1B)), isFalse);
      expect(has('\n'), isFalse);
      handle.dispose();
    });

    testWidgets('tree rows cannot be selected, even inside a SelectionArea', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const SelectionArea(
            child: ToolValuePanel(
              label: 'Result',
              text: _json,
              language: 'json',
              initiallyTree: true,
            ),
          ),
        ),
      );
      expect(find.byType(SelectableText), findsNothing);
      // The panel is selectable (it has a registrar), the tree opts out.
      expect(
        SelectionContainer.maybeOf(tester.element(find.byType(ToolValuePanel))),
        isNotNull,
      );
      expect(
        SelectionContainer.maybeOf(tester.element(find.byKey(_treeKey))),
        isNull,
      );
    });

    testWidgets('a lone surrogate does not crash the text or the tree', (
      tester,
    ) async {
      const text = r'{"a":"x\ud800","b\udc00":"y"}';
      for (final tree in [false, true]) {
        await tester.pumpWidget(
          _host(
            ToolValuePanel(
              label: 'Input',
              text: text,
              language: 'json',
              initiallyTree: tree,
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        _host(ToolValuePanel(label: 'Result', text: 'x${_char(0xD800)}')),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a valid surrogate pair (an emoji) is shown unchanged', (
      tester,
    ) async {
      const text = '{"k":"😀 ok"}';
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(label: 'Input', text: text, language: 'json'),
        ),
      );
      expect(_shown(_spans(tester)), text);
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(
            label: 'Input',
            text: text,
            language: 'json',
            initiallyTree: true,
          ),
        ),
      );
      expect(find.textContaining('😀 ok', findRichText: true), findsOneWidget);
      await tester.pumpWidget(
        _host(const ToolValuePanel(label: 'Result', text: 'a 😀 b')),
      );
      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .textSpan!
            .toPlainText(),
        'a 😀 b',
      );
    });

    testWidgets('JSON nested too deep is flat text with no tree or switch', (
      tester,
    ) async {
      for (final depth in [kToolJsonTreeMaxDepth + 1, 5000, 32000]) {
        final text = '${'[' * depth}${']' * depth}';
        for (final tree in [false, true]) {
          await tester.pumpWidget(
            _host(
              ToolValuePanel(
                label: 'Result',
                text: text,
                language: 'json',
                initiallyTree: tree,
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$depth');
          expect(find.byKey(_treeKey), findsNothing, reason: '$depth');
          expect(find.byKey(_toggle), findsNothing, reason: '$depth');
          expect(find.byType(SelectableText), findsOneWidget);
        }
      }
      await tester.pumpWidget(_host(const SizedBox()));
      await _workersGone(tester);
    });

    testWidgets('JSON at the depth limit still gets the tree switch', (
      tester,
    ) async {
      final text =
          '${'[' * kToolJsonTreeMaxDepth}${']' * kToolJsonTreeMaxDepth}';
      await tester.pumpWidget(
        _host(
          ToolValuePanel(
            label: 'Result',
            text: text,
            language: 'json',
            initiallyTree: true,
          ),
        ),
      );
      expect(find.byKey(_toggle), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
