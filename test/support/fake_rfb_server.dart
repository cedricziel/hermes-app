import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart' show pumpEventQueue;
import 'package:hermes_app/src/bot_screen/rfb/rfb_client.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A display socket the test drives by hand: [serverSend] delivers a frame to
/// the client, and every frame the client writes lands in [sent].
class FakeDisplayChannel with StreamChannelMixin implements WebSocketChannel {
  final _incoming = StreamController<Object?>();
  final sent = <Object?>[];
  int? _closeCode;
  int? sentCloseCode;
  // The client closes it; a test that never does leaks nothing.
  // ignore: close_sinks
  late final _sink = _FakeSink(this);

  /// Everything the client wrote, as one byte string.
  Uint8List get sentBytes {
    final all = BytesBuilder();
    for (final frame in sent) {
      all.add(frame! as List<int>);
    }
    return all.takeBytes();
  }

  void serverSend(Object data) => _incoming.add(data);

  Future<void> serverClose([int? code]) {
    _closeCode = code;
    return _incoming.close();
  }

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future.value();

  @override
  Stream get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _sink;
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this._channel);

  final FakeDisplayChannel _channel;
  final _done = Completer<void>();

  @override
  void add(Object? data) => _channel.sent.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) => stream.forEach(add);

  @override
  Future close([int? closeCode, String? closeReason]) {
    _channel.sentCloseCode = closeCode;
    if (!_done.isCompleted) _done.complete();
    return _done.future;
  }

  @override
  Future get done => _done.future;
}

/// An [RfbClient] on a [FakeDisplayChannel], with its events collected.
class RfbSession {
  RfbSession() : channel = FakeDisplayChannel() {
    client = RfbClient(channel);
    client.events.listen(events.add);
  }

  final FakeDisplayChannel channel;
  late final RfbClient client;
  final events = <RfbEvent>[];

  Future<void> send(List<int> data) async {
    channel.serverSend(Uint8List.fromList(data));
    await pumpEventQueue();
  }

  Future<void> handshake([int w = 8, int h = 4]) async {
    for (final part in rfbHandshake(w, h)) {
      await send(part);
    }
  }

  RfbEnded get ended => events.whereType<RfbEnded>().single;

  List<int> pixel(int x, int y) {
    final fb = client.framebuffer!;
    final o = (y * fb.width + x) * 4;
    return fb.rgba.sublist(o, o + 4);
  }
}

// Server messages (RFC 6143 section 7.6) ------------------------------------

Uint8List ascii(String text) => Uint8List.fromList(latin1.encode(text));

Uint8List bytes(Iterable<int> values) => Uint8List.fromList(values.toList());

Uint8List u16(int v) => bytes([(v >> 8) & 255, v & 255]);

Uint8List u32(int v) =>
    bytes([(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255]);

Uint8List cat(Iterable<List<int>> parts) {
  final out = BytesBuilder();
  parts.forEach(out.add);
  return out.takeBytes();
}

Uint8List rfbVersion([String version = 'RFB 003.008\n']) => ascii(version);

Uint8List rfbReason(String reason) => cat([u32(reason.length), ascii(reason)]);

/// The server's ServerInit for a [width] x [height] desktop.
Uint8List rfbServerInit(int width, int height, {String name = 'bot'}) => cat([
  u16(width),
  u16(height),
  // 32 bpp, depth 24, little-endian, true colour, 255/255/255, 16/8/0.
  bytes([32, 24, 0, 1]),
  u16(255), u16(255), u16(255),
  bytes([16, 8, 0, 0, 0, 0]),
  u32(name.length),
  ascii(name),
]);

/// The server side of the handshake up to and including ServerInit.
List<Uint8List> rfbHandshake(int width, int height) => [
  rfbVersion(),
  bytes([1, 1]), // one security type: None
  u32(0), // SecurityResult: OK
  rfbServerInit(width, height),
];

Uint8List rfbRectHeader(int x, int y, int w, int h, int encoding) =>
    cat([u16(x), u16(y), u16(w), u16(h), u32(encoding & 0xFFFFFFFF)]);

/// A FramebufferUpdate holding [rects] (each from one of the rect builders).
Uint8List rfbUpdate(List<List<int>> rects) => cat([
  bytes([0, 0]),
  u16(rects.length),
  ...rects,
]);

/// A Raw rectangle filled with the colour [rgb] (wire order R, G, B, pad).
Uint8List rfbRawRect(int x, int y, int w, int h, List<int> rgb) => cat([
  rfbRectHeader(x, y, w, h, 0),
  for (var i = 0; i < w * h; i++) bytes([...rgb, 0]),
]);

Uint8List rfbCopyRect(int x, int y, int w, int h, int srcX, int srcY) =>
    cat([rfbRectHeader(x, y, w, h, 1), u16(srcX), u16(srcY)]);

Uint8List rfbDesktopSizeRect(int w, int h) => rfbRectHeader(0, 0, w, h, -223);

Uint8List rfbZrleRect(int x, int y, int w, int h, List<int> payload) =>
    cat([rfbRectHeader(x, y, w, h, 16), u32(payload.length), payload]);

/// A zlib stream (RFC 1950) built the way a ZRLE server writes one: a single
/// header, then each rectangle's data ending at a flush point.
///
/// `dart:io`'s encoder cannot flush without finishing the stream, so the data
/// goes out in stored (uncompressed) deflate blocks, which are byte aligned and
/// decodable the moment they arrive, like Z_SYNC_FLUSH output.
class ZlibSyncStream {
  bool _started = false;

  /// The bytes to send as the payload of the next ZRLE rectangle.
  Uint8List next(List<int> data) {
    final out = BytesBuilder();
    if (!_started) {
      out.add([0x78, 0x01]);
      _started = true;
    }
    var offset = 0;
    do {
      final n = data.length - offset > 65535 ? 65535 : data.length - offset;
      out.add([0x00, n & 255, n >> 8, ~n & 255, (~n >> 8) & 255]);
      out.add(data.sublist(offset, offset + n));
      offset += n;
    } while (offset < data.length);
    return out.takeBytes();
  }
}

// Client messages ------------------------------------------------------------

/// Splits what the client wrote after the 14 handshake bytes (12 version, 1
/// security choice, 1 ClientInit) into messages the way the bridge's
/// `rfb_filter.py` frames them. Throws on a type the bridge cannot frame.
List<Uint8List> clientMessages(Uint8List written) {
  final out = <Uint8List>[];
  var p = 14;
  while (p < written.length) {
    final type = written[p];
    final int length;
    switch (type) {
      case 0:
        length = 20;
      case 2:
        length = 4 + 4 * ((written[p + 2] << 8) | written[p + 3]);
      case 3:
        length = 10;
      default:
        throw StateError('Unexpected client message type $type');
    }
    out.add(Uint8List.sublistView(written, p, p + length));
    p += length;
  }
  return out;
}
