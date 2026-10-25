/// Why clipboard text cannot be sent to the screen.
///
/// The error never carries the text.
enum RfbClipboardError implements Exception {
  /// The text has a character outside Latin-1, which classic ClientCutText
  /// cannot carry. Nothing is replaced.
  notLatin1,

  /// The text is longer than 256 KiB, the most the bridge and Xvnc take.
  tooLarge;

  @override
  String toString() => 'RfbClipboardError.$name';
}

/// The most clipboard bytes the bridge's `rfb_filter.py` frames and Xvnc's
/// `-MaxCutText` takes.
const maxCutTextBytes = 256 * 1024;

/// The bits of a PointerEvent button mask (RFC 6143, section 7.5.5).
abstract final class RfbButtons {
  static const primary = 1;
  static const middle = 2;
  static const secondary = 4;

  /// The buttons a pointer holds, as opposed to the wheel's.
  static const held = primary | middle | secondary;

  static const wheelUp = 8;
  static const wheelDown = 16;
  static const wheelLeft = 32;
  static const wheelRight = 64;
}

/// What a viewer needs from an RFB client to send input.
///
/// Every method throws [StateError] until the server has sent ServerInit and
/// after the stream ended.
abstract interface class RfbInputSink {
  /// Moves the pointer to ([x], [y]), clamped to the screen, with the buttons
  /// in [buttonMask] held.
  void pointer(int x, int y, int buttonMask);

  /// Presses or releases the key with the X11 [keysym].
  void key(int keysym, {required bool down});

  /// Scrolls [dy] notches down (negative: up) and [dx] notches right
  /// (negative: left) at ([x], [y]), keeping the held buttons.
  void scroll(int x, int y, {int dx = 0, int dy = 0});

  /// Sets the remote clipboard to [text].
  ///
  /// Throws [RfbClipboardError] for text that cannot be sent as it is.
  void cutText(String text);
}
