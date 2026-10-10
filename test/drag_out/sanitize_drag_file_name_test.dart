import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/drag_out/sanitize_drag_file_name.dart';

void main() {
  test('leaves a plain name alone', () {
    expect(sanitizeDragFileName('report.pdf'), 'report.pdf');
    expect(
      sanitizeDragFileName('Q3 plan (final).docx'),
      'Q3 plan (final).docx',
    );
  });

  test('removes path separators, colons and control characters', () {
    expect(sanitizeDragFileName('a/b\\c:d.txt'), 'a_b_c_d.txt');
    expect(sanitizeDragFileName('a\u0000b\u0007c\u007f.txt'), 'a_b_c_.txt');
    expect(sanitizeDragFileName('line\nbreak.txt'), 'line_break.txt');
  });

  test('a hostile name has no separators or colon and keeps its extension', () {
    final name = sanitizeDragFileName('../../x/y: z.pdf');
    expect(name, isNot(contains('/')));
    expect(name, isNot(contains('\\')));
    expect(name, isNot(contains(':')));
    expect(name, isNot(startsWith('.')));
    expect(name, endsWith('.pdf'));
  });

  test('strips leading dots and spaces', () {
    expect(sanitizeDragFileName('.env'), 'env');
    expect(sanitizeDragFileName('  ..hidden.txt'), 'hidden.txt');
  });

  test('uses the fallback when nothing is left', () {
    expect(sanitizeDragFileName(''), 'File');
    expect(sanitizeDragFileName('...'), 'File');
    expect(sanitizeDragFileName('  ', fallback: 'Chat'), 'Chat');
    expect(sanitizeDragFileName('..', fallback: 'Attachment'), 'Attachment');
  });

  test('adds the extension only when the name has none', () {
    expect(sanitizeDragFileName('Plan', extension: 'md'), 'Plan.md');
    expect(sanitizeDragFileName('Plan.txt', extension: 'md'), 'Plan.txt');
    expect(
      sanitizeDragFileName('', fallback: 'Chat', extension: 'md'),
      'Chat.md',
    );
  });

  test('bounds the length and keeps the extension', () {
    final name = sanitizeDragFileName('${'a' * 300}.pdf');
    expect(name.length, dragFileNameLimit);
    expect(name, endsWith('.pdf'));
  });

  test('bounds a long name with no extension', () {
    expect(sanitizeDragFileName('b' * 300).length, dragFileNameLimit);
  });

  test('bounds a name whose extension is absurdly long', () {
    final name = sanitizeDragFileName('a.${'x' * 300}');
    expect(name.length, dragFileNameLimit);
  });

  test('removes characters that reorder or hide text', () {
    final name = sanitizeDragFileName(
      'invoice\u202Efdp.exe\u2066x\u200F\u061C',
    );

    expect(name, 'invoicefdp.exex');
  });

  test('never splits a surrogate pair or a family emoji', () {
    final emoji = '\u{1F600}' * 200;
    final cut = sanitizeDragFileName('$emoji.pdf');

    expect(cut.characters.length, dragFileNameLimit);
    expect(cut, endsWith('.pdf'));
    expect(String.fromCharCodes(cut.runes), cut, reason: 'valid UTF-16');

    final family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}' * 200;
    final cutFamily = sanitizeDragFileName(family);
    expect(cutFamily.characters.length, dragFileNameLimit);
    expect(
      cutFamily.characters.last,
      '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}',
    );
  });
}
