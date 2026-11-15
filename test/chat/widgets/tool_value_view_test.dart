import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_json_view/flutter_json_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/tool_value_language.dart';
import 'package:hermes_app/src/chat/widgets/tool_value_view.dart';
import 'package:hermes_app/src/files/code_highlight.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Widget _host(Widget child, {TargetPlatform? platform}) {
  final base = buildHermesLightTheme();
  return MaterialApp(
    theme: platform == null ? base : base.copyWith(platform: platform),
    home: Scaffold(body: SingleChildScrollView(child: child)),
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

final _large = List.generate(
  200,
  (i) => 'def f$i(x):\n    return "v$i" + x\n',
).join('\n');

const _python = 'def hello(name):\n    return "hi " + name\n';
const _json = '{"a": 1, "b": [true, null]}';
const _toggle = ValueKey('tool-json-toggle');

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
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        _python,
      );
      await tester.pumpWidget(
        _host(const ToolValueView(text: _python, language: 'python')),
      );
      expect(_coloured(_spans(tester)), isTrue);
    });

    testWidgets('draws control and bidi characters as placeholders', (
      tester,
    ) async {
      final text =
          'a${String.fromCharCode(0x202E)}b${String.fromCharCode(0x1B)}c';
      for (final settled in [true, false]) {
        await tester.pumpWidget(
          _host(ToolValueView(text: text, language: 'bash', settled: settled)),
        );
        final selectable = tester.widget<SelectableText>(
          find.byType(SelectableText),
        );
        final shown = settled
            ? _shown(selectable.textSpan!.children!)
            : selectable.data;
        expect(shown, 'a<U+202E>b<U+001B>c', reason: 'settled: $settled');
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
  });

  group('ToolValuePanel copy', () {
    testWidgets('copies the original text, never the placeholders', (
      tester,
    ) async {
      final original = 'a${String.fromCharCode(0x202E)}b\nline';
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        _host(ToolValuePanel(label: 'Result', text: original)),
      );
      await tester.tap(find.byType(IconButton));
      expect(copied, original);
    });
  });

  group('ToolJsonView switch', () {
    testWidgets(
      'starts on the text as sent, coloured, with a labelled switch',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const ToolValuePanel(label: 'Input', text: _json, language: 'json'),
          ),
        );
        expect(find.text('Tree view'), findsOneWidget);
        expect(find.byType(JsonView), findsNothing);
        expect(_shown(_spans(tester)), _json);
        expect(_coloured(_spans(tester)), isTrue);
      },
    );

    testWidgets('switches to the tree and back, labelled with the other', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ToolValuePanel(label: 'Input', text: _json, language: 'json'),
        ),
      );
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      expect(find.byType(JsonView), findsOneWidget);
      expect(find.text('Text view'), findsOneWidget);
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      expect(find.byType(JsonView), findsNothing);
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
        final copy = tester.getSize(find.byType(IconButton));
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
      expect(find.byType(JsonView), findsOneWidget);
      expect(find.text('Text view'), findsOneWidget);
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
        ]) {
          await tester.pumpWidget(_host(panel));
          expect(find.byKey(_toggle), findsNothing);
          expect(find.byType(JsonView), findsNothing);
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
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        _json,
      );
    });

    testWidgets('the tree draws bidi and control characters as placeholders', (
      tester,
    ) async {
      final bidi = String.fromCharCode(0x202E);
      final esc = String.fromCharCode(0x1B);
      const text = r'{"name":"a\u202eb","k\u001bey":{"x":1}}';
      await tester.pumpWidget(
        _host(
          ToolValuePanel(
            label: 'Input',
            text: text,
            language: 'json',
            initiallyTree: true,
          ),
        ),
      );
      expect(find.byType(JsonView), findsOneWidget);
      bool has(String needle) => find
          .byWidgetPredicate(
            (w) =>
                (w is Text &&
                    (w.data ?? w.textSpan?.toPlainText() ?? '').contains(
                      needle,
                    )) ||
                (w is SelectableText && (w.data ?? '').contains(needle)),
          )
          .evaluate()
          .isNotEmpty;
      expect(has(bidi), isFalse);
      expect(has(esc), isFalse);
      expect(has('a<U+202E>b'), isTrue);
      expect(has('k<U+001B>ey'), isTrue);
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
        _host(
          ToolValuePanel(
            label: 'Result',
            text: 'x${String.fromCharCode(0xD800)}',
          ),
        ),
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
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && (w.data ?? '').contains('😀 ok'),
        ),
        findsOneWidget,
      );
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
          expect(find.byType(JsonView), findsNothing, reason: '$depth');
          expect(find.byKey(_toggle), findsNothing, reason: '$depth');
          expect(find.byType(SelectableText), findsOneWidget);
        }
        // A tree asked for directly falls back to flat text too.
        await tester.pumpWidget(_host(ToolJsonTree(text: text)));
        expect(find.byType(JsonView), findsNothing, reason: '$depth');
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
        _host(ToolValuePanel(label: 'Result', text: text, language: 'json')),
      );
      expect(find.byKey(_toggle), findsOneWidget);
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
          label: 'Tree view',
          isButton: true,
          hasToggledState: true,
          isToggled: false,
        ),
      );
      await tester.tap(find.byKey(_toggle));
      await tester.pump();
      expect(
        tester.getSemantics(find.byKey(_toggle)),
        isSemantics(label: 'Text view', hasToggledState: true, isToggled: true),
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
  });
}
