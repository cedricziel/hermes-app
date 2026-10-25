import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/rfb/rfb_client.dart';
import 'package:hermes_app/src/bot_screen/rfb/rfb_input_sink.dart';

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

void expectInputUnusable(RfbClient client) {
  expect(() => client.pointer(0, 0, 0), throwsStateError);
  expect(() => client.key(0x61, down: true), throwsStateError);
  expect(() => client.scroll(0, 0, dy: 1), throwsStateError);
  expect(() => client.cutText('x'), throwsStateError);
}

void main() {
  group('handshake', () {
    test('answers the server version with 3.8 and picks None', () async {
      final s = RfbSession();
      await s.send(rfbVersion());
      expect(s.channel.sentBytes, ascii('RFB 003.008\n'));

      await s.send([1, 1]);
      expect(s.channel.sentBytes.sublist(12), [1]);
    });

    test('accepts a server newer than 3.8', () async {
      final s = RfbSession();
      await s.send(rfbVersion('RFB 003.889\n'));
      expect(s.channel.sentBytes, ascii('RFB 003.008\n'));
      expect(s.events, isEmpty);
    });

    test('fails on a version below 3.8', () async {
      for (final old in ['RFB 003.003\n', 'RFB 003.007\n']) {
        final s = RfbSession();
        await s.send(rfbVersion(old));
        expect(s.ended.failure, RfbFailure.version);
        expect(s.ended.step, RfbStep.handshake);
        expect(s.channel.sentCloseCode, 1000);
        expect(s.channel.sentBytes, isEmpty);
      }
    });

    test('fails on a greeting that is not RFB', () async {
      final s = RfbSession();
      await s.send(ascii('SSH-2.0-Open'));
      expect(s.ended.failure, RfbFailure.version);
    });

    test('reads the reason when no security type is offered', () async {
      final s = RfbSession();
      await s.send(rfbVersion());
      await s.send([0]);
      expect(s.events, isEmpty);
      await s.send(rfbReason('too many connections'));

      expect(s.ended.failure, RfbFailure.security);
      expect(s.ended.reason, 'too many connections');
    });

    test('fails when None is not among the security types', () async {
      final s = RfbSession();
      await s.send(rfbVersion());
      await s.send([2, 2, 19]);

      expect(s.ended.failure, RfbFailure.security);
      expect(s.channel.sentBytes, ascii('RFB 003.008\n'));
    });

    test('fails with the reason when the security result is not 0', () async {
      final s = RfbSession();
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
      final s = RfbSession();
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

        final packed = RfbSession();
        await packed.send(server);

        final split = RfbSession();
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
      final s = RfbSession();
      s.channel.serverSend('RFB 003.008\n');
      await pumpEventQueue();

      expect(s.ended.failure, RfbFailure.protocol);
    });

    test('a socket error is a failure, not a clean close', () async {
      final s = RfbSession();
      await s.handshake();
      s.channel.serverError();
      await pumpEventQueue();

      expect(s.ended.failure, RfbFailure.connection);
      expect(s.ended.step, RfbStep.decode);
    });

    test(
      'a socket error during the handshake is a handshake failure',
      () async {
        final s = RfbSession();
        await s.send(rfbVersion());
        s.channel.serverError();
        await pumpEventQueue();

        expect(s.ended.failure, RfbFailure.connection);
        expect(s.ended.step, RfbStep.handshake);
      },
    );

    test(
      'a close with nothing buffered mid-handshake has no failure',
      () async {
        final s = RfbSession();
        await s.send(rfbVersion());
        await s.channel.serverClose(4401);
        await pumpEventQueue();

        expect(s.events.whereType<RfbConnected>(), isEmpty);
        expect(s.ended.failure, isNull);
        expect(s.ended.closeCode, 4401);
      },
    );

    test('reports the close code the server sent', () async {
      final s = RfbSession();
      await s.channel.serverClose(4401);
      await pumpEventQueue();

      expect(s.ended.failure, isNull);
      expect(s.ended.closeCode, 4401);
    });
  });

  group('updates', () {
    test('Raw rectangles paint opaque pixels', () async {
      final s = RfbSession();
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
      final s = RfbSession();
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

    test(
      'CopyRect with a source and destination that overlap vertically',
      () async {
        final s = RfbSession();
        await s.handshake(4, 6);
        await s.send(
          rfbUpdate([
            for (var y = 0; y < 4; y++)
              for (var x = 0; x < 2; x++)
                rfbRawRect(x, y, 1, 1, [y * 10 + x, 0, 0]),
          ]),
        );
        // Rows 0-2 move down one row, over themselves.
        await s.send(rfbUpdate([rfbCopyRect(0, 1, 2, 3, 0, 0)]));

        for (var x = 0; x < 2; x++) {
          expect(s.pixel(x, 0), [x, 0, 0, 255]);
          expect(s.pixel(x, 1), [x, 0, 0, 255]);
          expect(s.pixel(x, 2), [10 + x, 0, 0, 255]);
          expect(s.pixel(x, 3), [20 + x, 0, 0, 255]);
        }
      },
    );

    test('an update is followed by an incremental request', () async {
      final s = RfbSession();
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
      final s = RfbSession();
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
      final s = RfbSession();
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
      final s = RfbSession();
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
          final s = RfbSession();
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
      final s = RfbSession();
      await s.handshake();
      await s.send([3, 0, 0, 0, ...u32(0x7FFFFFF0)]);
      await s.send(Uint8List(1 << 20));
      await s.send(Uint8List(1 << 20));

      expect(s.events.whereType<RfbEnded>(), isEmpty);
    });

    test('an unknown server message type is a protocol failure', () async {
      final s = RfbSession();
      await s.handshake();
      await s.send([42]);

      expect(s.ended.failure, RfbFailure.protocol);
      expect(s.ended.step, RfbStep.decode);
      expect(s.channel.sentCloseCode, 1000);
    });

    test('an unrequested encoding is a protocol failure', () async {
      final s = RfbSession();
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
      final s = RfbSession();
      await s.handshake(8, 4);
      await s.send(
        rfbUpdate([
          rfbRawRect(7, 3, 2, 2, [1, 1, 1]),
        ]),
      );

      expect(s.ended.failure, RfbFailure.decode);
    });

    test('a desktop over 16 Mi pixels is refused', () async {
      final s = RfbSession();
      for (final part in rfbHandshake(4097, 4096)) {
        await s.send(part);
      }

      expect(s.ended.failure, RfbFailure.protocol);
    });

    test('an absurd desktop size is refused instead of allocated', () async {
      final s = RfbSession();
      for (final part in rfbHandshake(65535, 65535)) {
        await s.send(part);
      }

      expect(s.ended.failure, RfbFailure.protocol);
    });

    test('a socket that closes mid-message is a decode failure', () async {
      final s = RfbSession();
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

    test('close refuses a status code a close frame cannot carry', () async {
      final s = RfbSession();
      await s.handshake();

      for (final code in [0, 999, 1001, 2999, 5000]) {
        expect(
          () => s.client.close(code),
          throwsArgumentError,
          reason: '$code',
        );
      }
      expect(s.events.whereType<RfbEnded>(), isEmpty);
      await s.client.close(3000);
      expect(s.channel.sentCloseCode, 3000);
    });

    test('close sends the status code and ends the events', () async {
      final s = RfbSession();
      await s.handshake();
      await s.client.close(4100);
      await pumpEventQueue();

      expect(s.channel.sentCloseCode, 4100);
      expect(s.ended.failure, isNull);
    });

    test(
      'writes only the handshake, pixel format, encodings and requests',
      () async {
        final s = RfbSession();
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

  group('input', () {
    Future<RfbSession> ready([int w = 8, int h = 4]) async {
      final s = RfbSession();
      await s.handshake(w, h);
      return s;
    }

    // What the client wrote after the handshake, framed as the bridge does,
    // keeping only the input messages (types 4, 5 and 6).
    List<List<int>> input(RfbSession s) => [
      for (final m in clientMessages(s.channel.sentBytes))
        if (m[0] >= 4 && m[0] <= 6) m.toList(),
    ];

    test('a PointerEvent is 6 bytes: type, mask, x and y', () async {
      final s = await ready(1024, 768);
      s.client.pointer(0x0123, 0x0145, 5);

      expect(input(s), [
        [5, 5, 0x01, 0x23, 0x01, 0x45],
      ]);
    });

    test('coordinates are clamped to the screen', () async {
      final s = await ready(8, 4);
      s.client
        ..pointer(-3, -1, 0)
        ..pointer(99, 99, 1)
        ..pointer(7, 3, 0);

      expect(input(s), [
        [5, 0, 0, 0, 0, 0],
        [5, 1, 0, 7, 0, 3],
        [5, 0, 0, 7, 0, 3],
      ]);
    });

    test('clamps to the new size after the desktop resized', () async {
      final s = await ready(8, 4);
      await s.send(rfbUpdate([rfbDesktopSizeRect(16, 6)]));
      s.client.pointer(99, 99, 0);

      expect(input(s), [
        [5, 0, 0, 15, 0, 5],
      ]);
    });

    test('a button mask over one byte is refused', () async {
      final s = await ready();
      expect(() => s.client.pointer(0, 0, 256), throwsArgumentError);
      expect(() => s.client.pointer(0, 0, -1), throwsArgumentError);
      expect(input(s), isEmpty);
    });

    test('a KeyEvent is 8 bytes: type, down flag, padding, keysym', () async {
      final s = await ready();
      s.client
        ..key(0x010020AC, down: true)
        ..key(0x010020AC, down: false);

      expect(input(s), [
        [4, 1, 0, 0, 0x01, 0x00, 0x20, 0xAC],
        [4, 0, 0, 0, 0x01, 0x00, 0x20, 0xAC],
      ]);
    });

    test('a keysym that does not fit 32 bits is refused', () async {
      final s = await ready();
      expect(() => s.client.key(-1, down: true), throwsArgumentError);
      expect(() => s.client.key(0x100000000, down: true), throwsArgumentError);
      expect(input(s), isEmpty);
    });

    test('a wheel notch is a press and a release of its button', () async {
      final s = await ready();
      s.client.scroll(3, 2, dy: 3);

      expect(input(s), [
        for (var i = 0; i < 3; i++) ...[
          [5, 16, 0, 3, 0, 2], // button 5, down
          [5, 0, 0, 3, 0, 2],
        ],
      ]);
    });

    test('up is button 4, left is button 6 and right is button 7', () async {
      final s = await ready();
      s.client
        ..scroll(1, 1, dy: -2)
        ..scroll(1, 1, dx: -1)
        ..scroll(1, 1, dx: 1);

      expect(input(s).map((m) => m[1]), [8, 0, 8, 0, 32, 0, 64, 0]);
    });

    test('both axes in one call send the vertical notches first', () async {
      final s = await ready();
      s.client.scroll(0, 0, dx: 1, dy: 1);

      expect(input(s).map((m) => m[1]), [16, 0, 64, 0]);
    });

    test('a wheel notch keeps the buttons that are held', () async {
      final s = await ready();
      s.client
        ..pointer(4, 1, 1)
        ..scroll(4, 1, dy: 1);

      expect(input(s).map((m) => m[1]), [1, 17, 1]);
    });

    test('the held buttons follow the latest pointer event', () async {
      final s = await ready();
      s.client
        ..pointer(4, 1, 1 | 4)
        ..pointer(4, 1, 0)
        ..scroll(4, 1, dy: 1);

      expect(input(s).map((m) => m[1]), [5, 0, 16, 0]);
    });

    test('a wheel bit passed to pointer is not remembered as held', () async {
      final s = await ready();
      s.client
        ..pointer(4, 1, 16)
        ..scroll(4, 1, dy: 1);

      expect(input(s).map((m) => m[1]), [16, 16, 0]);
    });

    test('a scroll with no notches sends nothing', () async {
      final s = await ready();
      s.client.scroll(1, 1);

      expect(input(s), isEmpty);
    });

    test('clamps the position of a scroll', () async {
      final s = await ready(8, 4);
      s.client.scroll(50, -5, dy: 1);

      expect(input(s).first, [5, 16, 0, 7, 0, 0]);
    });

    test('ClientCutText is 8 + n bytes with a positive length', () async {
      final s = await ready();
      s.client.cutText('hi');

      expect(input(s), [
        [6, 0, 0, 0, 0, 0, 0, 2, 0x68, 0x69],
      ]);
    });

    test('Latin-1 text goes out byte for byte', () async {
      final s = await ready();
      s.client.cutText('café ÿ ');

      final message = input(s).single;
      expect(message.sublist(4, 8), [0, 0, 0, 7]);
      expect(message.sublist(8), [...'caf'.codeUnits, 0xE9, 0x20, 0xFF, 0xA0]);
    });

    test('line breaks go out as a line feed', () async {
      final s = await ready();
      s.client.cutText('a\r\nb\rc\nd');

      expect(input(s).single.sublist(8), 'a\nb\nc\nd'.codeUnits);
    });

    test('empty text is sent, to clear the remote clipboard', () async {
      final s = await ready();
      s.client.cutText('');

      expect(input(s), [
        [6, 0, 0, 0, 0, 0, 0, 0],
      ]);
    });

    test('text outside Latin-1 is refused and nothing is sent', () async {
      final s = await ready();
      for (final text in ['€', 'ok \u{1F600}', 'aĀ']) {
        expect(
          () => s.client.cutText(text),
          throwsA(RfbClipboardError.notLatin1),
          reason: text,
        );
      }
      expect(input(s), isEmpty);
    });

    test('256 KiB goes out and one byte more is refused', () async {
      final s = await ready();
      s.client.cutText('a' * (256 * 1024));
      expect(input(s).single.length, 8 + 256 * 1024);
      expect(input(s).single.sublist(4, 8), [0, 4, 0, 0]);

      expect(
        () => s.client.cutText('a' * (256 * 1024 + 1)),
        throwsA(RfbClipboardError.tooLarge),
      );
      expect(input(s), hasLength(1));
    });

    test('the clipboard errors carry no text', () {
      for (final error in RfbClipboardError.values) {
        expect(error.toString(), startsWith('RfbClipboardError.'));
      }
    });

    test('every input method throws before ServerInit', () async {
      final s = RfbSession();
      void expectUnusable() => expectInputUnusable(s.client);

      expectUnusable();
      await s.send(rfbVersion());
      expectUnusable();
      await s.send([1, 1]);
      await s.send(u32(0));
      expectUnusable();
      expect(s.channel.sentBytes.length, 12 + 1 + 1);
    });

    test('every input method throws after the stream ended', () async {
      for (final end in <Future<void> Function(RfbSession)>[
        (s) => s.client.close(),
        (s) => s.channel.serverClose(),
        (s) async {
          s.channel.serverError();
          await pumpEventQueue();
        },
      ]) {
        final s = await ready();
        await end(s);
        await pumpEventQueue();

        expectInputUnusable(s.client);
        expect(input(s), isEmpty);
      }
    });

    test('never sends SetDesktopSize or a QEMU message', () async {
      final s = await ready();
      s.client
        ..pointer(1, 1, 1)
        ..key(0x61, down: true)
        ..scroll(1, 1, dy: 1, dx: -1)
        ..cutText('x');
      await s.send(rfbUpdate([rfbDesktopSizeRect(16, 6)]));

      // clientMessages throws on a type the bridge cannot frame.
      final types = clientMessages(s.channel.sentBytes).map((m) => m[0]);
      expect(types, isNot(contains(251)));
      expect(types, isNot(contains(255)));
      expect(types.toSet(), {0, 2, 3, 4, 5, 6});
    });
  });

  group('counters', () {
    test('count the bytes received and the encodings seen', () async {
      final s = RfbSession();
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
