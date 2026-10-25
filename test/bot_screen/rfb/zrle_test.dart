import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/rfb/rfb_client.dart';

import '../../support/fake_rfb_server.dart';

typedef Rgb = List<int>;
typedef ColourAt = Rgb Function(int x, int y);

// Tile encoders (RFC 6143 section 7.7.6), CPIXEL being R, G, B.

List<int> solidTile(Rgb c) => [1, ...c];

List<int> rawTile(int w, int h, ColourAt at) => [
  0,
  for (var y = 0; y < h; y++)
    for (var x = 0; x < w; x++) ...at(x, y),
];

/// Packed palette tile: 1 bit per index for 2 colours, 2 for 3-4, 4 for 5-16,
/// each row padded to a byte.
List<int> packedTile(
  List<Rgb> palette,
  int w,
  int h,
  int Function(int, int) at,
) {
  final bits = palette.length == 2 ? 1 : (palette.length <= 4 ? 2 : 4);
  final out = <int>[palette.length, for (final c in palette) ...c];
  for (var y = 0; y < h; y++) {
    var byte = 0, used = 0;
    for (var x = 0; x < w; x++) {
      byte = (byte << bits) | at(x, y);
      used += bits;
      if (used == 8) {
        out.add(byte);
        byte = 0;
        used = 0;
      }
    }
    if (used > 0) out.add(byte << (8 - used));
  }
  return out;
}

List<int> runLength(int n) => [
  for (var k = n - 1; k >= 255; k -= 255) 255,
  (n - 1) % 255,
];

/// Plain RLE tile from (colour, run) pairs.
List<int> rleTile(List<(Rgb, int)> runs) => [
  128,
  for (final (c, n) in runs) ...[...c, ...runLength(n)],
];

/// Palette RLE tile from (index, run) pairs; a run of 1 is a bare index.
List<int> paletteRleTile(List<Rgb> palette, List<(int, int)> runs) => [
  128 + palette.length,
  for (final c in palette) ...c,
  for (final (i, n) in runs)
    if (n == 1) i else ...[i | 0x80, ...runLength(n)],
];

const red = [255, 0, 0];
const green = [0, 255, 0];
const blue = [0, 0, 255];
const white = [250, 250, 250];

void expectRegion(RfbSession s, int x0, int y0, int w, int h, ColourAt at) {
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      expect(s.pixel(x0 + x, y0 + y), [
        ...at(x, y),
        255,
      ], reason: 'pixel ${x0 + x},${y0 + y}');
    }
  }
}

/// One session with a ZRLE rectangle at (0, 0) carrying [tiles], on a stream
/// of its own.
Future<RfbSession> zrleSession(
  int w,
  int h,
  List<int> tiles, {
  int fbWidth = 80,
  int fbHeight = 70,
}) async {
  final s = RfbSession();
  await s.handshake(fbWidth, fbHeight);
  await s.send(
    rfbUpdate([rfbZrleRect(0, 0, w, h, ZlibSyncStream().next(tiles))]),
  );
  return s;
}

