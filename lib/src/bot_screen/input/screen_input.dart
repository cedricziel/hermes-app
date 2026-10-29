import 'package:flutter/foundation.dart';

import '../rfb/rfb_input_sink.dart';
import 'screen_keyboard.dart';
import 'screen_paste.dart';

/// What a person in control sends input through for one stream: the [sink]
/// (the stream's client, counting what goes through it), the [keyboard] that
/// maps keys and typed text, and [paste].
///
/// It belongs to the stream. [dispose] lets go of keys still held and empties
/// the screen's clipboard, which the owner does before it closes the stream.
class ScreenInput {
  ScreenInput(
    RfbInputSink client, {
    required TargetPlatform platform,
    required Future<String?> Function() readClipboard,
    required VoidCallback onEvent,
  }) : sink = _CountingSink(client, onEvent) {
    keyboard = ScreenKeyboard(sink, platform: platform);
    paste = ScreenPaste(sink, keyboard, readClipboard: readClipboard);
  }

  final RfbInputSink sink;
  late final ScreenKeyboard keyboard;
  late final ScreenPaste paste;

  void dispose() {
    keyboard.dispose();
    paste.dispose();
  }
}

/// Counts the messages it passes on, and nothing else about them.
class _CountingSink implements RfbInputSink {
  _CountingSink(this._inner, this._onEvent);

  final RfbInputSink _inner;
  final VoidCallback _onEvent;

  @override
  void pointer(int x, int y, int buttonMask) {
    _inner.pointer(x, y, buttonMask);
    _onEvent();
  }

  @override
  void key(int keysym, {required bool down}) {
    _inner.key(keysym, down: down);
    _onEvent();
  }

  @override
  void scroll(int x, int y, {int dx = 0, int dy = 0}) {
    _inner.scroll(x, y, dx: dx, dy: dy);
    _onEvent();
  }

  @override
  void cutText(String text) {
    _inner.cutText(text);
    _onEvent();
  }
}
