/// [text] made safe to show: a character that changes how text reads or that
/// the terminal and the screen treat as a command is drawn as a visible
/// placeholder, `⟨U+202E⟩`, never dropped and never obeyed.
///
/// This is for what a person looks at when deciding where an agent acts: a
/// folder name with U+202E (right-to-left override) would otherwise show its
/// path reordered. Bidi controls (U+202A to U+202E, U+2066 to U+2069, U+200E,
/// U+200F, U+061C), the C0 controls including CR, LF and ESC, DEL and the C1
/// controls are escaped. Everything else, tab aside, is left as it is.
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
      out.write('⟨U+$hex⟩');
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
    rune == 0x061C;
