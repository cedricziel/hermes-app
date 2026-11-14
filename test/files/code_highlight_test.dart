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

  test('highlightCodeIn is highlightCode for an isolate', () {
    expect(
      highlightCodeIn((python, 'python')),
      highlightCode(python, 'python'),
    );
  });
}
