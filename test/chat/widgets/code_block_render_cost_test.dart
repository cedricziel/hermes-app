import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide MessageStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/hermes_code_block.dart';

import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';

/// Wall-clock cost of laying out and painting a reply that holds fenced code
/// blocks. `flutter_test` pumps are synchronous on the test isolate, so a
/// Stopwatch around `pumpWidget` and `pump` is real time (no fake clock is
/// involved in build, layout or paint).
final _measured = <String>[];

Future<({int first, int rest})> _render(
  WidgetTester tester,
  String text,
) async {
  tester.view.physicalSize = const Size(1000, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final controller = InMemoryChatController(
    messages: [
      Message.text(
        id: 'a-1',
        authorId: kAssistantAuthorId,
        text: text,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    ],
  );
  addTearDown(controller.dispose);
  final first = Stopwatch()..start();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHermesLightTheme(),
      home: Scaffold(
        body: Chat(
          currentUserId: kUserAuthorId,
          resolveUser: (id) async => User(id: id),
          chatController: controller,
          builders: buildChatBuilders(onPickPrompt: (_) {})
              .copyWith(composerBuilder: (_) => const SizedBox.shrink()),
        ),
      ),
    ),
  );
  first.stop();
  final rest = Stopwatch()..start();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
  rest.stop();
  return (first: first.elapsedMilliseconds, rest: rest.elapsedMilliseconds);
}

String _fence(String lang, String body) =>
    'Here:\n\n```$lang\n$body\n```\n\nDone.';

String _base64Like(int n) =>
    List.generate(n, (i) => 'ABCDEFGHabcdefgh01234567+/'[i % 26]).join();

String _lines(String unit, {int lines = 20, int width = 399}) => List.filled(
  lines,
  List.filled(width ~/ unit.length + 1, unit).join().substring(0, width),
).join('\n');

void main() {
  tearDownAll(() {
    // ignore: avoid_print
    print('RENDER-COST\n${_measured.join('\n')}');
  });

  // The worst shapes that stay inside the limits of one block (500 characters
  // a line, 8 000 a block), then past them, then the forms a fence can take.
  final worst = <String, String>{
    'js a+spaces x20': _fence('javascript', _lines('a${' ' * 399}')),
    r'yaml ${ x20': _fence('yaml', _lines(r'${')),
    'js quotes x80 lines': _fence(
      'javascript',
      List.filled(80, '"' * 99).join('\n'),
    ),
    'swift # x20': _fence('swift', _lines('#')),
    'js 1+ x20': _fence('javascript', _lines('1+')),
    'js comment lines x300': _fence(
      'javascript',
      List.filled(300, '// a benign comment line').join('\n'),
    ),
  };
  final spaces = 'a${' ' * 20000}';
  final forms = <String, String>{
    'blockquote': '> ```javascript\n> $spaces\n> ```',
    'list item': '- ```javascript\n  $spaces\n  ```',
    '4 spaces': '1. x\n\n    ```javascript\n    $spaces\n    ```',
    'tab': '1. x\n\n\t```javascript\n\t$spaces\n\t```',
    'CRLF': '```javascript\r\n$spaces\r\n```\r\n',
    'pre code': '<pre><code class="language-javascript">$spaces</code></pre>',
    'backtick in info': '```a`b\n\n```javascript\n$spaces\n```',
  };
  final cases = <String, String>{
    'normal js 40 lines': _fence(
      'javascript',
      List.generate(40, (i) => 'const x$i = foo($i); // note').join('\n'),
    ),
    ...worst,
    'worst shapes x50 fences': List.generate(
      50,
      (i) => worst.values
          .elementAt(i % worst.length)
          .replaceFirst('\n```\n\nDone.', '\n// $i\n```\n\nDone.'),
    ).join('\n\n'),
    'js a+spaces 50 fences': List.generate(
      50,
      (i) =>
          _fence('javascript', '// $i\n${_lines('a${' ' * 399}', lines: 19)}'),
    ).join('\n\n'),
    'js a+spaces x19, 50 identical fences': List.filled(
      50,
      _fence('javascript', _lines('a${' ' * 399}', lines: 19)),
    ).join('\n\n'),
    'python 100 fences, 20 lines': List.generate(
      100,
      (i) => _fence(
        'python',
        List.generate(20, (j) => 'x$j = f($j)  # c').join('\n'),
      ),
    ).join('\n\n'),
    for (final n in [5000, 20000])
      'js a+$n spaces': _fence('javascript', 'a${' ' * n}'),
    'js 1+ x50000': _fence('javascript', '1+' * 50000),
    'text 400000 one line': _fence('text', _base64Like(400000)),
    'js 100000 one line': _fence('javascript', _base64Like(100000)),
    for (final form in forms.entries) 'form: ${form.key}': form.value,
  };

  final inLimits = {'normal js 40 lines', ...worst.keys};

  for (final e in cases.entries) {
    testWidgets(e.key, (tester) async {
      // The first block ever built pays for the grammar tables.
      await _render(tester, _fence('javascript', 'const a = 1;'));
      await tester.pumpWidget(const SizedBox());
      final r = await _render(tester, e.value);
      _measured.add(
        '${e.key} | chars=${e.value.length} | first=${r.first}ms | pumps=${r.rest}ms',
      );
      final fields = tester
          .widgetList<HermesCodeBlock>(find.byType(HermesCodeBlock))
          .toList();
      expect(fields, isNotEmpty, reason: e.key);
      // A fast plain fallback must not pass as a benchmark of colouring.
      final coloured = fields.where((f) => f.highlightCode).length;
      if (e.key.contains('fences')) {
        expect(coloured, inInclusiveRange(1, fields.length - 1), reason: e.key);
      } else if (inLimits.contains(e.key)) {
        expect(coloured, fields.length, reason: e.key);
      } else {
        expect(coloured, 0, reason: e.key);
      }
      // What the limits guarantee, counted rather than timed (unbounded these
      // take from 0.3 s to 17 s; the times are only printed above).
      final granted = fields.where((f) => f.highlightCode);
      expect(
        granted.fold<int>(0, (sum, f) => sum + f.codes.length),
        lessThanOrEqualTo(kHighlightMaxDocument),
        reason: e.key,
      );
      for (final f in granted) {
        expect(f.codes.length, lessThanOrEqualTo(kHighlightMaxBlock));
        for (final line in f.codes.split(RegExp(r'\r\n|\n|\r'))) {
          expect(line.length, lessThanOrEqualTo(kHighlightMaxLine));
        }
      }
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
}
