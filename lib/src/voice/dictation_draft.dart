import 'package:flutter/services.dart';

/// The composer's draft as a recording began, and how it reads with the
/// text recognized since: at the cursor (or the end, without one), a single
/// space from the words around it.
class DictationDraft {
  const DictationDraft(this.original);

  static final _space = RegExp(r'\s');

  /// The draft before recording, given back on cancel or failure.
  final TextEditingValue original;

  /// The draft with [recognized] in place, the cursor after it.
  TextEditingValue showing(String recognized) {
    if (recognized.isEmpty) return original;
    final text = original.text;
    final selection = original.selection.isValid
        ? original.selection
        : TextSelection.collapsed(offset: text.length);
    final before = text.substring(0, selection.start);
    final after = text.substring(selection.end);
    bool spaced(String s) => s.isEmpty || _space.hasMatch(s);
    final lead = spaced(before.isEmpty ? '' : before[before.length - 1])
        ? ''
        : ' ';
    final trail = spaced(after.isEmpty ? '' : after[0]) ? '' : ' ';
    return TextEditingValue(
      text: '$before$lead$recognized$trail$after',
      selection: TextSelection.collapsed(
        offset: before.length + lead.length + recognized.length,
      ),
    );
  }
}
