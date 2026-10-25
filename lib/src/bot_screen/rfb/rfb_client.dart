import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Why an RFB stream ended badly.
enum RfbFailure {
  /// The server speaks a version below 3.8.
  version,

  /// The server offers no usable security type, or refused the connection.
  security,

  /// The server sent something RFB does not allow.
  protocol,

  /// A message was truncated or its pixel data malformed.
  decode,
}

/// The part of the stream a failure happened in.
enum RfbStep { handshake, decode }

/// A rectangle of the framebuffer, in pixels.
class RfbRect {
  const RfbRect(this.x, this.y, this.width, this.height);

  final int x;
  final int y;
  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is RfbRect &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'RfbRect($x, $y, $width x $height)';
}

/// The remote screen as RGBA bytes with alpha 255.
class Framebuffer {
  Framebuffer(this.width, this.height) : rgba = Uint8List(width * height * 4) {
    for (var i = 3; i < rgba.length; i += 4) {
      rgba[i] = 255;
    }
  }

  final int width;
  final int height;
  final Uint8List rgba;
}

sealed class RfbEvent {
  const RfbEvent();
}

/// The handshake finished; the desktop is [width] x [height].
final class RfbConnected extends RfbEvent {
  const RfbConnected(this.width, this.height);

  final int width;
  final int height;
}

/// An update changed [dirty] in the framebuffer.
final class RfbUpdated extends RfbEvent {
  const RfbUpdated(this.dirty);

  final RfbRect dirty;
}

/// The desktop changed size; [RfbClient.framebuffer] is a new, empty buffer.
final class RfbResized extends RfbEvent {
  const RfbResized(this.width, this.height);

  final int width;
  final int height;
}

/// The stream ended. [failure] is null when the socket was closed cleanly,
/// by the server (see [closeCode]) or by [RfbClient.close].
final class RfbEnded extends RfbEvent {
  const RfbEnded({this.failure, this.step, this.closeCode, this.reason});

  final RfbFailure? failure;
  final RfbStep? step;
  final int? closeCode;

  /// The reason the server gave for refusing the connection. It is the
  /// server's text: never log it.
  final String? reason;
}

const _encodingRaw = 0;
const _encodingCopyRect = 1;
const _encodingDesktopSize = -223;

const _maxPixels = 32 * 1024 * 1024;
const _maxReason = 4096;
const _maxName = 64 * 1024;

final _versionLine = RegExp(r'^RFB (\d{3})\.(\d{3})\n$');

/// A message the server got wrong; ends the stream with [failure].
class _Fail implements Exception {
  const _Fail(this.failure, [this.reason]);

  final RfbFailure failure;
  final String? reason;
}

enum _Phase { version, securityTypes, securityResult, serverInit, running }

/// An update whose rectangles are still arriving.
class _Update {
  _Update(this.rectsLeft);

  int rectsLeft;
  int _left = 1 << 30, _top = 1 << 30, _right = 0, _bottom = 0;
  bool resized = false;

  void paint(int x, int y, int w, int h) {
    _left = math.min(_left, x);
    _top = math.min(_top, y);
    _right = math.max(_right, x + w);
    _bottom = math.max(_bottom, y + h);
  }

  RfbRect? get dirty => _right > _left && _bottom > _top
      ? RfbRect(_left, _top, _right - _left, _bottom - _top)
      : null;
}

/// The bytes received and not yet parsed. RFB messages do not line up with
/// WebSocket frames, so parsing peeks at offsets and consumes once a whole
/// message (or rectangle) is here.
class _Reader {
  Uint8List _buf = Uint8List(4096);
  int _start = 0;
  int _end = 0;

  int get available => _end - _start;

  void add(List<int> data) {
    if (_end + data.length > _buf.length) {
      final live = available;
      if (live + data.length > _buf.length) {
        final grown = Uint8List(math.max(live + data.length, _buf.length * 2));
        grown.setRange(0, live, _buf, _start);
        _buf = grown;
      } else {
        _buf.setRange(0, live, _buf, _start);
      }
      _start = 0;
      _end = live;
    }
    _buf.setRange(_end, _end + data.length, data);
    _end += data.length;
  }

  int u8(int at) => _buf[_start + at];

  int u16(int at) => (u8(at) << 8) | u8(at + 1);

  int u32(int at) => (u16(at) << 16) | u16(at + 2);

  int i32(int at) => u32(at).toSigned(32);

  Uint8List view(int at, int length) =>
      Uint8List.sublistView(_buf, _start + at, _start + at + length);

  void skip(int length) => _start += length;
}

/// A watch-only RFB 3.8 client over the display socket.
///
/// It sends the handshake, SetPixelFormat, SetEncodings and
/// FramebufferUpdateRequest, and nothing else: there is no way to send input.
/// Failures and the end of the stream arrive as [RfbEnded]; nothing throws
/// past this API.
class RfbClient {
  RfbClient(this._channel) {
    _subscription = _channel.stream.listen(
      _onData,
      onError: (Object _) => _end(closeCode: _channel.closeCode),
      onDone: _onDone,
      cancelOnError: true,
    );
  }

