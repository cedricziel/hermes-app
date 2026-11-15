import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/tool_value_language.dart';
import 'package:hermes_app/src/files/code_highlight.dart';

void main() {
  group('toolValueLanguage', () {
    test('a path decides by its extension, in any case, in any folder', () {
      expect(toolValueLanguage('x', path: 'lib/main.dart'), 'dart');
      expect(toolValueLanguage('x', path: '/a.b/tool.PY'), 'python');
      expect(toolValueLanguage('x', path: 'ci/build.yml'), 'yaml');
      expect(toolValueLanguage('x', path: 'run.sh'), 'bash');
      expect(toolValueLanguage('x', path: 'a/b/c.tsx'), 'typescript');
    });

    test('every language it names has a grammar', () {
      for (final ext in [
        'py', 'js', 'ts', 'json', 'yaml', 'toml', 'sh', 'xml', 'css', 'scss', //
        'sql', 'rs', 'go', 'java', 'kt', 'swift', 'c', 'cpp', 'rb', 'php', //
        'dart', 'lua', 'md',
      ]) {
        final language = toolValueLanguage('x', path: 'f.$ext');
        expect(language, isNotNull, reason: ext);
        expect(hasCodeGrammar(language), isTrue, reason: '$ext -> $language');
      }
    });

    test('a command is shell, whatever the text looks like', () {
      expect(toolValueLanguage('ls -la', isCommand: true), 'bash');
      expect(toolValueLanguage('{"a": 1}', isCommand: true), 'bash');
    });

    test('a JSON object or array is json; a path wins over the sniff', () {
      expect(toolValueLanguage('{"a": 1}'), 'json');
      expect(toolValueLanguage(' \n[1, 2]'), 'json');
      expect(toolValueLanguage('{"a": 1}', path: 'x.py'), 'python');
    });

    test('invalid JSON, scalars and plain text are plain', () {
      expect(toolValueLanguage('{"a": 1'), isNull);
      expect(toolValueLanguage('[1, 2,'), isNull);
      expect(toolValueLanguage('42'), isNull);
      expect(toolValueLanguage('"text"'), isNull);
      expect(toolValueLanguage('null'), isNull);
      expect(toolValueLanguage('Build finished'), isNull);
      expect(toolValueLanguage(''), isNull);
    });

    test('unknown or missing extensions fall through to the sniff', () {
      expect(toolValueLanguage('plain', path: 'notes.xyz'), isNull);
      expect(toolValueLanguage('plain', path: 'Makefile'), isNull);
      expect(toolValueLanguage('plain', path: '.gitignore'), isNull);
      expect(toolValueLanguage('plain', path: 'dir.d/file'), isNull);
      expect(toolValueLanguage('plain', path: 'trailing.'), isNull);
      expect(toolValueLanguage('[1]', path: 'notes.xyz'), 'json');
    });

    test(
      'nesting depth ignores brackets in strings and gives up past the cap',
      () {
        expect(jsonNestingDepth('{"a": [[1], "[[[["]}'), 3);
        expect(jsonNestingDepth(r'["\"[[[", 1]'), 1);
        expect(jsonNestingDepth('[' * 32000), kToolJsonTreeMaxDepth + 1);
        expect(tryDecodeJsonTree('[' * 70 + ']' * 70), isNull);
        expect(tryDecodeJsonTree('[' * 64 + ']' * 64), isNotNull);
        // Still JSON for the sniff, so it is coloured as flat text.
        expect(toolValueLanguage('[' * 5000 + ']' * 5000), 'json');
      },
    );

    test('JSON above the size bound is not parsed, only recognised by shape', () {
      final inside = '[${List.filled(1000, '1').join(',')}]';
      expect(inside.length, lessThan(kToolJsonSniffMaxChars));
      expect(toolValueLanguage(inside), 'json');
      final over = '[${List.filled(kToolJsonSniffMaxChars, '1').join(',')}]';
      expect(over.length, greaterThan(kToolJsonSniffMaxChars));
      expect(isJsonContainerText(over), isFalse);
      // Coloured flat as JSON all the same, with the outline as the only test.
      expect(toolValueLanguage(over), 'json');
      expect(toolValueLanguage('x' * (kToolJsonSniffMaxChars + 1)), isNull);
      expect(
        toolValueLanguage('{${'x' * kToolJsonSniffMaxChars}'),
        isNull,
        reason: 'no closing brace',
      );
    });

    test('a fence tag names the grammar, by alias and case, or nothing', () {
      expect(toolValueLanguage('x', fence: 'python'), 'python');
      expect(toolValueLanguage('x', fence: 'PY'), 'python');
      expect(toolValueLanguage('x', fence: 'sh'), 'bash');
      expect(toolValueLanguage('x', fence: 'json title="a"'), 'json');
      expect(toolValueLanguage('x', fence: 'yml'), 'yaml');
      expect(toolValueLanguage('x', fence: 'nosuchlang'), isNull);
      expect(toolValueLanguage('x', fence: 'text'), isNull);
      expect(toolValueLanguage('x', fence: ''), isNull);
      // The fence wins over the path and the sniff.
      expect(
        toolValueLanguage('{"a": 1}', path: 'a.py', fence: 'dart'),
        'dart',
      );
      expect(toolValueLanguage('{"a": 1}', fence: 'unknown'), isNull);
    });

    test('a path names the language of code and a fence-less text is JSON', () {
      expect(toolValueLanguage('print(1)', path: 'tools/a.py'), 'python');
      expect(toolValueLanguage('plain words'), isNull);
    });
  });

  group('limits', () {
    test('the three numbers', () {
      expect(kToolJsonSniffMaxChars, 64 * 1024);
      expect(kToolValueColourMaxChars, 512 * 1024);
      expect(kToolValueColourMaxChars, kCodeHighlightMaxChars);
      expect(kToolJsonTreeMaxDepth, 64);
    });

    String json(int length) {
      // An array of "x" padded to exactly [length] characters.
      const head = '["';
      const tail = '"]';
      return '$head${'x' * (length - head.length - tail.length)}$tail';
    }

    test('JSON of exactly 64 KB still gets the tree, one more does not', () {
      final exact = json(kToolJsonSniffMaxChars);
      expect(exact.length, kToolJsonSniffMaxChars);
      final shape = toolValueShape(exact, language: 'json');
      expect(shape.offersTree, isTrue);
      expect(shape.notice, ToolValueNotice.none);

      final over = json(kToolJsonSniffMaxChars + 1);
      final overShape = toolValueShape(over, language: 'json');
      expect(overShape.offersTree, isFalse);
      expect(overShape.language, 'json');
      expect(overShape.notice, ToolValueNotice.tooLongForTree);
    });

    test(
      'text of exactly 512 KB is coloured, one more is plain and says so',
      () {
        final exact = json(kToolValueColourMaxChars);
        final shape = toolValueShape(exact, language: 'json');
        expect(shape.notice, ToolValueNotice.tooLongForTree);
        expect(shape.language, 'json');

        final over = json(kToolValueColourMaxChars + 1);
        final overShape = toolValueShape(over, language: 'json');
        expect(overShape.notice, ToolValueNotice.tooLongToColour);
        expect(overShape.offersTree, isFalse);

        final code = 'x = 1\n' * 100000;
        expect(code.length, greaterThan(kToolValueColourMaxChars));
        expect(
          toolValueShape(code, language: 'python').notice,
          ToolValueNotice.tooLongToColour,
        );
        expect(
          toolValueShape(
            'x' * kToolValueColourMaxChars,
            language: 'python',
          ).notice,
          ToolValueNotice.none,
        );
      },
    );

    test('depth 64 gets the tree, depth 65 is flat and says so', () {
      final ok = '[' * 64 + ']' * 64;
      expect(toolValueShape(ok, language: 'json').offersTree, isTrue);
      final deep = '[' * 65 + ']' * 65;
      final shape = toolValueShape(deep, language: 'json');
      expect(shape.offersTree, isFalse);
      expect(shape.language, 'json');
      expect(shape.notice, ToolValueNotice.tooDeepForTree);
    });

    test('a running call, plain text and invalid JSON say nothing', () {
      for (final shape in [
        toolValueShape('{"a": 1}', language: 'json', settled: false),
        toolValueShape('words'),
        toolValueShape('{"a": 1', language: 'json'),
        toolValueShape('x' * (kToolValueColourMaxChars + 1)),
      ]) {
        expect(shape.language, isNull);
        expect(shape.notice, ToolValueNotice.none);
        expect(shape.offersTree, isFalse);
      }
    });

    test('code gets no tree and no notice', () {
      final shape = toolValueShape('print(1)', language: 'python');
      expect(shape.language, 'python');
      expect(shape.offersTree, isFalse);
      expect(shape.notice, ToolValueNotice.none);
    });
  });

  group('node cap', () {
    test('the number', () => expect(kToolJsonTreeMaxNodes, 2000));

    String array(int items) => '[${List.filled(items, '1').join(',')}]';

    test('2,000 nodes still get the tree, 2,001 do not', () {
      final ok = toolValueShape(array(1999), language: 'json');
      expect(ok.offersTree, isTrue);
      final over = toolValueShape(array(2000), language: 'json');
      expect(over.offersTree, isFalse);
      expect(over.language, 'json');
      expect(over.notice, ToolValueNotice.tooLongForTree);
    });

    test('a large text is tagged only by the outline at both ends', () {
      final body = List.filled(kToolJsonSniffMaxChars ~/ 4, '"abc"').join(',');
      expect(toolValueLanguage('[$body]'), 'json');
      expect(toolValueLanguage('\n {$body} \r\n\n'), 'json');
      expect(toolValueLanguage('[$body'), isNull);
      // A log that happens to end in a bracket is not JSON.
      final log =
          '[INFO] ${List.filled(kToolJsonSniffMaxChars ~/ 8, 'line').join('\n')} [done]';
      expect(toolValueLanguage(log), isNull);
      expect(toolValueLanguage('{ x ${body.substring(3)}}'), isNull);
      expect(toolValueLanguage('[ \n 1, $body]'), 'json');
      expect(toolValueLanguage('{"a": $body}'), 'json');
      expect(toolValueLanguage('{ }'), 'json');
      expect(toolValueLanguage('[$body}'), isNull);
      expect(toolValueLanguage('$body]'), isNull);
    });
  });
}
