import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/code_highlight.dart';

String _joined(List<CodeRun> runs) => runs.map((r) => r.$1).join();

Set<CodeToken?> _tokens(List<CodeRun> runs) => {for (final r in runs) r.$2};

CodeToken? _of(List<CodeRun> runs, String text) {
  for (final run in runs) {
    if (run.$1.contains(text)) return run.$2;
  }
  fail('no run holds "$text" in $runs');
}

void main() {
  const python = '''
# greet
def hello(name):
    return "hi " + name + str(42)
''';

  group('highlightCode', () {
    test("colours Python by the server's language name", () {
      final runs = highlightCode(python, 'python');
      expect(_joined(runs), python);
      expect(_of(runs, '# greet'), CodeToken.comment);
      expect(_of(runs, 'def'), CodeToken.keyword);
      expect(_of(runs, '"hi "'), CodeToken.string);
      expect(_of(runs, '42'), CodeToken.number);
      expect(_of(runs, 'hello'), CodeToken.function);
    });

    test('the name is case-insensitive and aliases work', () {
      expect(
        _tokens(highlightCode(python, 'PYTHON')),
        contains(CodeToken.keyword),
      );
      expect(
        _tokens(highlightCode('echo "x"', 'shell')),
        contains(CodeToken.string),
      );
      expect(
        _tokens(highlightCode('{"a": 1}', 'json')),
        contains(CodeToken.number),
      );
      expect(_tokens(highlightCode('a: 1', 'yaml')), isNotEmpty);
      expect(_tokens(highlightCode('<a href="x"></a>', 'xml')), isNot({null}));
    });

    test('an unknown or plain-text name is one plain run', () {
      for (final name in ['text', 'klingon', '', null]) {
        expect(highlightCode(python, name), [(python, null)], reason: '$name');
      }
    });

    test('nothing is coloured above the size cap', () {
      final big = 'x = 1\n' * (kCodeHighlightMaxChars ~/ 6 + 1);
      expect(big.length, greaterThan(kCodeHighlightMaxChars));
      expect(highlightCode(big, 'python'), [(big, null)]);
    });

    test('empty text is one plain run', () {
      expect(highlightCode('', 'python'), [('', null)]);
    });

    test('whatever the grammar does, the text is unchanged', () {
      for (final (code, lang) in [
        ('def (:\n  "unterminated', 'python'),
        ('}{ ][ <<<', 'rust'),
        ('\t\r\n<U+202E>', 'javascript'),
      ]) {
        expect(_joined(highlightCode(code, lang)), code);
      }
    });
  });

  group('tokenOfScope', () {
    test('maps grammar scopes to the six palette tokens', () {
      expect(tokenOfScope('keyword'), CodeToken.keyword);
      expect(tokenOfScope('string'), CodeToken.string);
      expect(tokenOfScope('comment'), CodeToken.comment);
      expect(tokenOfScope('number'), CodeToken.number);
      expect(tokenOfScope('function.call'), CodeToken.function);
      expect(tokenOfScope('type.builtin'), CodeToken.type);
      expect(tokenOfScope('attribute'), CodeToken.type);
      expect(tokenOfScope('operator'), isNull);
      expect(tokenOfScope('punctuation'), isNull);
    });
  });

  test('text and plaintext need no highlighter', () {
    for (final name in ['text', 'plaintext', 'TXT', 'plain']) {
      expect(hasCodeGrammar(name), isFalse, reason: name);
      expect(highlightCode(python, name), [(python, null)]);
    }
    expect(hasCodeGrammar('python'), isTrue);
  });

  group('isInlineSafe', () {
    test('a small, plainly shaped text is', () {
      expect(isInlineSafe(python), isTrue);
      expect(isInlineSafe(''), isTrue);
    });

    test('a long text, a long line or a long blank run is not', () {
      expect(isInlineSafe('x\n' * kCodeHighlightInlineChars), isFalse);
      expect(isInlineSafe('a' * (kCodeHighlightInlineLine + 1)), isFalse);
      expect(isInlineSafe('a' * kCodeHighlightInlineLine), isTrue);
      expect(
        isInlineSafe('a${' ' * (kCodeHighlightInlineSpaceRun + 1)}b'),
        isFalse,
      );
      expect(
        isInlineSafe('a${'\t' * (kCodeHighlightInlineSpaceRun + 1)}b'),
        isFalse,
      );
      expect(
        isInlineSafe('${'a' * 200}\n${'b' * 200}\n${'c' * 200}'),
        isTrue,
        reason: 'the line counter resets at a line feed',
      );
    });
  });

  group('CodeHighlightBudget', () {
    test('covers a few small blocks, then nothing', () {
      final budget = CodeHighlightBudget();
      var taken = 0;
      for (var i = 0; i < 26; i++) {
        if (budget.take('def f(): pass')) taken++;
      }
      expect(taken, 8);
    });

    test('refuses a block that is not inline safe', () {
      expect(CodeHighlightBudget().take('a${' ' * 500}'), isFalse);
    });

    test('is spent by characters too', () {
      final budget = CodeHighlightBudget(chars: 100, blocks: 50);
      expect(budget.take('x' * 60), isTrue);
      expect(budget.take('x' * 60), isFalse);
    });
  });

  group('CodeHighlightWorker', () {
    // `a` then blanks: quadratic in about twenty grammars of val_highlight.
    final crafted = 'a${' ' * 20000}';

    test('answers what highlightCode answers', () async {
      final worker = CodeHighlightWorker();
      expect(
        await worker.highlight(python, 'python'),
        highlightCode(python, 'python'),
      );
    });

    test(
      'gives up on a slow text at the timeout and ends its isolate',
      () async {
        final worker = CodeHighlightWorker();
        final clock = Stopwatch()..start();
        final runs = await worker.highlight(
          crafted,
          'javascript',
          timeout: const Duration(milliseconds: 300),
        );
        expect(runs, isNull);
        expect(clock.elapsedMilliseconds, lessThan(1500));
        await _until(() => CodeHighlightWorker.alive == 0);
      },
    );

    test('kill ends the isolate and answers null', () async {
      final worker = CodeHighlightWorker();
      final pending = worker.highlight(crafted, 'javascript');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      worker.kill();
      expect(await pending, isNull);
      await _until(() => CodeHighlightWorker.alive == 0);
    });

    test('kill before the isolate started still ends it', () async {
      final worker = CodeHighlightWorker();
      final pending = worker.highlight(crafted, 'javascript');
      worker.kill();
      expect(await pending, isNull);
      await _until(() => CodeHighlightWorker.alive == 0);
    });
  });
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  expect(done(), isTrue);
}
