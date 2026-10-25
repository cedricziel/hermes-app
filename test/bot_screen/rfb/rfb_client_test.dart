import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/rfb/rfb_client.dart';

import '../../support/fake_rfb_server.dart';

final _setPixelFormat = [
  ...[0, 0, 0, 0], // type, padding
  ...[32, 24, 0, 1], // bpp, depth, big-endian, true colour
  ...[0, 255, 0, 255, 0, 255], // maxima
  ...[0, 8, 16], // shifts
  ...[0, 0, 0],
];

// ZRLE (16), CopyRect (1), Raw (0), DesktopSize (-223).
final _setEncodings = [
  ...[2, 0, 0, 4],
  ...[0, 0, 0, 16],
  ...[0, 0, 0, 1],
  ...[0, 0, 0, 0],
  ...[0xFF, 0xFF, 0xFF, 0x21],
];

List<int> _request(int w, int h, {required bool incremental}) => [
  3,
  incremental ? 1 : 0,
  ...[0, 0, 0, 0],
  ...u16(w),
  ...u16(h),
];

class _Session {
  _Session() : channel = FakeDisplayChannel() {
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

void main() {
  group('handshake', () {
    test('answers the server version with 3.8 and picks None', () async {
      final s = _Session();
      await s.send(rfbVersion());
      expect(s.channel.sentBytes, ascii('RFB 003.008\n'));

      await s.send([1, 1]);
      expect(s.channel.sentBytes.sublist(12), [1]);
    });

    test('accepts a server newer than 3.8', () async {
      final s = _Session();
      await s.send(rfbVersion('RFB 003.889\n'));
      expect(s.channel.sentBytes, ascii('RFB 003.008\n'));
      expect(s.events, isEmpty);
    });

    test('fails on a version below 3.8', () async {
      for (final old in ['RFB 003.003\n', 'RFB 003.007\n']) {
        final s = _Session();
        await s.send(rfbVersion(old));
        expect(s.ended.failure, RfbFailure.version);
        expect(s.ended.step, RfbStep.handshake);
        expect(s.channel.sentCloseCode, 1000);
        expect(s.channel.sentBytes, isEmpty);
      }
    });

    test('fails on a greeting that is not RFB', () async {
      final s = _Session();
      await s.send(ascii('SSH-2.0-Open'));
      expect(s.ended.failure, RfbFailure.version);
    });

    test('reads the reason when no security type is offered', () async {
      final s = _Session();
      await s.send(rfbVersion());
      await s.send([0]);
      expect(s.events, isEmpty);
      await s.send(rfbReason('too many connections'));

      expect(s.ended.failure, RfbFailure.security);
      expect(s.ended.reason, 'too many connections');
    });

    test('fails when None is not among the security types', () async {
      final s = _Session();
      await s.send(rfbVersion());
      await s.send([2, 2, 19]);

      expect(s.ended.failure, RfbFailure.security);
      expect(s.channel.sentBytes, ascii('RFB 003.008\n'));
    });

    test('fails with the reason when the security result is not 0', () async {
      final s = _Session();
      await s.send(rfbVersion());
      await s.send([1, 1]);
      await s.send(u32(1));
      await s.send(rfbReason('denied'));

      expect(s.ended.failure, RfbFailure.security);
      expect(s.ended.reason, 'denied');
      // No ClientInit went out.
      expect(s.channel.sentBytes.length, 13);
    });

    test('sends a shared ClientInit, then the pixel format, encodings and '
        'a full non-incremental request', () async {
      final s = _Session();
      await s.handshake(1280, 800);

      expect(s.events.single, isA<RfbConnected>());
      final connected = s.events.single as RfbConnected;
      expect((connected.width, connected.height), (1280, 800));
      expect(s.channel.sentBytes, [
        ...ascii('RFB 003.008\n'),
        1, // security type None
        1, // ClientInit: shared
        ..._setPixelFormat,
        ..._setEncodings,
        ..._request(1280, 800, incremental: false),
      ]);
      expect(s.client.framebuffer!.width, 1280);
      expect(s.client.framebuffer!.height, 800);
    });

    test(
      'parses the same when packed in one frame or split byte by byte',
      () async {
        final server = cat([
          ...rfbHandshake(8, 4),
          rfbUpdate([
            rfbRawRect(0, 0, 2, 2, [9, 8, 7]),
          ]),
        ]);

        final packed = _Session();
        await packed.send(server);

        final split = _Session();
        for (final byte in server) {
          await split.send([byte]);
        }

        for (final s in [packed, split]) {
          expect(s.events.length, 2);
          expect(s.pixel(1, 1), [9, 8, 7, 255]);
        }
        expect(split.channel.sentBytes, packed.channel.sentBytes);
      },
    );

    test('fails on a text frame', () async {
      final s = _Session();
      s.channel.serverSend('RFB 003.008\n');
      await pumpEventQueue();

      expect(s.ended.failure, RfbFailure.protocol);
    });

    test('reports the close code the server sent', () async {
      final s = _Session();
      await s.channel.serverClose(4401);
      await pumpEventQueue();

      expect(s.ended.failure, isNull);
      expect(s.ended.closeCode, 4401);
    });
  });

  group('updates', () {
    test('Raw rectangles paint opaque pixels', () async {
      final s = _Session();
      await s.handshake();
      await s.send(
        rfbUpdate([
          rfbRawRect(2, 1, 3, 2, [10, 20, 30]),
        ]),
      );

      expect(s.events.last, isA<RfbUpdated>());
      expect((s.events.last as RfbUpdated).dirty, const RfbRect(2, 1, 3, 2));
      expect(s.pixel(2, 1), [10, 20, 30, 255]);
      expect(s.pixel(4, 2), [10, 20, 30, 255]);
      expect(s.pixel(1, 1), [0, 0, 0, 255]);
      expect(s.pixel(5, 1), [0, 0, 0, 255]);
    });

    test('CopyRect copies pixels, also over themselves', () async {
      final s = _Session();
      await s.handshake();
      await s.send(
        rfbUpdate([
          rfbRawRect(0, 0, 2, 1, [1, 2, 3]),
          rfbRawRect(2, 0, 1, 1, [4, 5, 6]),
        ]),
      );
      await s.send(rfbUpdate([rfbCopyRect(1, 0, 2, 1, 0, 0)]));

      expect(s.pixel(0, 0), [1, 2, 3, 255]);
      expect(s.pixel(1, 0), [1, 2, 3, 255]);
      expect(s.pixel(2, 0), [1, 2, 3, 255]);
      expect((s.events.last as RfbUpdated).dirty, const RfbRect(1, 0, 2, 1));
    });

    test('an update is followed by an incremental request', () async {
      final s = _Session();
      await s.handshake(8, 4);
      final before = s.channel.sentBytes.length;
      await s.send(
        rfbUpdate([
          rfbRawRect(0, 0, 1, 1, [1, 1, 1]),
        ]),
      );

      expect(
        s.channel.sentBytes.sublist(before),
        _request(8, 4, incremental: true),
      );
    });

    test('DesktopSize resizes and asks for the whole new screen', () async {
      final s = _Session();
      await s.handshake(8, 4);
      await s.send(
        rfbUpdate([
          rfbRawRect(0, 0, 1, 1, [1, 1, 1]),
        ]),
      );
      final before = s.channel.sentBytes.length;
      await s.send(rfbUpdate([rfbDesktopSizeRect(16, 6)]));

      final fb = s.client.framebuffer!;
      expect((fb.width, fb.height), (16, 6));
      expect(s.pixel(0, 0), [0, 0, 0, 255]);
      final resized = s.events.last as RfbResized;
      expect((resized.width, resized.height), (16, 6));
      expect(
        s.channel.sentBytes.sublist(before),
        _request(16, 6, incremental: false),
      );
    });

    test('draws into the new size within the same update', () async {
      final s = _Session();
      await s.handshake(8, 4);
      await s.send(
        rfbUpdate([
          rfbDesktopSizeRect(16, 6),
          rfbRawRect(15, 5, 1, 1, [7, 7, 7]),
        ]),
      );

      expect(s.pixel(15, 5), [7, 7, 7, 255]);
      expect(s.events.whereType<RfbEnded>(), isEmpty);
    });

    test('reads past Bell and SetColourMapEntries', () async {
      final s = _Session();
      await s.handshake();
      await s.send([2]); // Bell
      await s.send([
        1, 0, // SetColourMapEntries
        ...u16(0), ...u16(2),
        ...List.filled(12, 0xAB),
      ]);
      await s.send(
        rfbUpdate([
          rfbRawRect(0, 0, 1, 1, [3, 3, 3]),
        ]),
      );

      expect(s.pixel(0, 0), [3, 3, 3, 255]);
      expect(s.events.whereType<RfbEnded>(), isEmpty);
    });

    test(
      'discards ServerCutText of either form, however it is framed',
      () async {
        for (final length in [5, -5]) {
          final s = _Session();
          await s.handshake();
          final secret = ascii('hunter2');
          final message = cat([
            bytes([3, 0, 0, 0]),
            u32(length & 0xFFFFFFFF),
            secret.sublist(0, length.abs()),
          ]);
          for (final byte in message) {
            await s.send([byte]);
          }
          await s.send(
            rfbUpdate([
              rfbRawRect(0, 0, 1, 1, [3, 3, 3]),
            ]),
          );

          expect(s.pixel(0, 0), [3, 3, 3, 255]);
          expect(s.events.map((e) => e.runtimeType), [
            RfbConnected,
            RfbUpdated,
          ]);
        }
      },
    );

    test('skips a very large ServerCutText without buffering it', () async {
      final s = _Session();
      await s.handshake();
      await s.send([3, 0, 0, 0, ...u32(0x7FFFFFF0)]);
      await s.send(Uint8List(1 << 20));
      await s.send(Uint8List(1 << 20));

      expect(s.events.whereType<RfbEnded>(), isEmpty);
    });

    test('an unknown server message type is a protocol failure', () async {
      final s = _Session();
      await s.handshake();
      await s.send([42]);

      expect(s.ended.failure, RfbFailure.protocol);
      expect(s.ended.step, RfbStep.decode);
      expect(s.channel.sentCloseCode, 1000);
    });

    test('an unrequested encoding is a protocol failure', () async {
      final s = _Session();
      await s.handshake();
      await s.send(
        cat([
          bytes([0, 0]),
          u16(1),
          rfbRectHeader(0, 0, 1, 1, 7),
        ]),
      );

      expect(s.ended.failure, RfbFailure.protocol);
    });

    test('a rectangle outside the screen is a decode failure', () async {
      final s = _Session();
      await s.handshake(8, 4);
      await s.send(
        rfbUpdate([
          rfbRawRect(7, 3, 2, 2, [1, 1, 1]),
        ]),
      );

      expect(s.ended.failure, RfbFailure.decode);
    });

    test('an absurd desktop size is refused instead of allocated', () async {
      final s = _Session();
      for (final part in rfbHandshake(65535, 65535)) {
        await s.send(part);
      }

      expect(s.ended.failure, RfbFailure.protocol);
    });

    test('a socket that closes mid-message is a decode failure', () async {
      final s = _Session();
      await s.handshake();
      await s.send(
        rfbUpdate([
          rfbRawRect(0, 0, 2, 2, [1, 1, 1]),
        ]).sublist(0, 20),
      );
      await s.channel.serverClose(1006);
      await pumpEventQueue();

      expect(s.ended.failure, RfbFailure.decode);
    });

    test('close sends the status code and ends the events', () async {
      final s = _Session();
      await s.handshake();
      await s.client.close(4100);
      await pumpEventQueue();

      expect(s.channel.sentCloseCode, 4100);
      expect(s.ended.failure, isNull);
    });

    test(
      'writes only the handshake, pixel format, encodings and requests',
      () async {
        final s = _Session();
        await s.handshake(8, 4);
        await s.send(
          rfbUpdate([
            rfbRawRect(0, 0, 1, 1, [1, 1, 1]),
          ]),
        );
        await s.send([3, 0, 0, 0, ...u32(2), 0x68, 0x69]);
        await s.send(rfbUpdate([rfbDesktopSizeRect(16, 6)]));
        await s.client.close();

        final types = clientMessages(s.channel.sentBytes).map((m) => m[0]);
        expect(types, [0, 2, 3, 3, 3]);
      },
    );
  });

  group('counters', () {
    test('count the bytes received and the encodings seen', () async {
      final s = _Session();
      final handshake = rfbHandshake(8, 4);
      for (final part in handshake) {
        await s.send(part);
      }
      expect(s.client.bytesReceived, cat(handshake).length);
      expect(s.client.encodingsSeen, isEmpty);

      final update = rfbUpdate([
        rfbRawRect(0, 0, 1, 1, [1, 1, 1]),
        rfbCopyRect(1, 0, 1, 1, 0, 0),
        rfbDesktopSizeRect(8, 4),
      ]);
      await s.send(update);

      expect(s.client.bytesReceived, cat(handshake).length + update.length);
      expect(s.client.encodingsSeen, {0, 1, -223});
    });
  });
}