void main() {
  group('subencodings', () {
    test('solid', () async {
      final s = await zrleSession(10, 5, solidTile(red));

      expectRegion(s, 0, 0, 10, 5, (_, _) => red);
      expect(s.pixel(10, 0), [0, 0, 0, 255]);
      expect(s.events.last, isA<RfbUpdated>());
      expect(s.client.encodingsSeen, {16});
    });

    test('raw, in a partial tile', () async {
      Rgb at(int x, int y) => [x * 10, y * 20, 7];
      final s = await zrleSession(5, 3, rawTile(5, 3, at));

      expectRegion(s, 0, 0, 5, 3, at);
    });

    test('packed palette of 2 colours, rows padded to a byte', () async {
      int index(int x, int y) => (x + y) % 2;
      final s = await zrleSession(10, 3, packedTile([red, blue], 10, 3, index));

      expectRegion(s, 0, 0, 10, 3, (x, y) => index(x, y) == 0 ? red : blue);
    });

    test('packed palette of 3 and of 4 colours', () async {
      for (final palette in [
        [red, green, blue],
        [red, green, blue, white],
      ]) {
        int index(int x, int y) => (x * 3 + y) % palette.length;
        final s = await zrleSession(7, 4, packedTile(palette, 7, 4, index));

        expectRegion(s, 0, 0, 7, 4, (x, y) => palette[index(x, y)]);
      }
    });

    test('packed palette of 5 and of 16 colours', () async {
      for (final size in [5, 16]) {
        final palette = [
          for (var i = 0; i < size; i++) [i * 10, 255 - i * 10, i],
        ];
        int index(int x, int y) => (x + y * 3) % size;
        final s = await zrleSession(9, 5, packedTile(palette, 9, 5, index));

        expectRegion(s, 0, 0, 9, 5, (x, y) => palette[index(x, y)]);
      }
    });

    test('plain RLE, with a run over 255', () async {
      // 64 x 8 = 512 pixels: 300 red, 1 green, 211 blue.
      final s = await zrleSession(
        64,
        8,
        rleTile([(red, 300), (green, 1), (blue, 211)]),
      );

      Rgb at(int x, int y) {
        final i = y * 64 + x;
        return i < 300 ? red : (i == 300 ? green : blue);
      }

      expectRegion(s, 0, 0, 64, 8, at);
    });

    test('plain RLE with a run of exactly 256', () async {
      final s = await zrleSession(16, 16, rleTile([(red, 256)]));

      expectRegion(s, 0, 0, 16, 16, (_, _) => red);
    });

    test('palette RLE', () async {
      final palette = [red, green, blue];
      // 10 x 4 = 40 pixels.
      final s = await zrleSession(
        10,
        4,
        paletteRleTile(palette, [(0, 17), (1, 1), (2, 1), (1, 21)]),
      );

      Rgb at(int x, int y) {
        final i = y * 10 + x;
        if (i < 17) return red;
        if (i == 17) return green;
        if (i == 18) return blue;
        return green;
      }

      expectRegion(s, 0, 0, 10, 4, at);
    });

    test('a rectangle of several tiles with partial edges', () async {
      // 70 x 66: tiles 64x64, 6x64, 64x2, 6x2.
      Rgb at(int x, int y) => [x, y, 99];
      final s = await zrleSession(70, 66, [
        ...solidTile(green),
        ...rawTile(6, 64, (x, y) => at(64 + x, y)),
        ...packedTile([red, white], 64, 2, (x, y) => x % 2),
        ...paletteRleTile([blue, white], [(1, 6), (0, 6)]),
      ]);

      expectRegion(s, 0, 0, 64, 64, (_, _) => green);
      expectRegion(s, 64, 0, 6, 64, (x, y) => at(64 + x, y));
      expectRegion(s, 0, 64, 64, 2, (x, _) => x % 2 == 0 ? red : white);
      expectRegion(s, 64, 64, 6, 2, (x, y) => y * 6 + x < 6 ? white : blue);
    });

    test('rectangle offsets leave the rest of the picture alone', () async {
      final s = RfbSession();
      await s.handshake(20, 10);
      await s.send(
        rfbUpdate([
          rfbZrleRect(5, 3, 4, 2, ZlibSyncStream().next(solidTile(blue))),
        ]),
      );

      expectRegion(s, 5, 3, 4, 2, (_, _) => blue);
      expect(s.pixel(4, 3), [0, 0, 0, 255]);
      expect(s.pixel(9, 3), [0, 0, 0, 255]);
      expect(s.pixel(5, 5), [0, 0, 0, 255]);
      expect((s.events.last as RfbUpdated).dirty, const RfbRect(5, 3, 4, 2));
    });
  });

  group('the zlib stream', () {
    test('spans updates: the second carries no zlib header', () async {
      final stream = ZlibSyncStream();
      final s = RfbSession();
      await s.handshake(20, 10);
      await s.send(
        rfbUpdate([rfbZrleRect(0, 0, 4, 4, stream.next(solidTile(red)))]),
      );
      await s.send(
        rfbUpdate([rfbZrleRect(4, 0, 4, 4, stream.next(solidTile(green)))]),
      );

      expect(s.events.whereType<RfbEnded>(), isEmpty);
      expect(s.pixel(0, 0), [...red, 255]);
      expect(s.pixel(4, 0), [...green, 255]);
    });

    test('spans the rectangles of one update', () async {
      final stream = ZlibSyncStream();
      final s = RfbSession();
      await s.handshake(20, 10);
      await s.send(
        rfbUpdate([
          rfbZrleRect(0, 0, 4, 4, stream.next(solidTile(red))),
          rfbZrleRect(4, 0, 4, 4, stream.next(solidTile(green))),
        ]),
      );

      expect(s.pixel(0, 0), [...red, 255]);
      expect(s.pixel(4, 0), [...green, 255]);
    });

    test('decodes data compressed by a real deflate encoder', () async {
      Rgb at(int x, int y) => [(x * 4) % 256, (y * 4) % 256, (x + y) % 256];
      final tiles = rawTile(64, 64, at);
      final compressed = zlib.encode(tiles); // one finished zlib stream
      expect(compressed.length, lessThan(tiles.length));

      final s = RfbSession();
      await s.handshake(80, 70);
      await s.send(rfbUpdate([rfbZrleRect(0, 0, 64, 64, compressed)]));

      expectRegion(s, 0, 0, 64, 64, at);
    });

    test('a corrupt stream is a decode failure', () async {
      final s = RfbSession();
      await s.handshake(80, 70);
      await s.send(
        rfbUpdate([
          rfbZrleRect(0, 0, 4, 4, bytes([0x78, 0x01, 0xFF, 0xFF])),
        ]),
      );

      expect(s.ended.failure, RfbFailure.decode);
      expect(s.channel.sentCloseCode, 1000);
    });
  });

  group('malformed tiles', () {
    for (final sub in [17, 64, 127, 129]) {
      test('subencoding $sub is a decode failure', () async {
        final s = await zrleSession(4, 4, [sub, 1, 2, 3, 4, 5, 6, 7, 8, 9]);

        expect(s.ended.failure, RfbFailure.decode);
        expect(s.ended.step, RfbStep.decode);
      });
    }

    test('missing tile data is a decode failure', () async {
      final s = await zrleSession(4, 4, [0, 1, 2, 3]);

      expect(s.ended.failure, RfbFailure.decode);
    });

    test('data left over after the tiles is a decode failure', () async {
      final s = await zrleSession(4, 4, [...solidTile(red), 9, 9]);

      expect(s.ended.failure, RfbFailure.decode);
    });

    test('a palette index outside the palette is a decode failure', () async {
      // Three colours use 2 bits, so index 3 does not exist.
      final s = await zrleSession(
        4,
        1,
        packedTile([red, green, blue], 4, 1, (x, _) => x),
      );

      expect(s.ended.failure, RfbFailure.decode);
    });

    test('a run past the end of the tile is a decode failure', () async {
      final s = await zrleSession(4, 4, rleTile([(red, 17)]));

      expect(s.ended.failure, RfbFailure.decode);
    });

    test('a rectangle outside the screen is a decode failure', () async {
      final s = RfbSession();
      await s.handshake(8, 4);
      await s.send(
        rfbUpdate([
          rfbZrleRect(6, 0, 4, 4, ZlibSyncStream().next(solidTile(red))),
        ]),
      );

      expect(s.ended.failure, RfbFailure.decode);
    });

    test('an oversized payload length is refused unread', () async {
      final s = RfbSession();
      await s.handshake(8, 4);
      await s.send(
        cat([
          bytes([0, 0]),
          u16(1),
          rfbRectHeader(0, 0, 4, 4, 16),
          u32(0xF0000000),
        ]),
      );

      expect(s.ended.failure, RfbFailure.decode);
    });

    test('an inflate bomb is stopped at the rectangle\'s size', () async {
      // 4 MB of zeros compress to a few KB.
      final bomb = zlib.encode(List.filled(4 << 20, 0));
      final s = RfbSession();
      await s.handshake(8, 4);
      await s.send(rfbUpdate([rfbZrleRect(0, 0, 4, 4, bomb)]));

      expect(s.ended.failure, RfbFailure.decode);
    });
  });

  group('truncation', () {
    test(
      'at every offset of a recorded session ends cleanly or as decode',
      () async {
        final stream = ZlibSyncStream();
        Rgb at(int x, int y) => [x * 3, y * 3, 5];
        final parts = [
          ...rfbHandshake(80, 70),
          rfbUpdate([
            rfbZrleRect(
              0,
              0,
              70,
              66,
              stream.next([
                ...solidTile(green),
                ...rawTile(6, 64, at),
                ...packedTile([red, white], 64, 2, (x, y) => x % 2),
                ...paletteRleTile([blue, white], [(1, 6), (0, 6)]),
              ]),
            ),
            rfbRawRect(0, 0, 2, 2, [1, 2, 3]),
          ]),
          rfbUpdate([
            rfbZrleRect(0, 0, 8, 8, stream.next(rleTile([(red, 64)]))),
          ]),
          bytes([2]), // Bell
        ];
        final session = cat(parts);
        final boundaries = <int>{0};
        var end = 0;
        for (final part in parts) {
          end += part.length;
          boundaries.add(end);
        }

        // The whole session decodes.
        final whole = RfbSession();
        await whole.send(session);
        expect(whole.events.whereType<RfbEnded>(), isEmpty);

        for (var k = 0; k <= session.length; k++) {
          final s = RfbSession();
          if (k > 0) await s.send(session.sublist(0, k));
          await s.channel.serverClose(1006);
          await pumpEventQueue();

          final failure = s.ended.failure;
          if (boundaries.contains(k)) {
            expect(failure, isNull, reason: 'offset $k is a message boundary');
          } else {
            expect(failure, RfbFailure.decode, reason: 'offset $k');
          }
          expect(s.ended.closeCode, 1006);
        }
      },
    );
  });
}
