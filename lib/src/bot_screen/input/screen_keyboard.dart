import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../rfb/rfb_input_sink.dart';
import 'keysyms.dart';

/// What a hardware key event came to.
enum ScreenKeyResult {
  /// It went to the screen as key events.
  sent,

  /// It is the Paste chord: the viewer pastes, nothing was sent.
  paste,

  /// It is the key that closes the viewer (⌘. on a Mac, F8 elsewhere).
  close,

  /// It is a reserved chord repeating, or otherwise done with: the key is
  /// taken and nothing is sent.
  consumed,

  /// It is the app's or the system's, or has no keysym: nothing was sent and
  /// the key is left to whoever handles it next.
  ignored,
}

const _controlLeft = 0xffe3;
const _altLeft = 0xffe9;
const _tab = 0xff09;
const _escape = 0xff1b;
const _backSpace = 0xff08;
const _arrowLeft = 0xff51;
const _arrowRight = 0xff53;
const _f8 = 0xffc5;
const _enter = 0xff0d;

/// The keys of the key bar, which send a keysym of their own.
abstract final class ScreenKeys {
  static const escape = _escape;
  static const tab = _tab;
  static const backSpace = _backSpace;
  static const arrowLeft = _arrowLeft;
  static const arrowRight = _arrowRight;
  static const f8 = _f8;
  static const enter = _enter;
}

/// Turns the keys of the person in control into key events for the screen.
///
/// Hardware keys come through [handle]. The reserved keys stay with the app:
/// on a Mac (and an iPad, whose Command key is the same) ⌘V is Paste, ⌘Q, ⌘W,
/// ⌘H, ⌘M and ⌘Tab belong to the app and the system, ⌘. closes the viewer and
/// any other ⌘ chord reaches the screen with Control in its place (⌘A is
/// Ctrl+A). Elsewhere Ctrl+V is Paste, F8 closes the viewer, and Alt+Tab,
/// Alt+F4 and every Super chord belong to the system. Escape and everything
/// else go to the screen.
///
/// The key bar and the on-screen keyboard come through [tap] and [typeText];
/// [ctrl] and [alt] are latched for the next key, as on the key bar. A key
/// pressed here is released again on its key-up, and [releaseAll] lets go of
/// whatever is still held (a key whose release the app will never see, such as
/// one held while the focus moved). Nothing here keeps or logs what is typed:
/// it only ever leaves as the key events it returns.
class ScreenKeyboard {
  ScreenKeyboard(this._sink, {required this.platform});

  final RfbInputSink _sink;
  final TargetPlatform platform;
  static const _mapper = KeysymMapper();

  /// Control held for the next key, from the key bar.
  final ctrl = ValueNotifier(false);

  /// Alt held for the next key, from the key bar.
  final alt = ValueNotifier(false);

  /// The keysyms sent for each key still down, in the order they went out.
  final _held = <PhysicalKeyboardKey, List<int>>{};

  bool get _commandIsControl =>
      platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;

  /// Sends a hardware key event, or says what else it is.
  ScreenKeyResult handle(KeyEvent event) {
    final key = event.logicalKey;
    if (event is KeyUpEvent) return _release(event.physicalKey);
    final keyboard = HardwareKeyboard.instance;
    final meta = keyboard.isMetaPressed;

    if (_isMeta(key)) return ScreenKeyResult.ignored;
    final reserved = _reserved(key, keyboard);
    if (reserved != null) {
      // A held chord repeating does not paste or close again.
      final once =
          reserved == ScreenKeyResult.paste ||
          reserved == ScreenKeyResult.close;
      return once && event is KeyRepeatEvent
          ? ScreenKeyResult.consumed
          : reserved;
    }

    if (event is KeyRepeatEvent && _held.containsKey(event.physicalKey)) {
      return _repeat(event.physicalKey);
    }
    final keysym = _keysym(event, controlHeld: keyboard.isControlPressed);
    if (keysym == null) return ScreenKeyResult.ignored;
    final modifiers = <int>[
      if (_commandIsControl && meta) _controlLeft,
      if (ctrl.value) _controlLeft,
      if (alt.value) _altLeft,
    ];
    _clearLatches();
    _guarded(() {
      final sent = <int>[];
      for (final modifier in modifiers) {
        _sink.key(modifier, down: true);
        sent.add(modifier);
      }
      _sink.key(keysym, down: true);
      sent.add(keysym);
      _held[event.physicalKey] = sent;
    });
    return ScreenKeyResult.sent;
  }

