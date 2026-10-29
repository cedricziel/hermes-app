import 'package:flutter/foundation.dart';

import '../rfb/rfb_input_sink.dart';
import 'screen_keyboard.dart';
import 'screen_paste.dart';

/// What a person in control sends input through for one stream: the [sink]
/// (the stream's client, counting what goes through it), the [keyboard] that
/// maps keys and typed text, and [paste].
///
/// It belongs to the stream. [dispose] lets go of keys and pointer buttons
/// still held and empties the screen's clipboard, which the owner does while
/// this device still holds the lease and before it closes the stream; after
/// it the sink refuses everything.
class ScreenInput {
  ScreenInput(
    RfbInputSink client, {
    required TargetPlatform platform,
    required Future<String?> Function() readClipboard,
    required VoidCallback onEvent,
  }) : _counting = _CountingSink(client, onEvent) {
    keyboard = ScreenKeyboard(_counting, platform: platform);
    paste = ScreenPaste(_counting, keyboard, readClipboard: readClipboard);
  }

  final _CountingSink _counting;
  RfbInputSink get sink => _counting;
  late final ScreenKeyboard keyboard;
  late final ScreenPaste paste;

  /// Lets go of the keys and the pointer button still held, for a moment the
  /// app will not see their release in (the window lost the keyboard).
  void releaseAll() {
    keyboard.releaseAll();
    _counting.releaseButtons();
  }

  void dispose() {
    keyboard.dispose();
    paste.dispose();
    _counting.dispose();
  }
}

/// Counts the messages it passes on, and nothing else about them.
class _CountingSink implements RfbInputSink {
  _CountingSink(this._inner, this._onEvent);

  final RfbInputSink _inner;
  final VoidCallback _onEvent;
  bool _disposed = false;
  int _x = 0;
  int _y = 0;
  int _mask = 0;

  /// A closed sink throws [StateError], as the client does.
  void _open() {
    if (_disposed) throw StateError('The input is closed.');
  }

  @override
  void pointer(int x, int y, int buttonMask) {
    _open();
    _inner.pointer(x, y, buttonMask);
    _x = x;
    _y = y;
    _mask = buttonMask;
    _onEvent();
  }

  @override
  void key(int keysym, {required bool down}) {
    _open();
    _inner.key(keysym, down: down);
    _onEvent();
  }

  @override
  void scroll(int x, int y, {int dx = 0, int dy = 0}) {
    _open();
    _inner.scroll(x, y, dx: dx, dy: dy);
    _onEvent();
  }

  @override
  void cutText(String text) {
    _open();
    _inner.cutText(text);
    _onEvent();
  }

  /// Lets go of a button still down, where it was pressed.
  void releaseButtons() {
    if (_disposed || _mask == 0) return;
    try {
      pointer(_x, _y, 0);
    } on Object {
      // The stream may be gone already.
    }
  }

  void dispose() {
    releaseButtons();
    _disposed = true;
  }
}
