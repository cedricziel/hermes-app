import 'package:flutter/services.dart';

/// One KeyEvent to send: press ([down]) or release of an X11 [keysym].
typedef KeyStroke = ({int keysym, bool down});

/// Turns Flutter keys and typed characters into X11 keysyms (`keysymdef.h`).
///
/// It keeps nothing and logs nothing: what is typed only ever leaves as the
/// keysyms it returns.
class KeysymMapper {
  const KeysymMapper({this.commandAsControl = false});

  /// Maps the Meta keys (Command on a Mac) to Control, so that Command+A
  /// reaches a Linux desktop as Ctrl+A.
  final bool commandAsControl;

  /// The keysym of a key that prints nothing (Escape, arrows, F-keys, the
  /// modifiers, ...), or null for any other key, whose character the caller
  /// maps with [forCodePoint].
  int? forLogicalKey(LogicalKeyboardKey key) {
    if (commandAsControl) {
      if (key == LogicalKeyboardKey.metaLeft) return _controlLeft;
      if (key == LogicalKeyboardKey.metaRight) return _controlRight;
    }
    return _nonPrinting[key];
  }

  /// The keysym of the character [codePoint]: itself for 0x20 to 0x7e and
  /// 0xa0 to 0xff, the key the character stands for when it is Backspace, Tab,
  /// a line break, Escape or Delete, and otherwise the X11 Unicode keysym.
  ///
  /// Throws [ArgumentError] (without the value) for a value that is not a
  /// character and for a control character that has no key of its own (NUL,
  /// the other C0 and the C1 controls): `0x01000000 + codepoint` would name no
  /// key. Ctrl+letter comes from the logical key with Control pressed, not
  /// from the control character.
  int forCodePoint(int codePoint) {
    if (codePoint < 0 ||
        codePoint > 0x10FFFF ||
        (codePoint >= 0xD800 && codePoint <= 0xDFFF)) {
      throw ArgumentError('The value is not a character');
    }
    if ((codePoint >= 0x20 && codePoint <= 0x7e) ||
        (codePoint >= 0xa0 && codePoint <= 0xff)) {
      return codePoint;
    }
    final key = _controlCharacters[codePoint];
    if (key != null) return key;
    if (codePoint < 0x20 || (codePoint >= 0x7f && codePoint < 0xa0)) {
      throw ArgumentError('The control character has no key');
    }
    return 0x01000000 + codePoint;
  }

  /// The strokes that type [text]: a press and a release for each code point
  /// (a grapheme cluster is typed as its parts), with CRLF as one Return.
  ///
  /// Throws [ArgumentError] for a lone surrogate or a control character
  /// without a key (see [forCodePoint]) instead of replacing it.
  List<KeyStroke> text(String text) {
    final strokes = <KeyStroke>[];
    final runes = text.runes.toList();
    for (var i = 0; i < runes.length; i++) {
      if (runes[i] == 0x0D && i + 1 < runes.length && runes[i + 1] == 0x0A) {
        i++;
      }
      final keysym = forCodePoint(runes[i]);
      strokes
        ..add((keysym: keysym, down: true))
        ..add((keysym: keysym, down: false));
    }
    return strokes;
  }
}

const _controlLeft = 0xffe3;
const _controlRight = 0xffe4;

final _nonPrinting = <LogicalKeyboardKey, int>{
  LogicalKeyboardKey.escape: 0xff1b,
  LogicalKeyboardKey.tab: 0xff09,
  LogicalKeyboardKey.enter: 0xff0d,
  LogicalKeyboardKey.backspace: 0xff08,
  LogicalKeyboardKey.insert: 0xff63,
  LogicalKeyboardKey.delete: 0xffff,
  LogicalKeyboardKey.home: 0xff50,
  LogicalKeyboardKey.end: 0xff57,
  LogicalKeyboardKey.pageUp: 0xff55,
  LogicalKeyboardKey.pageDown: 0xff56,
  LogicalKeyboardKey.arrowLeft: 0xff51,
  LogicalKeyboardKey.arrowUp: 0xff52,
  LogicalKeyboardKey.arrowRight: 0xff53,
  LogicalKeyboardKey.arrowDown: 0xff54,
  LogicalKeyboardKey.f1: 0xffbe,
  LogicalKeyboardKey.f2: 0xffbf,
  LogicalKeyboardKey.f3: 0xffc0,
  LogicalKeyboardKey.f4: 0xffc1,
  LogicalKeyboardKey.f5: 0xffc2,
  LogicalKeyboardKey.f6: 0xffc3,
  LogicalKeyboardKey.f7: 0xffc4,
  LogicalKeyboardKey.f8: 0xffc5,
  LogicalKeyboardKey.f9: 0xffc6,
  LogicalKeyboardKey.f10: 0xffc7,
  LogicalKeyboardKey.f11: 0xffc8,
  LogicalKeyboardKey.f12: 0xffc9,
  LogicalKeyboardKey.shiftLeft: 0xffe1,
  LogicalKeyboardKey.shiftRight: 0xffe2,
  LogicalKeyboardKey.controlLeft: _controlLeft,
  LogicalKeyboardKey.controlRight: _controlRight,
  LogicalKeyboardKey.capsLock: 0xffe5,
  LogicalKeyboardKey.altLeft: 0xffe9,
  LogicalKeyboardKey.altRight: 0xffea,
  LogicalKeyboardKey.metaLeft: 0xffeb,
  LogicalKeyboardKey.metaRight: 0xffec,
};

/// Control characters that are keys, not Unicode keysyms.
const _controlCharacters = <int, int>{
  0x08: 0xff08, // BackSpace
  0x09: 0xff09, // Tab
  0x0a: 0xff0d, // Return
  0x0d: 0xff0d,
  0x1b: 0xff1b, // Escape
  0x7f: 0xffff, // Delete
};
