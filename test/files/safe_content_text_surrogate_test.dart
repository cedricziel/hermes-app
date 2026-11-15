import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/widgets/safe_path_text.dart';

void main() {
  group('lone UTF-16 surrogates', () {
    test('a lone high or low surrogate becomes U+FFFD', () {
      expect(safeContentText('a\ud800'), 'a�');
      expect(safeContentText('a\ud800b'), 'a�b');
      expect(safeContentText('\udc00x'), '�x');
      expect(safeContentText('\ud800\ud800'), '��');
      expect(safeContentText('\udc00\ud800'), '��');
      expect(safePathText('dir\ud800'), 'dir�');
    });

    test('valid pairs stay untouched', () {
      const emoji = 'ok \u{1F600} \u{1F1E9}\u{1F1EA}';
      expect(safeContentText(emoji), emoji);
      expect(wellFormedText(emoji), emoji);
      expect(safeContentText('\u{1F600}\ud800'), '\u{1F600}�');
    });

    test('the placeholders and line breaks still work beside one', () {
      final input = 'a\r\n${String.fromCharCode(0x202E)}\ud800\n';
      expect(
        safeContentText(input),
        'a\n<U+202E>${String.fromCharCode(0xFFFD)}\n',
      );
    });

    test('the result is always well formed', () {
      for (final text in ['\ud800', 'x\udfff', 'a\ud83d', '\ud83d\u{1F600}']) {
        expect(_wellFormed(safeContentText(text)), isTrue, reason: text);
      }
    });
  });
}

bool _wellFormed(String text) {
  try {
    Uri.encodeFull(text);
    return true;
  } on ArgumentError {
    return false;
  }
}