  /// What a reserved key does instead of reaching the screen, or null for a
  /// key that is not reserved.
  ScreenKeyResult? _reserved(
    LogicalKeyboardKey key,
    HardwareKeyboard keyboard,
  ) {
    if (_commandIsControl) {
      if (!keyboard.isMetaPressed) return null;
      if (key == LogicalKeyboardKey.keyV) return ScreenKeyResult.paste;
      if (key == LogicalKeyboardKey.period) return ScreenKeyResult.close;
      return _appKeys.contains(key) ? ScreenKeyResult.ignored : null;
    }
    if (keyboard.isMetaPressed) return ScreenKeyResult.ignored;
    if (key == LogicalKeyboardKey.f8) return ScreenKeyResult.close;
    if (keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        key == LogicalKeyboardKey.keyV) {
      return ScreenKeyResult.paste;
    }
    if (keyboard.isAltPressed &&
        (key == LogicalKeyboardKey.tab || key == LogicalKeyboardKey.f4)) {
      return ScreenKeyResult.ignored;
    }
    return null;
  }

  ScreenKeyResult _release(PhysicalKeyboardKey key) {
    final sent = _held.remove(key);
    if (sent == null) return ScreenKeyResult.ignored;
    _guarded(() {
      for (final keysym in sent.reversed) {
        _sink.key(keysym, down: false);
      }
    });
    return ScreenKeyResult.sent;
  }

  /// A held key repeating: the screen hears it pressed again.
  ScreenKeyResult _repeat(PhysicalKeyboardKey key) {
    final sent = _held[key];
    if (sent == null || sent.isEmpty) return ScreenKeyResult.ignored;
    _guarded(() => _sink.key(sent.last, down: true));
    return ScreenKeyResult.sent;
  }

  /// Presses and releases [keysym] (Escape, Tab, an arrow, F8), with Control
  /// and Alt if they are latched.
  void tap(int keysym) => _chord([keysym]);

  /// Types [text] as key presses of the matching keysyms, the first with
  /// Control and Alt if they are latched. A character with no key (a control
  /// character) is dropped.
  void typeText(String text) {
    for (final rune in text.runes) {
      final int keysym;
      try {
        keysym = _mapper.forCodePoint(rune);
      } on ArgumentError {
        continue;
      }
      _chord([keysym]);
    }
  }

  /// Presses Control+[keysym] and releases both: the Paste chord, whatever the
  /// platform.
  void pressControl(int keysym) {
    _guarded(() {
      _sink
        ..key(_controlLeft, down: true)
        ..key(keysym, down: true)
        ..key(keysym, down: false)
        ..key(_controlLeft, down: false);
    });
  }

  void _chord(List<int> keysyms) {
    final modifiers = <int>[
      if (ctrl.value) _controlLeft,
      if (alt.value) _altLeft,
    ];
    _clearLatches();
    _guarded(() {
      for (final modifier in modifiers) {
        _sink.key(modifier, down: true);
      }
      for (final keysym in keysyms) {
        _sink
          ..key(keysym, down: true)
          ..key(keysym, down: false);
      }
      for (final modifier in modifiers.reversed) {
        _sink.key(modifier, down: false);
      }
    });
  }

  /// Lets go of every key still down.
  void releaseAll() {
    final held = _held.values.toList();
    _held.clear();
    _guarded(() {
      for (final sent in held) {
        for (final keysym in sent.reversed) {
          _sink.key(keysym, down: false);
        }
      }
    });
  }

  void _clearLatches() {
    ctrl.value = false;
    alt.value = false;
  }

  /// The keysym a key event stands for, or null when it has none: a
  /// non-printing key from the table, else the character it typed, else (with
  /// Control held, when the character is a control code) its letter.
  int? _keysym(KeyEvent event, {required bool controlHeld}) {
    final known = _mapper.forLogicalKey(event.logicalKey);
    if (known != null) return known;
    final character = event.character;
    if (character != null && character.isNotEmpty && !controlHeld) {
      try {
        return _mapper.forCodePoint(character.runes.first);
      } on ArgumentError {
        return null;
      }
    }
    final label = event.logicalKey.keyLabel;
    if (label.runes.length != 1) return null;
    final shifted = HardwareKeyboard.instance.isShiftPressed;
    try {
      return _mapper.forCodePoint(
        (shifted ? label : label.toLowerCase()).runes.first,
      );
    } on ArgumentError {
      return null;
    }
  }

  bool _isMeta(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.metaLeft || key == LogicalKeyboardKey.metaRight;

  /// A closed sink throws [StateError]; input after the stream ended is
  /// dropped.
  void _guarded(void Function() send) {
    try {
      send();
    } on StateError {
      return;
    }
  }

  void dispose() {
    releaseAll();
    ctrl.dispose();
    alt.dispose();
  }
}

/// The ⌘ chords that stay with the app and the system.
final _appKeys = {
  LogicalKeyboardKey.keyQ,
  LogicalKeyboardKey.keyW,
  LogicalKeyboardKey.keyH,
  LogicalKeyboardKey.keyM,
  LogicalKeyboardKey.tab,
};
