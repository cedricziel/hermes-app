import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/dictation_draft.dart';

TextEditingValue _at(String text, int offset) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: offset),
);

void main() {
  test('puts recognized text at the cursor, a space from the draft', () {
    final draft = DictationDraft(_at('Please', 6));

    expect(draft.showing('book a').text, 'Please book a');
    expect(draft.showing('book a table').text, 'Please book a table');
  });

  test('keeps the text after the cursor', () {
    final draft = DictationDraft(_at('Please now', 6));

    final value = draft.showing('book');

    expect(value.text, 'Please book now');
    expect(value.selection, const TextSelection.collapsed(offset: 11));
  });

  test('without a cursor the text goes at the end', () {
    final draft = DictationDraft(
      const TextEditingValue(
        text: 'Hi',
        selection: TextSelection.collapsed(offset: -1),
      ),
    );

    expect(draft.showing('there').text, 'Hi there');
  });

  test('an empty draft takes the text as it is', () {
    expect(
      DictationDraft(TextEditingValue.empty).showing('hello').text,
      'hello',
    );
  });

  test('nothing recognized yet shows the draft unchanged', () {
    final start = _at('Please', 6);

    expect(DictationDraft(start).showing(''), start);
  });

  test('gives the draft back', () {
    final start = _at('Please', 3);

    expect(DictationDraft(start).original, start);
  });
}
