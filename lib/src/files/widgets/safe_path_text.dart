import 'package:characters/characters.dart';

/// [text] made safe to show: a character that changes how text reads or that
/// the terminal and the screen treat as a command is drawn as a visible
/// placeholder, `<U+202E>`, never dropped and never obeyed.
///
/// This is for what a person looks at when deciding where an agent acts: a
/// folder name with U+202E (right-to-left override) would otherwise show its
/// path reordered. Bidi controls (U+202A to U+202E, U+2066 to U+2069, U+200E,
/// U+200F, U+061C), the C0 controls including CR, LF and ESC, DEL, the C1
/// controls, U+2028, U+2029, U+200B, U+2060 to U+2064, U+206A to U+206F and
/// U+FEFF are escaped, and so are the characters that draw nothing yet are
/// not spaces: the tag characters U+E0000 to U+E007F (a way to hide
/// instructions in text), the soft hyphen U+00AD, U+034F, the Hangul fillers
/// U+115F, U+1160 and U+3164, and the Mongolian vowel separator U+180E.
/// Everything else, tab aside, is left as it is.
///
/// Only the display changes. A path that is sent, stored or compared is the
/// original string.
String safePathText(String text) {
  var changed = false;
  final out = StringBuffer();
  for (final rune in text.runes) {
    if (_unsafe(rune)) {
      changed = true;
      final hex = rune.toRadixString(16).toUpperCase().padLeft(4, '0');
      out.write('<U+$hex>');
    } else {
      out.writeCharCode(rune);
    }
  }
  return changed ? out.toString() : text;
}

bool _unsafe(int rune) =>
    (rune <= 0x1F && rune != 0x09) ||
    rune == 0x7F ||
    (rune >= 0x80 && rune <= 0x9F) ||
    (rune >= 0x202A && rune <= 0x202E) ||
    (rune >= 0x2066 && rune <= 0x2069) ||
    rune == 0x200E ||
    rune == 0x200F ||
    rune == 0x061C ||
    // Line and paragraph separators, zero-width space, word joiner and the
    // invisible operators, the deprecated format controls and the BOM. The
    // zero-width (non-)joiners U+200C and U+200D are left alone: Persian and
    // Indic names need them.
    rune == 0x2028 ||
    rune == 0x2029 ||
    rune == 0x200B ||
    (rune >= 0x2060 && rune <= 0x2064) ||
    (rune >= 0x206A && rune <= 0x206F) ||
    rune == 0xFEFF ||
    // Invisible but not spaces: the soft hyphen, the combining grapheme
    // joiner, the Hangul fillers and the Mongolian vowel separator, and the
    // tag block, which can spell out text no one sees.
    rune == 0x00AD ||
    rune == 0x034F ||
    rune == 0x115F ||
    rune == 0x1160 ||
    rune == 0x3164 ||
    rune == 0x180E ||
    (rune >= 0xE0000 && rune <= 0xE007F);

final _placeholder = RegExp(r'^<U\+[0-9A-F]{4,6}>$');

/// [text] as the units a shortened display may cut between: every grapheme
/// cluster, except that a placeholder from [safePathText] is one unit, so a
/// cut never leaves `<U+20…`.
List<String> safeTextUnits(String text) {
  final chars = text.characters.toList();
  final units = <String>[];
  for (var i = 0; i < chars.length; i++) {
    if (chars[i] == '<') {
      final end = chars.indexOf('>', i);
      if (end > i && end - i <= 8) {
        final candidate = chars.sublist(i, end + 1).join();
        if (_placeholder.hasMatch(candidate)) {
          units.add(candidate);
          i = end;
          continue;
        }
      }
    }
    units.add(chars[i]);
  }
  return units;
}

/// Whether [rune] is one [safePathText] draws as a placeholder.
bool isUnsafeDisplayRune(int rune) => _unsafe(rune);
