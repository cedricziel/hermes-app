import 'dart:async';

import 'package:flutter/services.dart';

import '../rfb/rfb_input_sink.dart';
import 'screen_keyboard.dart';

/// How a paste ended.
enum PasteOutcome {
  /// The text went to the screen's clipboard and Control+V was pressed.
  pasted,

  /// The device clipboard holds no text (or could not be read).
  empty,

  /// The text has a character outside Latin-1, which the screen's clipboard
  /// cannot take. Nothing was sent.
  notLatin1,

  /// The text is over 256 KiB. Nothing was sent.
  tooLarge,

  /// The stream is gone. Nothing was sent.
  closed,
}

/// The device clipboard's text.
Future<String?> readDeviceClipboard() async =>
    (await Clipboard.getData(Clipboard.kTextPlain))?.text;

/// Pastes the device clipboard onto the screen: its text goes to the screen's
/// clipboard, Control+V is pressed there, and [clearAfter] later the screen's
/// clipboard is emptied again so that a pasted secret does not stay in it.
///
/// The text is never kept, logged or put in an error: it only ever leaves as
/// the clipboard message. A paste that is refused sends nothing at all, not
/// even the keys.
class ScreenPaste {
  ScreenPaste(
    this._sink,
    this._keyboard, {
    this.readClipboard = readDeviceClipboard,
    this.clearAfter = const Duration(milliseconds: 500),
  });

  final RfbInputSink _sink;
  final ScreenKeyboard _keyboard;
  final Future<String?> Function() readClipboard;
  final Duration clearAfter;
  Timer? _clear;

  Future<PasteOutcome> paste() async {
    final String? text;
    try {
      text = await readClipboard();
    } on Object {
      // A refused clipboard permission is no text.
      return PasteOutcome.empty;
    }
    if (text == null || text.isEmpty) return PasteOutcome.empty;
    try {
      _sink.cutText(text);
    } on RfbClipboardError catch (error) {
      return switch (error) {
        RfbClipboardError.notLatin1 => PasteOutcome.notLatin1,
        RfbClipboardError.tooLarge => PasteOutcome.tooLarge,
      };
    } on StateError {
      return PasteOutcome.closed;
    }
    _keyboard.pressControl(_v);
    _clear?.cancel();
    _clear = Timer(clearAfter, _empty);
    return PasteOutcome.pasted;
  }

  /// Empties the screen's clipboard; the stream may be gone by now.
  void _empty() {
    _clear = null;
    try {
      _sink.cutText('');
    } on StateError {
      return;
    }
  }

  /// Empties the screen's clipboard at once if that is still due, since the
  /// stream is about to close.
  void dispose() {
    if (_clear == null) return;
    _clear!.cancel();
    _empty();
  }
}

const _v = 0x76;
