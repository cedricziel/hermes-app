import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/input/keysyms.dart';

void main() {
  const mapper = KeysymMapper();

  group('non-printing keys', () {
    test('map to the X11 keysyms', () {
      final expected = <LogicalKeyboardKey, int>{
        LogicalKeyboardKey.escape: 0xff1b,
        LogicalKeyboardKey.tab: 0xff09,
        LogicalKeyboardKey.enter: 0xff0d,
        LogicalKeyboardKey.backspace: 0xff08,
        LogicalKeyboardKey.insert: 0xff63,
        LogicalKeyboardKey.delete: 0xffff,
        LogicalKeyboardKey.home: 0xff50,
        LogicalKeyboardKey.end: 0xff57,
        LogicalKeyboardKey.pageUp: 0xff55,
        LogicalKeyboardKey.pageDown: 0xff56,
        LogicalKeyboardKey.arrowLeft: 0xff51,
        LogicalKeyboardKey.arrowUp: 0xff52,
        LogicalKeyboardKey.arrowRight: 0xff53,
        LogicalKeyboardKey.arrowDown: 0xff54,
        LogicalKeyboardKey.shiftLeft: 0xffe1,
        LogicalKeyboardKey.shiftRight: 0xffe2,
        LogicalKeyboardKey.controlLeft: 0xffe3,
        LogicalKeyboardKey.controlRight: 0xffe4,
        LogicalKeyboardKey.capsLock: 0xffe5,
        LogicalKeyboardKey.metaLeft: 0xffeb,
        LogicalKeyboardKey.metaRight: 0xffec,
        LogicalKeyboardKey.altLeft: 0xffe9,
        LogicalKeyboardKey.altRight: 0xffea,
      };
      for (final entry in expected.entries) {
        expect(
          mapper.forLogicalKey(entry.key),
          entry.value,
          reason: entry.key.debugName,
        );
      }
    });

    test('F1 to F12 are 0xffbe to 0xffc9', () {
      final keys = [
        LogicalKeyboardKey.f1,
        LogicalKeyboardKey.f2,
        LogicalKeyboardKey.f3,
        LogicalKeyboardKey.f4,
        LogicalKeyboardKey.f5,
        LogicalKeyboardKey.f6,
        LogicalKeyboardKey.f7,
        LogicalKeyboardKey.f8,
        LogicalKeyboardKey.f9,
        LogicalKeyboardKey.f10,
        LogicalKeyboardKey.f11,
        LogicalKeyboardKey.f12,
      ];
      expect(
        [for (final key in keys) mapper.forLogicalKey(key)],
        [for (var i = 0; i < 12; i++) 0xffbe + i],
      );
    });

    test('a key without a keysym of its own is null', () {
      expect(mapper.forLogicalKey(LogicalKeyboardKey.keyA), isNull);
      expect(mapper.forLogicalKey(LogicalKeyboardKey.f13), isNull);
    });
  });

  group('commandAsControl', () {
    test('maps Meta to Control only when set', () {
      const control = KeysymMapper(commandAsControl: true);

      expect(control.forLogicalKey(LogicalKeyboardKey.metaLeft), 0xffe3);
      expect(control.forLogicalKey(LogicalKeyboardKey.metaRight), 0xffe4);
      expect(mapper.forLogicalKey(LogicalKeyboardKey.metaLeft), 0xffeb);
      expect(mapper.forLogicalKey(LogicalKeyboardKey.metaRight), 0xffec);
    });

    test('leaves Control and the other keys alone', () {
      const control = KeysymMapper(commandAsControl: true);

      expect(control.forLogicalKey(LogicalKeyboardKey.controlLeft), 0xffe3);
      expect(control.forLogicalKey(LogicalKeyboardKey.altLeft), 0xffe9);
      expect(control.forLogicalKey(LogicalKeyboardKey.escape), 0xff1b);
    });
  });

  group('characters', () {
    test('ASCII printable characters are their code point', () {
      for (var unit = 0x20; unit <= 0x7e; unit++) {
        expect(mapper.forCodePoint(unit), unit);
      }
    });

    test('Latin-1 characters are their code point', () {
      for (var unit = 0xa0; unit <= 0xff; unit++) {
        expect(mapper.forCodePoint(unit), unit);
      }
      expect(mapper.forCodePoint('\u00E9'.runes.single), 0xe9);
    });

    test('any other character is an X11 Unicode keysym', () {
      expect(mapper.forCodePoint(0x20AC), 0x010020AC); // euro sign
      expect(mapper.forCodePoint(0x0100), 0x01000100);
      expect(mapper.forCodePoint(0x4E2D), 0x01004E2D);
    });

    test('a character outside the BMP is one keysym', () {
      expect(mapper.forCodePoint(0x1F600), 0x0101F600);
      expect(mapper.forCodePoint(0x10FFFF), 0x0110FFFF);
    });

    test('the C0 controls with a key of their own map to it', () {
      expect(mapper.forCodePoint(0x08), 0xff08);
      expect(mapper.forCodePoint(0x09), 0xff09);
      expect(mapper.forCodePoint(0x0a), 0xff0d);
      expect(mapper.forCodePoint(0x0d), 0xff0d);
      expect(mapper.forCodePoint(0x1b), 0xff1b);
      expect(mapper.forCodePoint(0x7f), 0xffff);
    });

    test('a value that is not a character is refused', () {
      for (final bad in [-1, 0xD800, 0xDFFF, 0x110000]) {
        expect(() => mapper.forCodePoint(bad), throwsArgumentError);
      }
    });

    test('control characters without a key of their own are refused', () {
      final others = [
        for (var c = 0; c < 0x20; c++)
          if (![0x08, 0x09, 0x0a, 0x0d, 0x1b].contains(c)) c,
        for (var c = 0x80; c < 0xa0; c++) c,
      ];
      for (final control in others) {
        expect(
          () => mapper.forCodePoint(control),
          throwsArgumentError,
          reason: '$control',
        );
      }
      expect(() => mapper.text('a\u0000'), throwsArgumentError);
    });

    test('the errors do not carry the value', () {
      for (final bad in [0xD800, 0x110000, 0x07]) {
        expect(
          () => mapper.forCodePoint(bad),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.toString(),
              'text',
              isNot(anyOf(contains('$bad'), contains(bad.toRadixString(16)))),
            ),
          ),
        );
      }
    });
  });

  group('text', () {
    test('is a press and a release for each character', () {
      expect(mapper.text('hi'), [
        (keysym: 0x68, down: true),
        (keysym: 0x68, down: false),
        (keysym: 0x69, down: true),
        (keysym: 0x69, down: false),
      ]);
    });

    test('uses Unicode keysyms for what Latin-1 lacks', () {
      expect(mapper.text('€'), [
        (keysym: 0x010020AC, down: true),
        (keysym: 0x010020AC, down: false),
      ]);
    });

    test('splits a grapheme cluster into its code points', () {
      // e and a combining acute accent; a flag is two regional indicators.
      expect(mapper.text('é').map((s) => s.keysym), [
        0x65,
        0x65,
        0x01000301,
        0x01000301,
      ]);
      expect(mapper.text('\u{1F1E9}\u{1F1EA}'), hasLength(4));
    });

    test('a character outside the BMP is one press and one release', () {
      expect(mapper.text('\u{1F600}'), [
        (keysym: 0x0101F600, down: true),
        (keysym: 0x0101F600, down: false),
      ]);
    });

    test('line breaks are Return, once for CRLF', () {
      expect(mapper.text('\n').map((s) => s.keysym), [0xff0d, 0xff0d]);
      expect(mapper.text('\r\n').map((s) => s.keysym), [0xff0d, 0xff0d]);
      expect(mapper.text('a\tb').map((s) => s.keysym), [
        0x61,
        0x61,
        0xff09,
        0xff09,
        0x62,
        0x62,
      ]);
    });

    test('empty text is nothing', () {
      expect(mapper.text(''), isEmpty);
    });

    test('a lone surrogate is refused, not replaced', () {
      expect(() => mapper.text('a\uD800'), throwsArgumentError);
    });
  });
}
