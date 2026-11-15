import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/markdown_entities.dart';

String _fence(String info, String body, {String marker = '```'}) =>
    'Intro\n\n$marker$info\n$body\n$marker\n\nOutro';

void main() {
  group('boundCodeFences', () {
    test('leaves text without a fence as it is', () {
      const text = 'Just prose with `code` and a | table.';
      expect(identical(boundCodeFences(text), text), isTrue);
    });

    test('keeps the language of an ordinary block untouched', () {
      final text = _fence(
        'javascript',
        List.generate(400, (i) => 'const x$i = foo($i); // note').join('\n'),
      );
      expect(boundCodeFences(text), text);
    });

    test('keeps a block just under both limits', () {
      final text = _fence('python', '${'a ' * (kMaxHighlightedLine ~/ 2)}\nb');
      expect(boundCodeFences(text), text);
    });

    test('drops the language of a block with one very long line', () {
      final text = _fence('javascript', 'a${' ' * (kMaxHighlightedLine + 1)}');
      expect(boundCodeFences(text), startsWith('Intro\n\n```\n'));
      expect(boundCodeFences(text), contains('a  '));
    });

    test('drops the language of a block over the size limit', () {
      final body = List.filled(
        kMaxHighlightedChars ~/ 20 + 10,
        'const a = 1; // x   ',
      ).join('\n');
      expect(body.length, greaterThan(kMaxHighlightedChars));
      expect(boundCodeFences(_fence('js', body)), startsWith('Intro\n\n```\n'));
    });

    test('keeps the body byte for byte', () {
      final body = 'a${' ' * 5000}\n// tail';
      final bounded = boundCodeFences(_fence('javascript', body));
      expect(bounded, _fence('', body));
    });

    test('only touches the oversized block of several', () {
      final good = _fence('dart', 'final a = 1;');
      final bad = _fence('javascript', '1+' * kMaxHighlightedChars);
      final bounded = boundCodeFences('$good\n\n$bad\n\n$good');
      expect('```dart'.allMatches(bounded), hasLength(2));
      expect(bounded, isNot(contains('```javascript')));
    });

    test('handles a still-streaming fence that is already too long', () {
      final text = 'Here\n```javascript\na${' ' * (kMaxHighlightedLine + 5)}';
      expect(boundCodeFences(text), startsWith('Here\n```\n'));
    });

    test('keeps a streaming fence that is still small', () {
      const text = 'Here\n```javascript\nconst a = 1;';
      expect(boundCodeFences(text), text);
    });

    test('handles tilde fences and indentation', () {
      final text = _fence(
        'javascript',
        'a${' ' * (kMaxHighlightedLine + 1)}',
        marker: '~~~',
      );
      expect(boundCodeFences(text), startsWith('Intro\n\n~~~\n'));
      expect(
        boundCodeFences(
          '  ```javascript\n${'x' * (kMaxHighlightedLine + 1)}\n  ```',
        ),
        startsWith('  ```\n'),
      );
    });

    test('a longer fence is not closed by a shorter marker inside', () {
      final text =
          '````javascript\n```\n${'a' * (kMaxHighlightedLine + 1)}\n````';
      expect(boundCodeFences(text), startsWith('````\n```\n'));
    });

    test('a block with no language needs no change', () {
      final text = _fence('', 'x' * (kMaxHighlightedLine * 4));
      expect(boundCodeFences(text), text);
    });
  });
}
