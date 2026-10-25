import 'dart:typed_data';

/// A small invented desktop (a wallpaper, one window, a panel) as a PNG, so
/// the Bot screen card has a picture to show without a server. Built by hand
/// from stored deflate blocks, which keeps it free of `dart:io`; the catalog
/// also runs on the web.
Uint8List botScreenFixturePng({int width = 192, int height = 120}) {
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter: none
    for (var x = 0; x < width; x++) {
      raw.add(_pixel(x, y, width, height));
    }
  }
  final data = raw.toBytes();

  final zlib = BytesBuilder()..add([0x78, 0x01]);
  for (var offset = 0; offset < data.length; offset += 65535) {
    final end = offset + 65535 < data.length ? offset + 65535 : data.length;
    final length = end - offset;
    zlib
      ..addByte(end == data.length ? 1 : 0)
      ..add([length & 0xff, length >> 8, ~length & 0xff, (~length >> 8) & 0xff])
      ..add(data.sublist(offset, end));
  }
  zlib.add(_be32(_adler32(data)));

  final png = BytesBuilder()
    ..add([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  _chunk(png, 'IHDR', [
    ..._be32(width),
    ..._be32(height),
    8, // bit depth
    2, // true colour
    0, 0, 0,
  ]);
  _chunk(png, 'IDAT', zlib.toBytes());
  _chunk(png, 'IEND', const []);
  return png.toBytes();
}

List<int> _pixel(int x, int y, int width, int height) {
  final panel = y >= height - 10;
  if (panel) return const [0x2b, 0x2d, 0x42];
  final title = x >= 28 && x < width - 28 && y >= 14 && y < 26;
  if (title) return const [0x4a, 0x4e, 0x69];
  final body = x >= 28 && x < width - 28 && y >= 26 && y < height - 24;
  if (body) {
    final line = (y - 26) % 10 == 5 && x >= 36 && x < width - 60;
    return line ? const [0x9a, 0x8c, 0x98] : const [0xf2, 0xe9, 0xe4];
  }
  final shade = 0x6a + (y * 0x30 ~/ height);
  return [0x22, shade ~/ 2, shade];
}

void _chunk(BytesBuilder out, String type, List<int> body) {
  final typed = [...type.codeUnits, ...body];
  out
    ..add(_be32(body.length))
    ..add(typed)
    ..add(_be32(_crc32(typed)));
}

List<int> _be32(int value) => [
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];

int _adler32(List<int> data) {
  var a = 1, b = 0;
  for (final byte in data) {
    a = (a + byte) % 65521;
    b = (b + a) % 65521;
  }
  return (b << 16) | a;
}

int _crc32(List<int> data) {
  var crc = 0xffffffff;
  for (final byte in data) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return crc ^ 0xffffffff;
}
