import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/json_tree_parser.dart';

JsonTreeParse _parse(String text, {int depth = 64, int nodes = 2000}) =>
    parseJsonTree(text, maxDepth: depth, maxNodes: nodes);

List<String> _texts(String text) => [
  for (final n in _parse(text).nodes!)
    if (!n.isContainer) n.text,
];

void main() {
  group('numbers are kept as written', () {
    test('every lexeme comes back unchanged', () {
      const lexemes = [
        '12345678901234567890',
        '1.50',
        '1e3',
        '-0',
        '0.10',
        '1E+2',
        '-1.5e-07',
        '0',
      ];
      expect(_texts('[${lexemes.join(',')}]'), lexemes);
      expect(_texts('{"a": 12345678901234567890, "b": 1.50}'), [
        '12345678901234567890',
        '1.50',
      ]);
    });

    test('keys keep their order and duplicates', () {
      final nodes = _parse('{"b": 1, "a": 2, "b": 3}').nodes!;
      expect([for (final n in nodes) n.key], [null, 'b', 'a', 'b']);
      expect(nodes.first.count, 3);
    });

    test('strings are decoded for display, literals are as written', () {
      final nodes = _parse(r'["a\nbé\"", true, false, null]').nodes!;
      expect(nodes[1].text, 'a\nbé"');
      expect(
        [for (final n in nodes.skip(2)) n.text],
        ['true', 'false', 'null'],
      );
    });

    test('a lone surrogate escape does not fail the parse', () {
      expect(_parse(r'{"a":"x\ud800"}').nodes, isNotNull);
    });
  });

  group('structure', () {
    test('subtree ends and counts', () {
      final nodes = _parse('{"a": [1, 2], "o": {}, "e": []}').nodes!;
      expect(nodes.length, 6);
      expect(nodes[0].end, 6);
      expect(nodes[1].count, 2);
      expect(nodes[1].end, 4);
      expect(nodes[4].count, 0);
    });

    test('invalid text fails as invalid', () {
      for (final text in [
        '',
        '1',
        '"a"',
        '[1,]',
        '[1 2]',
        '{"a" 1}',
        '{a: 1}',
        '[01]',
        '[1.]',
        '[1e]',
        '[-]',
        '[tru]',
        '{"a":1',
        '[1] x',
        '{"a":1,}',
      ]) {
        expect(_parse(text).failure, JsonTreeFailure.invalid, reason: text);
      }
    });

    test('agrees with jsonDecode on what is a container', () {
      for (final text in [
        '[]',
        '{}',
        ' [ 1 , {"a" : [ ] } ] ',
        '[1.5e3, -0, "x"]',
      ]) {
        expect(() => jsonDecode(text), returnsNormally);
        expect(_parse(text).nodes, isNotNull, reason: text);
      }
    });
  });

  group('caps', () {
    test('depth 64 parses, 65 fails as too deep', () {
      expect(_parse('[' * 64 + ']' * 64).nodes, isNotNull);
      expect(_parse('[' * 65 + ']' * 65).failure, JsonTreeFailure.tooDeep);
      expect(_parse('[' * 100000).failure, JsonTreeFailure.tooDeep);
    });

    test('2,000 nodes parse, 2,001 fail', () {
      String array(int items) => '[${List.filled(items, '1').join(',')}]';
      expect(_parse(array(1999)).nodes!.length, 2000);
      expect(_parse(array(2000)).failure, JsonTreeFailure.tooManyNodes);
      expect(
        _parse('[${List.filled(2000, '[]').join(',')}]').failure,
        JsonTreeFailure.tooManyNodes,
      );
    });

    test('a huge text stops at the cap and does not read the rest', () {
      final big = '[${List.filled(500000, '1').join(',')}]';
      final watch = Stopwatch()..start();
      expect(_parse(big).failure, JsonTreeFailure.tooManyNodes);
      expect(watch.elapsedMilliseconds, lessThan(500));
    });
  });
}
