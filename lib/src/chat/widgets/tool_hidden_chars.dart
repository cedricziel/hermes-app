import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../files/widgets/safe_path_text.dart' show isUnsafeDisplayRune;
import '../../theme/hermes_theme.dart';

/// The most boxed escapes one text draws. Each box is a widget in the text's
/// layout, so a body full of hidden characters must not build thousands of
/// them: past this the rest are the plain `<U+XXXX>` text of the Files
/// preview, which costs no widget.
const int kToolHiddenBoxMax = 200;

/// [text] with every carriage return that belongs to a CRLF removed, for
/// display. A lone carriage return stays (and is boxed); copying uses the
/// original.
String withoutCrlfReturns(String text) =>
    text.contains('\r\n') ? text.replaceAll('\r\n', '\n') : text;

/// How many boxed escapes one text has left to draw, shared by every run of
/// the text.
class HiddenBoxBudget {
  HiddenBoxBudget([this.left = kToolHiddenBoxMax]);

  int left;

  /// Whether the last character was U+1F3F4 or a tag character of the flag
  /// sequence that follows it, so the tag characters after it are part of an
  /// emoji (England, Scotland, Wales) and not hidden text.
  bool inFlag = false;
}

bool _isTag(int rune) => rune >= 0xE0020 && rune <= 0xE007F;

/// Whether [rune] is a tag character that belongs to a flag sequence, given
/// whether the character before it ended in one ([inFlag]).
bool _tagInFlag(int rune, bool inFlag) => inFlag && _isTag(rune);

bool _flagAfter(int rune, bool inFlag) =>
    rune == 0x1F3F4 || _tagInFlag(rune, inFlag);

String _hex(int rune) =>
    'U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')}';

/// Whether [rune] is drawn as a boxed escape: the characters that hide or
/// reorder text (controls other than tab and line break, zero-width and
/// bidirectional characters, the byte order mark), as the Files preview
/// escapes them. A line break is never one in a text; the tree boxes the line
/// break of a decoded string itself.
bool isHiddenToolRune(int rune) => rune != 0x0A && isUnsafeDisplayRune(rune);

/// Whether [text] has a character [hiddenCharSpans] would box, so a text
/// without one is drawn as plain runs.
bool hasHiddenToolText(String text) {
  var inFlag = false;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    // ASCII text and most of the rest have no hidden character.
    if (unit >= 0x20 && unit < 0x7F) {
      inFlag = false;
      continue;
    }
    final rune = _runeAt(text, i);
    if (isHiddenToolRune(rune) && !_tagInFlag(rune, inFlag)) return true;
    inFlag = _flagAfter(rune, inFlag);
    if (rune > 0xFFFF) i++;
  }
  return false;
}

/// The label a screen reader reads for [rune]'s box.
String hiddenCharLabel(BuildContext context, int rune) =>
    context.l10n.chatWidgetsToolValueHiddenChar(_hex(rune));

/// [text] as spans: ordinary runs stay [TextSpan]s with [style], and every
/// hidden character is a box ([HiddenCharBox]) while [budget] lasts, then the
/// plain `<U+XXXX>` text. Joined, the visible text is [text] with each hidden
/// character shown as its escape; the characters themselves never reach the
/// screen.
List<InlineSpan> hiddenCharSpans(
  BuildContext context,
  String text,
  TextStyle? style,
  HiddenBoxBudget budget, {
  TextStyle? boxStyle,
  bool boxLineBreaks = false,
}) {
  bool hidden(int rune) =>
      (isHiddenToolRune(rune) && !_tagInFlag(rune, budget.inFlag)) ||
      (boxLineBreaks && rune == 0x0A);
  final spans = <InlineSpan>[];
  var plainStart = 0;
  void flush(int end) {
    if (end > plainStart) {
      spans.add(TextSpan(text: text.substring(plainStart, end), style: style));
    }
  }

  var i = 0;
  while (i < text.length) {
    final rune = _runeAt(text, i);
    final width = rune > 0xFFFF ? 2 : 1;
    final isHidden = hidden(rune);
    final startedFlag = budget.inFlag;
    budget.inFlag = _flagAfter(rune, budget.inFlag);
    if (isHidden) {
      flush(i);
      if (budget.left > 0) {
        budget.left--;
        final lineBreak = rune == 0x0A;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: HiddenCharBox(
              code: lineBreak ? r'\n' : _hex(rune),
              label: lineBreak
                  ? context.l10n.chatWidgetsToolValueLineBreak
                  : hiddenCharLabel(context, rune),
              textStyle: boxStyle ?? style,
            ),
          ),
        );
      } else {
        // Out of boxes: the rest of this run is one span, so ten thousand
        // hidden characters cost one span and not ten thousand.
        spans.add(
          TextSpan(
            text: _escapedRest(
              text,
              i,
              boxLineBreaks: boxLineBreaks,
              inFlag: startedFlag,
            ),
            style: style,
          ),
        );
        return spans;
      }
      plainStart = i + width;
    }
    i += width;
  }
  flush(text.length);
  return spans;
}

String _escapedRest(
  String text,
  int from, {
  required bool boxLineBreaks,
  required bool inFlag,
}) {
  final out = StringBuffer();
  var i = from;
  while (i < text.length) {
    final rune = _runeAt(text, i);
    if (boxLineBreaks && rune == 0x0A) {
      out.write(r'\n');
    } else if (isHiddenToolRune(rune) && !_tagInFlag(rune, inFlag)) {
      out.write('<${_hex(rune)}>');
    } else {
      out.writeCharCode(rune);
    }
    inFlag = _flagAfter(rune, inFlag);
    i += rune > 0xFFFF ? 2 : 1;
  }
  return out.toString();
}

int _runeAt(String text, int i) {
  final unit = text.codeUnitAt(i);
  if (unit >= 0xD800 &&
      unit <= 0xDBFF &&
      i + 1 < text.length &&
      (text.codeUnitAt(i + 1) & 0xFC00) == 0xDC00) {
    return 0x10000 +
        ((unit - 0xD800) << 10) +
        (text.codeUnitAt(i + 1) - 0xDC00);
  }
  return unit;
}

/// One hidden character, drawn as its code in a box: the border is the
/// marker, so it does not rely on colour. A screen reader hears [label]
/// instead of the code.
class HiddenCharBox extends StatelessWidget {
  const HiddenCharBox({
    super.key,
    required this.code,
    required this.label,
    this.textStyle,
  });

  /// What the box shows, such as `U+202E` or `\n`.
  final String code;

  /// What a screen reader says, such as "hidden character U+202E".
  final String label;

  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final subtle = context.hermesColors.subtleText;
    final base = textStyle ?? DefaultTextStyle.of(context).style;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          border: Border.all(color: subtle),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          code,
          style: base.copyWith(
            fontSize: (base.fontSize ?? 12) * 0.8,
            height: 1.2,
            color: subtle,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.normal,
          ),
        ),
      ),
    );
  }
}
