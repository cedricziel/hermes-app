/// `CodeColourPlan` decides from the text, in document order, which code
/// blocks are coloured (see `bounded_markdown.dart`). These cases read the
/// plan directly, without a widget: the limits at their boundaries, the
/// occurrence key, and each fence form the scan has to read.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/widgets/bounded_markdown.dart';

const _fence = '```';

String _fenced(String code, [String info = 'js']) =>
    '$_fence$info\n$code\n$_fence';

/// Code of exactly [length] characters in lines of at most 78.
String _code(int length, [String c = 'x']) {
  final chars = [for (var i = 0; i < length; i++) i % 79 == 78 ? '\n' : c];
  if (chars.last == '\n') {
    chars[length - 1] = c;
    chars[length - 2] = '\n';
  }
  return chars.join();
}

String _doc(List<String> codes) =>
    [for (final c in codes) 'Para.\n\n${_fenced(c)}\n\n'].join();

void main() {
  group('limits', () {
    test('an ordinary block is admitted, an unknown one is not', () {
      final plan = CodeColourPlan.scan(_doc(['final a = 1;']));
      expect(plan.admits('final a = 1;', 0), isTrue);
      expect(plan.admits('final b = 2;', 0), isFalse);
      expect(plan.admits('', 0), isFalse);
    });

    test('a line of 500 characters is admitted, 501 is not', () {
      final fits = 'a' * kHighlightMaxLine;
      final over = 'a' * (kHighlightMaxLine + 1);
      final plan = CodeColourPlan.scan(_doc([fits, over]));
      expect(plan.admits(fits, 0), isTrue);
      expect(plan.admits(over, 0), isFalse);
    });

    test('a block of 8000 characters is admitted, 8001 is not', () {
      final fits = _code(kHighlightMaxBlock);
      final over = _code(kHighlightMaxBlock + 1);
      expect(CodeColourPlan.scan(_doc([fits])).admits(fits, 0), isTrue);
      expect(CodeColourPlan.scan(_doc([over])).admits(over, 0), isFalse);
    });

    test('blocks summing to 10000 are all admitted, 10001 stops the last', () {
      final five = [for (var i = 0; i < 5; i++) _code(2000, '$i')];
      final plan = CodeColourPlan.scan(_doc(five));
      expect([for (final c in five) plan.admits(c, 0)], everyElement(isTrue));
      final over = [...five.sublist(0, 4), _code(2001, '4')];
      final plan2 = CodeColourPlan.scan(_doc(over));
      expect(plan2.admits(over[3], 0), isTrue);
      expect(plan2.admits(over[4], 0), isFalse);
    });

    test('a block that does not fit takes no room from later blocks', () {
      final big = _code(7000, 'a');
      final alsoBig = _code(7000, 'b');
      final small = _code(2000, 'c');
      final plan = CodeColourPlan.scan(_doc([big, alsoBig, small]));
      expect(plan.admits(big, 0), isTrue);
      expect(plan.admits(alsoBig, 0), isFalse);
      expect(plan.admits(small, 0), isTrue);
    });

    test('custom limits apply', () {
      final plan = CodeColourPlan.scan(
        _doc(['abcdef', 'abcd']),
        maxLine: 5,
        maxBlock: 100,
        maxDocument: 100,
      );
      expect(plan.admits('abcdef', 0), isFalse);
      expect(plan.admits('abcd', 0), isTrue);
    });
  });

  group('the (code, occurrence) key', () {
    test('two identical blocks: the first is admitted, the second is not', () {
      final same = _code(6000);
      final plan = CodeColourPlan.scan(_doc([same, same]));
      expect(plan.admits(same, 0), isTrue);
      expect(plan.admits(same, 1), isFalse);
    });

    test('occurrences count identical code in document order', () {
      final a = _code(4000, 'a');
      final b = _code(4000, 'b');
      final plan = CodeColourPlan.scan(_doc([a, b, a]));
      expect(plan.admits(a, 0), isTrue);
      expect(plan.admits(b, 0), isTrue);
      expect(plan.admits(a, 1), isFalse);
    });

    test('an occurrence the document does not have is plain', () {
      final plan = CodeColourPlan.scan(_doc(['a = 1;']));
      expect(plan.admits('a = 1;', 1), isFalse);
      expect(plan.admits('a = 1;', -1), isFalse);
    });

    test('each copy is judged at its own place', () {
      // After a block that fills the document no copy fits; before it, both do.
      final fill = _code(8000, 'f');
      final rest = _code(2500, 'r');
      final plan = CodeColourPlan.scan(_doc([fill, rest, rest]));
      expect(plan.admits(rest, 0), isFalse);
      expect(plan.admits(rest, 1), isFalse);
      final plan2 = CodeColourPlan.scan(_doc([rest, rest, fill]));
      expect(plan2.admits(rest, 0), isTrue);
      expect(plan2.admits(rest, 1), isTrue);
      expect(plan2.admits(fill, 0), isFalse);
    });
  });

  group('fence forms', () {
    test('an unclosed fence at the end is a block of the code so far', () {
      final plan = CodeColourPlan.scan('Para.\n\n${_fence}js\n${_code(300)}');
      expect(plan.admits(_code(300), 0), isTrue);
    });

    test('the start of an unclosed tail is judged on its own text', () {
      final closed = [_code(4500, 'c'), _code(4500, 'd')];
      final tail = _code(2000, 't');
      final plan = CodeColourPlan.scan('${_doc(closed)}${_fence}js\n$tail');
      expect(plan.admits(tail, 0), isFalse, reason: 'the whole tail');
      expect(plan.admits(tail.substring(0, 500), 0), isTrue);
      expect(plan.admits(tail.substring(0, 1500), 0), isFalse);
    });

    test('a block that is not the start of the tail stays unknown', () {
      final plan = CodeColourPlan.scan('${_fence}js\nabc');
      expect(plan.admits('abd', 0), isFalse);
      expect(plan.admits('abcd', 0), isFalse);
    });

    test('a closed document has no tail', () {
      final plan = CodeColourPlan.scan(_doc(['abcdef']));
      expect(plan.admits('abc', 0), isFalse);
    });

    test('tilde fences and fences of four backticks', () {
      final plan = CodeColourPlan.scan(
        'Para.\n\n~~~python title="x"\nprint(1)\n~~~\n\n'
        '````js {1,3}\na();\n$_fence\ninner\n$_fence\nb();\n````\n',
      );
      expect(plan.admits('print(1)', 0), isTrue);
      expect(plan.admits('a();\n$_fence\ninner\n$_fence\nb();', 0), isTrue);
    });

    test('a fence in a list item loses the item indent', () {
      final plan = CodeColourPlan.scan(
        '- item\n\n  ${_fence}js\n  one();\n    two();\n  $_fence\n\n'
        '1. numbered\n\n   ${_fence}py\n   x = 1\n   $_fence\n',
      );
      expect(plan.admits('one();\n  two();', 0), isTrue);
      expect(plan.admits('x = 1', 0), isTrue);
    });

    test('a fence in a quote and in an alert', () {
      final plan = CodeColourPlan.scan(
        '> quoted\n>\n> ${_fence}js\n> q();\n> $_fence\n\n'
        '> [!NOTE]\n> text\n>\n> ${_fence}js\n> n();\n> $_fence\n',
      );
      expect(plan.admits('q();', 0), isTrue);
      expect(plan.admits('n();', 0), isTrue);
    });

    test('a fence in a footnote definition', () {
      final plan = CodeColourPlan.scan(
        'Text[^a].\n\n[^a]: note\n\n    ${_fence}js\n    f();\n    $_fence\n',
      );
      expect(plan.admits('f();', 0), isTrue);
    });

    test('an HTML code block, with its entities decoded as the parser does', () {
      final plan = CodeColourPlan.scan(
        'Para\n\n<pre><code class="language-js">a &amp;&amp; b;</code></pre>\n',
      );
      expect(plan.admits('a && b;', 0), isTrue);
      expect(plan.admits('a &amp;&amp; b;', 0), isFalse);
    });

    test('CRLF line ends give the key of the same code with LF', () {
      final plan = CodeColourPlan.scan(
        'Para\r\n\r\n${_fence}js\r\nline1\r\nline2\r\n$_fence\r\n',
      );
      expect(plan.admits('line1\nline2', 0), isTrue);
      expect(plan.admits('line1\r\nline2', 0), isTrue);
    });

    test('a lone surrogate becomes U+FFFD on the scan side', () {
      final plan = CodeColourPlan.scan(
        'Para\n\n${_fence}js\nx\uD800y\n$_fence\n',
      );
      expect(plan.admits('x�y', 0), isTrue);
    });

    test('text with no code has an empty plan', () {
      final plan = CodeColourPlan.scan('Just *prose*, and `inline`.');
      expect(plan.admits('inline', 0), isFalse);
    });
  });
}