  final WebSocketChannel _channel;
  late final StreamSubscription<Object?> _subscription;
  final _events = StreamController<RfbEvent>();
  final _reader = _Reader();
  final _encodings = <int>{};

  _Phase _phase = _Phase.version;
  _Update? _update;
  int _skipLeft = 0;
  int _bytesReceived = 0;
  bool _ended = false;
  Framebuffer? _framebuffer;

  Stream<RfbEvent> get events => _events.stream;

  /// The picture. Replaced by a new buffer after [RfbResized].
  Framebuffer? get framebuffer => _framebuffer;

  /// Every byte the server sent on this connection.
  int get bytesReceived => _bytesReceived;

  /// The encodings of the rectangles received so far.
  Set<int> get encodingsSeen => Set.unmodifiable(_encodings);

  /// Ends the stream with a close frame carrying [code].
  Future<void> close([int code = 1000]) async {
    if (_ended) return;
    _end(closeWith: code);
  }

  void _onData(Object? data) {
    if (_ended) return;
    if (data is! List<int>) {
      _end(failure: RfbFailure.protocol);
      return;
    }
    _bytesReceived += data.length;
    _reader.add(data);
    try {
      while (!_ended && _advance()) {}
    } on _Fail catch (fail) {
      _end(failure: fail.failure, reason: fail.reason);
    } on Object {
      _end(failure: RfbFailure.decode);
    }
  }

  void _onDone() {
    if (_ended) return;
    final partial = _reader.available > 0 || _update != null || _skipLeft > 0;
    _end(
      failure: partial ? RfbFailure.decode : null,
      closeCode: _channel.closeCode,
    );
  }

  /// Ends the stream once. The socket is closed with [closeWith] (1000 after
  /// a failure) unless the server closed it first, which [closeCode] says.
  void _end({
    RfbFailure? failure,
    String? reason,
    int? closeCode,
    int? closeWith,
  }) {
    if (_ended) return;
    _ended = true;
    final step = _phase == _Phase.running ? RfbStep.decode : RfbStep.handshake;
    unawaited(_subscription.cancel());
    unawaited(_closeSink(closeWith ?? 1000));
    _events
      ..add(
        RfbEnded(
          failure: failure,
          step: failure == null ? null : step,
          closeCode: closeCode,
          reason: reason,
        ),
      )
      ..close();
  }

  Future<void> _closeSink(int code) async {
    try {
      await _channel.sink.close(code);
    } on Object {
      // The socket is gone already.
    }
  }

  void _send(List<int> message) {
    if (!_ended) _channel.sink.add(Uint8List.fromList(message));
  }

  /// Parses what has arrived; false when more bytes are needed.
  bool _advance() {
    final r = _reader;
    switch (_phase) {
      case _Phase.version:
        if (r.available < 12) return false;
        final match = _versionLine.firstMatch(
          latin1.decode(r.view(0, 12), allowInvalid: true),
        );
        if (match == null ||
            match.group(1) != '003' ||
            int.parse(match.group(2)!) < 8) {
          throw const _Fail(RfbFailure.version);
        }
        r.skip(12);
        _send(latin1.encode('RFB 003.008\n'));
        _phase = _Phase.securityTypes;
        return true;
      case _Phase.securityTypes:
        if (r.available < 1) return false;
        final count = r.u8(0);
        if (count == 0) return _failWithReason(1);
        if (r.available < 1 + count) return false;
        if (!r.view(1, count).contains(1)) {
          throw const _Fail(RfbFailure.security);
        }
        r.skip(1 + count);
        _send([1]);
        _phase = _Phase.securityResult;
        return true;
      case _Phase.securityResult:
        if (r.available < 4) return false;
        if (r.u32(0) != 0) return _failWithReason(4);
        r.skip(4);
        _send([1]); // ClientInit: shared
        _phase = _Phase.serverInit;
        return true;
      case _Phase.serverInit:
        if (r.available < 24) return false;
        final nameLength = r.u32(20);
        if (nameLength > _maxName) throw const _Fail(RfbFailure.protocol);
        if (r.available < 24 + nameLength) return false;
        final width = r.u16(0);
        final height = r.u16(2);
        _checkSize(width, height);
        r.skip(24 + nameLength);
        _framebuffer = Framebuffer(width, height);
        _send(_setPixelFormat);
        _send(_setEncodings);
        _send(_updateRequest(width, height, incremental: false));
        _phase = _Phase.running;
        _events.add(RfbConnected(width, height));
        return true;
      case _Phase.running:
        return _advanceRunning();
    }
  }

  /// Reads the reason string at [at] and fails with `security`.
  bool _failWithReason(int at) {
    final r = _reader;
    if (r.available < at + 4) return false;
    final length = r.u32(at);
    if (length > _maxReason) throw const _Fail(RfbFailure.security);
    if (r.available < at + 4 + length) return false;
    throw _Fail(
      RfbFailure.security,
      utf8.decode(r.view(at + 4, length), allowMalformed: true),
    );
  }

  void _checkSize(int width, int height) {
    if (width == 0 || height == 0 || width * height > _maxPixels) {
      throw const _Fail(RfbFailure.protocol);
    }
  }

