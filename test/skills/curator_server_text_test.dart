import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/skills/curator/curator_server_text.dart';

void main() {
  test('plain text stays as it is, trimmed', () {
    expect(curatorServerText('  disk full  '), 'disk full');
    expect(
      curatorServerText(
        'curator: disabled via config; enable with `curator.enabled: true`',
      ),
      'curator: disabled via config; enable with `curator.enabled: true`',
    );
  });

  test('nothing readable is null', () {
    expect(curatorServerText(null), isNull);
    expect(curatorServerText(''), isNull);
    expect(curatorServerText(' \n\t '), isNull);
  });

  test('line breaks and tabs become one space', () {
    expect(curatorServerText('a\r\nb\n\n\tc'), 'a b c');
  });

  test('control and bidi characters are drawn, never obeyed', () {
    expect(
      curatorServerText('a\u202Eb \u001B[31mred\u0007'),
      'a<U+202E>b <U+001B>[31mred<U+0007>',
    );
    expect(curatorServerText('x\u200By'), 'x<U+200B>y');
    expect(curatorServerText('x\u2066y\u2069'), 'x<U+2066>y<U+2069>');
  });

  test('a lone surrogate becomes U+FFFD', () {
    expect(curatorServerText('a\uD800b'), 'a\uFFFDb');
    expect(curatorServerText('a\uDC00'), 'a\uFFFD');
  });

  test('200 characters stay whole, 201 are cut with an ellipsis', () {
    final exact = 'a' * 200;
    expect(curatorServerText(exact), exact);
    final cut = curatorServerText('a' * 201)!;
    expect(cut, '${'a' * 199}…');
    expect(cut.characters.length, 200);
  });

  test('the cap counts characters, not code units', () {
    final emoji = '👩‍👩‍👧' * 250;
    final cut = curatorServerText(emoji)!;
    expect(cut.characters.length, 200);
    expect(cut, endsWith('…'));
    expect(cut.characters.take(199).toString(), '👩‍👩‍👧' * 199);
  });

  test('a cut never leaves half a placeholder', () {
    // 198 letters, then a control that draws as <U+0007> (8 characters).
    for (var pad = 190; pad <= 199; pad++) {
      final cut = curatorServerText('${'a' * pad}\u0007\u0007tail')!;
      expect(cut, isNot(matches(RegExp(r'<(U(\+[0-9A-F]*)?)?…$'))));
      expect(cut, endsWith('…'));
      expect(cut.characters.length, lessThanOrEqualTo(200));
    }
  });

  test('the limit is the parameter', () {
    expect(curatorServerText('abcdef', limit: 4), 'abc…');
    // A space right before the cut does not leave "word …".
    expect(curatorServerText('ab cdef', limit: 4), 'ab…');
  });
}
