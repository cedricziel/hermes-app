import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _tileSize = 64;

/// Decodes ZRLE rectangles (RFC 6143 section 7.7.6) for the client's pixel
/// format: 3-byte CPIXELs holding R, G and B.
///
/// ZRLE keeps one zlib stream (RFC 1950) for the whole connection. Each
/// rectangle's data ends at a flush point, so feeding it exactly that
/// rectangle's bytes yields all of its tiles, and the next rectangle
/// continues the same stream.
class ZrleDecoder {
  ZrleDecoder() {
    _inflater = ZLibDecoder().startChunkedConversion(_Collector(_collect));
  }

  late final ByteConversionSink _inflater;
  final _inflated = BytesBuilder();
  int _inflatedLimit = 0;

  /// The most compressed bytes a [w] x [h] rectangle can need: zlib adds a few
  /// bytes per 64 KiB to tile data of at most 4 bytes per pixel.
  static int maxPayload(int w, int h) => w * h * 5 + 64 * 1024;

  /// The most tile data a [w] x [h] rectangle can hold: a one-pixel run in
  /// plain RLE takes 4 bytes, plus 1 byte per tile.
  static int _maxInflated(int w, int h) =>
      w * h * 4 +
      ((w + _tileSize - 1) ~/ _tileSize) * ((h + _tileSize - 1) ~/ _tileSize);

  void _collect(List<int> chunk) {
    _inflated.add(chunk);
    if (_inflated.length > _inflatedLimit) {
      throw const FormatException('ZRLE data larger than its rectangle');
    }
  }

  /// Paints the rectangle ([x], [y], [w], [h]) of [rgba], a picture
  /// [stride] pixels wide, from the rectangle's compressed [payload].
  /// Throws [FormatException] on malformed data.
  void decode(
    Uint8List payload,
    Uint8List rgba,
    int stride,
    int x,
    int y,
    int w,
    int h,
  ) {
    _inflatedLimit = _maxInflated(w, h);
    _inflater.add(payload);
    final data = _inflated.takeBytes();
    var p = 0;
    for (var ty = 0; ty < h; ty += _tileSize) {
      for (var tx = 0; tx < w; tx += _tileSize) {
        p = _tile(
          data,
          p,
          rgba,
          stride,
          x + tx,
          y + ty,
          _tileSize < w - tx ? _tileSize : w - tx,
          _tileSize < h - ty ? _tileSize : h - ty,
        );
      }
    }
    if (p != data.length) throw const FormatException('ZRLE data left over');
  }

  void close() {
    try {
      _inflater.close();
    } on Object {
      // An unfinished stream cannot be closed cleanly.
    }
  }
}

class _Collector extends ByteConversionSinkBase {
  _Collector(this._onChunk);

  final void Function(List<int>) _onChunk;

  @override
  void add(List<int> chunk) => _onChunk(chunk);

  @override
  void close() {}
}

FormatException _bad(String what) => FormatException('Bad ZRLE tile: $what');

int _cpixel(Uint8List d, int p) {
  if (p + 3 > d.length) throw _bad('short pixel');
  return d[p] | (d[p + 1] << 8) | (d[p + 2] << 16);
}

void _put(Uint8List rgba, int offset, int colour) {
  rgba[offset] = colour & 255;
  rgba[offset + 1] = (colour >> 8) & 255;
  rgba[offset + 2] = colour >> 16;
}

/// Decodes the tile at ([x], [y]) of size [w] x [h] from [d] at [p] and
/// returns the position after it.
int _tile(
  Uint8List d,
  int p,
  Uint8List rgba,
  int stride,
  int x,
  int y,
  int w,
  int h,
) {
  if (p >= d.length) throw _bad('missing tile');
  final sub = d[p++];
  int at(int i) => ((y + i ~/ w) * stride + x + i % w) * 4;
  final area = w * h;

  if (sub == 0) {
    if (p + area * 3 > d.length) throw _bad('short raw tile');
    for (var i = 0; i < area; i++, p += 3) {
      _put(rgba, at(i), _cpixel(d, p));
    }
    return p;
  }
  if (sub == 1) {
    final colour = _cpixel(d, p);
    for (var i = 0; i < area; i++) {
      _put(rgba, at(i), colour);
    }
    return p + 3;
  }
  final isRle = sub >= 128;
  final paletteSize = isRle ? sub - 128 : sub;
  if (sub == 129 || (!isRle && sub > 16)) {
    throw _bad('subencoding $sub');
  }
  if (isRle && sub == 128) return _plainRle(d, p, rgba, at, area);

  final palette = [for (var i = 0; i < paletteSize; i++) _cpixel(d, p + i * 3)];
  p += paletteSize * 3;
  if (isRle) return _paletteRle(d, p, rgba, at, area, palette);

  final bits = paletteSize == 2 ? 1 : (paletteSize <= 4 ? 2 : 4);
  final rowBytes = (w * bits + 7) >> 3;
  if (p + rowBytes * h > d.length) throw _bad('short packed tile');
  final mask = (1 << bits) - 1;
  for (var row = 0; row < h; row++, p += rowBytes) {
    for (var col = 0; col < w; col++) {
      final shift = 8 - bits * (col % (8 ~/ bits) + 1);
      final index = (d[p + col * bits ~/ 8] >> shift) & mask;
      if (index >= paletteSize) throw _bad('palette index');
      _put(rgba, at(row * w + col), palette[index]);
    }
  }
  return p;
}

/// Reads a run length: 1 plus the bytes up to the first one below 255.
(int, int) _run(Uint8List d, int p) {
  var length = 1;
  while (true) {
    if (p >= d.length) throw _bad('short run');
    final b = d[p++];
    length += b;
    if (b != 255) return (length, p);
  }
}

int _plainRle(
  Uint8List d,
  int p,
  Uint8List rgba,
  int Function(int) at,
  int area,
) {
  var done = 0;
  while (done < area) {
    final colour = _cpixel(d, p);
    final (length, next) = _run(d, p + 3);
    p = next;
    if (done + length > area) throw _bad('run past the tile');
    for (var i = 0; i < length; i++) {
      _put(rgba, at(done + i), colour);
    }
    done += length;
  }
  return p;
}

int _paletteRle(
  Uint8List d,
  int p,
  Uint8List rgba,
  int Function(int) at,
  int area,
  List<int> palette,
) {
  var done = 0;
  while (done < area) {
    if (p >= d.length) throw _bad('short palette run');
    var index = d[p++];
    var length = 1;
    if (index & 0x80 != 0) {
      index &= 0x7F;
      (length, p) = _run(d, p);
    }
    if (index >= palette.length) throw _bad('palette index');
    if (done + length > area) throw _bad('run past the tile');
    for (var i = 0; i < length; i++) {
      _put(rgba, at(done + i), palette[index]);
    }
    done += length;
  }
  return p;
}