  bool _advanceRunning() {
    final r = _reader;
    if (_skipLeft > 0) {
      final n = math.min(_skipLeft, r.available);
      r.skip(n);
      _skipLeft -= n;
      return n > 0;
    }
    if (_update != null) return _readRect();
    if (r.available < 1) return false;
    switch (r.u8(0)) {
      case 0: // FramebufferUpdate
        if (r.available < 4) return false;
        final rects = r.u16(2);
        r.skip(4);
        _update = _Update(rects);
        if (rects == 0) _finishUpdate();
        return true;
      case 1: // SetColourMapEntries
        if (r.available < 6) return false;
        final length = 6 + 6 * r.u16(4);
        if (r.available < length) return false;
        r.skip(length);
        return true;
      case 2: // Bell
        r.skip(1);
        return true;
      case 3: // ServerCutText; a negative length is the extended form
        if (r.available < 8) return false;
        _skipLeft = r.i32(4).abs();
        r.skip(8);
        return true;
      default:
        throw const _Fail(RfbFailure.protocol);
    }
  }

  bool _readRect() {
    final r = _reader;
    if (r.available < 12) return false;
    final x = r.u16(0), y = r.u16(2), w = r.u16(4), h = r.u16(6);
    final encoding = r.i32(8);
    final fb = _framebuffer!;
    final update = _update!;

    void inside(int rx, int ry, int rw, int rh) {
      if (rx + rw > fb.width || ry + rh > fb.height) {
        throw const _Fail(RfbFailure.decode);
      }
    }

    switch (encoding) {
      case _encodingRaw:
        inside(x, y, w, h);
        if (r.available < 12 + w * h * 4) return false;
        _blit(fb, r.view(12, w * h * 4), x, y, w, h);
        r.skip(12 + w * h * 4);
        update.paint(x, y, w, h);
      case _encodingCopyRect:
        if (r.available < 16) return false;
        final srcX = r.u16(12), srcY = r.u16(14);
        inside(x, y, w, h);
        inside(srcX, srcY, w, h);
        _copy(fb, srcX, srcY, x, y, w, h);
        r.skip(16);
        update.paint(x, y, w, h);
      case _encodingDesktopSize:
        _checkSize(w, h);
        r.skip(12);
        _framebuffer = Framebuffer(w, h);
        update.resized = true;
      default:
        throw const _Fail(RfbFailure.protocol);
    }
    _encodings.add(encoding);
    if (--update.rectsLeft == 0) _finishUpdate();
    return true;
  }

  void _finishUpdate() {
    final update = _update!;
    _update = null;
    final fb = _framebuffer!;
    if (update.resized) {
      _events.add(RfbResized(fb.width, fb.height));
      _send(_updateRequest(fb.width, fb.height, incremental: false));
      return;
    }
    final dirty = update.dirty;
    if (dirty != null) _events.add(RfbUpdated(dirty));
    _send(_updateRequest(fb.width, fb.height, incremental: true));
  }
}

/// Raw pixels are R, G, B and a padding byte on the wire.
void _blit(Framebuffer fb, Uint8List wire, int x, int y, int w, int h) {
  var from = 0;
  for (var row = 0; row < h; row++) {
    var to = ((y + row) * fb.width + x) * 4;
    for (var col = 0; col < w; col++) {
      fb.rgba[to] = wire[from];
      fb.rgba[to + 1] = wire[from + 1];
      fb.rgba[to + 2] = wire[from + 2];
      to += 4;
      from += 4;
    }
  }
}

void _copy(Framebuffer fb, int sx, int sy, int x, int y, int w, int h) {
  // Through a snapshot, so overlapping rectangles copy correctly.
  final source = Uint8List(w * h * 4);
  for (var row = 0; row < h; row++) {
    final from = ((sy + row) * fb.width + sx) * 4;
    source.setRange(row * w * 4, (row + 1) * w * 4, fb.rgba, from);
  }
  for (var row = 0; row < h; row++) {
    final to = ((y + row) * fb.width + x) * 4;
    fb.rgba.setRange(to, to + w * 4, source, row * w * 4);
  }
}

// 32 bits per pixel, depth 24, little-endian, true colour, 255 for each
// channel, shifts 0, 8 and 16: wire pixels are R, G, B and a padding byte.
final _setPixelFormat = Uint8List.fromList([
  0, 0, 0, 0, // SetPixelFormat, padding
  32, 24, 0, 1,
  0, 255, 0, 255, 0, 255,
  0, 8, 16,
  0, 0, 0,
]);

// ZRLE (16), CopyRect (1), Raw (0), DesktopSize (-223).
final _setEncodings = Uint8List.fromList([
  2,
  0,
  0,
  4,
  0,
  0,
  0,
  16,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  0,
  0xFF,
  0xFF,
  0xFF,
  0x21,
]);

Uint8List _updateRequest(int width, int height, {required bool incremental}) =>
    Uint8List.fromList([
      3,
      incremental ? 1 : 0,
      0,
      0,
      0,
      0,
      width >> 8,
      width & 255,
      height >> 8,
      height & 255,
    ]);
