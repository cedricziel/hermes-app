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

    test('JSON above the size bound is not parsed and stays plain', () {
      final inside = '[${List.filled(1000, '1').join(',')}]';
      expect(inside.length, lessThan(kToolJsonSniffMaxChars));
      expect(toolValueLanguage(inside), 'json');
      final over = '[${List.filled(kToolJsonSniffMaxChars, '1').join(',')}]';
      expect(over.length, greaterThan(kToolJsonSniffMaxChars));
      expect(toolValueLanguage(over), isNull);
      expect(isJsonContainerText(over), isFalse);
    });
  });
}
