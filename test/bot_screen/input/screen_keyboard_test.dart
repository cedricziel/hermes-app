import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/input/screen_keyboard.dart';
import 'package:hermes_app/src/bot_screen/rfb/rfb_input_sink.dart';

/// Records key events as `d <keysym>` and `u <keysym>`, in hex.
class _KeySink implements RfbInputSink {
  final calls = <String>[];
  bool closed = false;

  @override
  void key(int keysym, {required bool down}) {
    if (closed) throw StateError('closed');
    calls.add('${down ? 'd' : 'u'} ${keysym.toRadixString(16)}');
  }

  @override
  void pointer(int x, int y, int buttonMask) => fail('no pointer');

  @override
  void scroll(int x, int y, {int dx = 0, int dy = 0}) => fail('no scroll');

  @override
  void cutText(String text) => fail('no clipboard');
}

const _control = 'ffe3';
const _shift = 'ffe1';
const _alt = 'ffe9';

void main() {
  late _KeySink sink;
  late ScreenKeyboard keyboard;
  late List<ScreenKeyResult> results;

  Future<void> pump(WidgetTester tester, TargetPlatform platform) async {
    sink = _KeySink();
    keyboard = ScreenKeyboard(sink, platform: platform);
    results = [];
    addTearDown(keyboard.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            final result = keyboard.handle(event);
            results.add(result);
            return result == ScreenKeyResult.ignored
                ? KeyEventResult.ignored
                : KeyEventResult.handled;
          },
          child: const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey key,
    String platform, {
    String? character,
  }) async {
    await tester.sendKeyDownEvent(
      key,
      platform: platform,
      character: character,
    );
    await tester.sendKeyUpEvent(key, platform: platform);
  }

  group('on a Mac', () {
    const mac = 'macos';

    testWidgets('a typed character is pressed and released', (tester) async {
      await pump(tester, TargetPlatform.macOS);

      await press(tester, LogicalKeyboardKey.keyA, mac, character: 'a');

      expect(sink.calls, ['d 61', 'u 61']);
      expect(results, [ScreenKeyResult.sent, ScreenKeyResult.sent]);
    });

    testWidgets('shift goes to the screen and the character it makes with '
        'it', (tester) async {
      await pump(tester, TargetPlatform.macOS);

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.shiftLeft,
        platform: mac,
      );
      await press(tester, LogicalKeyboardKey.keyA, mac, character: 'A');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft, platform: mac);

      expect(sink.calls, ['d $_shift', 'd 41', 'u 41', 'u $_shift']);
    });

    testWidgets('Escape goes to the screen', (tester) async {
      await pump(tester, TargetPlatform.macOS);

      await press(tester, LogicalKeyboardKey.escape, mac);

      expect(sink.calls, ['d ff1b', 'u ff1b']);
    });

    testWidgets('Command alone sends nothing', (tester) async {
      await pump(tester, TargetPlatform.macOS);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: mac);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: mac);

      expect(sink.calls, isEmpty);
    });

    testWidgets('Command+A reaches the screen as Control+A', (tester) async {
      await pump(tester, TargetPlatform.macOS);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: mac);
      await press(tester, LogicalKeyboardKey.keyA, mac, character: 'a');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: mac);

      expect(sink.calls, ['d $_control', 'd 61', 'u 61', 'u $_control']);
    });

    testWidgets('Command+V is Paste and sends nothing', (tester) async {
      await pump(tester, TargetPlatform.macOS);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: mac);
      await press(tester, LogicalKeyboardKey.keyV, mac, character: 'v');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: mac);

      expect(sink.calls, isEmpty);
      expect(results, contains(ScreenKeyResult.paste));
    });

    testWidgets('holding Command+V does not paste again', (tester) async {
      await pump(tester, TargetPlatform.macOS);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: mac);
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyV,
        platform: mac,
        character: 'v',
      );
      await tester.sendKeyRepeatEvent(
        LogicalKeyboardKey.keyV,
        platform: mac,
        character: 'v',
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV, platform: mac);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: mac);

      expect(results.where((r) => r == ScreenKeyResult.paste), hasLength(1));
      expect(results, contains(ScreenKeyResult.consumed));
    });

    testWidgets('Command+Q, W, H, M and Tab stay with the app and the '
        'system', (tester) async {
      await pump(tester, TargetPlatform.macOS);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: mac);
      for (final key in [
        LogicalKeyboardKey.keyQ,
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyH,
        LogicalKeyboardKey.keyM,
        LogicalKeyboardKey.tab,
      ]) {
        await tester.sendKeyDownEvent(key, platform: mac);
        await tester.sendKeyUpEvent(key, platform: mac);
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: mac);

      expect(sink.calls, isEmpty);
      expect(
        results.where((r) => r == ScreenKeyResult.ignored),
        hasLength(results.length),
      );
    });

    testWidgets('Command+Period closes the viewer', (tester) async {
      await pump(tester, TargetPlatform.macOS);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft, platform: mac);
      await press(tester, LogicalKeyboardKey.period, mac, character: '.');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: mac);

      expect(sink.calls, isEmpty);
      expect(results, contains(ScreenKeyResult.close));
    });

    testWidgets('F8 is an ordinary key', (tester) async {
      await pump(tester, TargetPlatform.macOS);

      await press(tester, LogicalKeyboardKey.f8, mac);

      expect(sink.calls, ['d ffc5', 'u ffc5']);
    });
  });

  group('on Windows and Linux', () {
    const windows = 'windows';

    testWidgets('Control+C reaches the screen as Control+C', (tester) async {
      await pump(tester, TargetPlatform.windows);

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.controlLeft,
        platform: windows,
      );
      await press(tester, LogicalKeyboardKey.keyC, windows, character: 'c');
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.controlLeft,
        platform: windows,
      );

      expect(sink.calls, ['d $_control', 'd 63', 'u 63', 'u $_control']);
    });

    testWidgets('Control+V is Paste', (tester) async {
      await pump(tester, TargetPlatform.windows);

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.controlLeft,
        platform: windows,
      );
      await press(tester, LogicalKeyboardKey.keyV, windows, character: 'v');
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.controlLeft,
        platform: windows,
      );

      expect(results, contains(ScreenKeyResult.paste));
      expect(sink.calls, ['d $_control', 'u $_control']);
    });

    testWidgets('F8 closes the viewer and goes nowhere', (tester) async {
      await pump(tester, TargetPlatform.linux);

      await press(tester, LogicalKeyboardKey.f8, 'linux');

      expect(results.first, ScreenKeyResult.close);
      expect(sink.calls, isEmpty);
    });

    testWidgets('Escape goes to the screen', (tester) async {
      await pump(tester, TargetPlatform.windows);

      await press(tester, LogicalKeyboardKey.escape, windows);

      expect(sink.calls, ['d ff1b', 'u ff1b']);
    });

    testWidgets('Alt+Tab and Alt+F4 stay with the system', (tester) async {
      await pump(tester, TargetPlatform.windows);

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.altLeft,
        platform: windows,
      );
      for (final key in [LogicalKeyboardKey.tab, LogicalKeyboardKey.f4]) {
        await tester.sendKeyDownEvent(key, platform: windows);
        await tester.sendKeyUpEvent(key, platform: windows);
      }
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.altLeft,
        platform: windows,
      );

      expect(sink.calls, ['d $_alt', 'u $_alt']);
    });

    testWidgets('a Super chord stays with the system', (tester) async {
      await pump(tester, TargetPlatform.linux);

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.metaLeft,
        platform: 'linux',
      );
      await press(tester, LogicalKeyboardKey.keyD, 'linux', character: 'd');
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.metaLeft,
        platform: 'linux',
      );

      expect(sink.calls, isEmpty);
    });
  });

  group('any platform', () {
    testWidgets('a repeating key is pressed again, released once', (
      tester,
    ) async {
      await pump(tester, TargetPlatform.windows);

      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.arrowLeft,
        platform: 'windows',
      );
      await tester.sendKeyRepeatEvent(
        LogicalKeyboardKey.arrowLeft,
        platform: 'windows',
      );
      await tester.sendKeyUpEvent(
        LogicalKeyboardKey.arrowLeft,
        platform: 'windows',
      );

      expect(sink.calls, ['d ff51', 'd ff51', 'u ff51']);
    });

    testWidgets('a key with no keysym is left alone', (tester) async {
      await pump(tester, TargetPlatform.windows);

      await press(tester, LogicalKeyboardKey.audioVolumeUp, 'windows');

      expect(sink.calls, isEmpty);
      expect(results.first, ScreenKeyResult.ignored);
    });

    testWidgets('releaseAll lets go of a key whose release never comes', (
      tester,
    ) async {
      await pump(tester, TargetPlatform.windows);
      await tester.sendKeyDownEvent(
        LogicalKeyboardKey.keyA,
        platform: 'windows',
        character: 'a',
      );
      sink.calls.clear();

      keyboard.releaseAll();
      keyboard.releaseAll();

      expect(sink.calls, ['u 61']);
    });

    testWidgets('a closed sink drops the key instead of throwing', (
      tester,
    ) async {
      await pump(tester, TargetPlatform.windows);
      sink.closed = true;

      await press(tester, LogicalKeyboardKey.keyA, 'windows', character: 'a');

      expect(tester.takeException(), isNull);
    });
  });

  group('the key bar and the on-screen keyboard', () {
    testWidgets('tap presses and releases a key', (tester) async {
      await pump(tester, TargetPlatform.android);

      keyboard.tap(ScreenKeys.escape);
      keyboard.tap(ScreenKeys.tab);

      expect(sink.calls, ['d ff1b', 'u ff1b', 'd ff09', 'u ff09']);
    });

    testWidgets('a latched Control holds for the next key only', (
      tester,
    ) async {
      await pump(tester, TargetPlatform.android);
      keyboard.ctrl.value = true;

      keyboard.tap(0x63);
      keyboard.tap(0x63);

      expect(sink.calls, [
        'd $_control',
        'd 63',
        'u 63',
        'u $_control',
        'd 63',
        'u 63',
      ]);
      expect(keyboard.ctrl.value, isFalse);
    });

    testWidgets('Control and Alt latch together, and release in reverse', (
      tester,
    ) async {
      await pump(tester, TargetPlatform.android);
      keyboard.ctrl.value = true;
      keyboard.alt.value = true;

      keyboard.tap(ScreenKeys.tab);

      expect(sink.calls, [
        'd $_control',
        'd $_alt',
        'd ff09',
        'u ff09',
        'u $_alt',
        'u $_control',
      ]);
    });

    testWidgets('typed text is one press and release per character, the '
        'latched Control on the first', (tester) async {
      await pump(tester, TargetPlatform.android);
      keyboard.ctrl.value = true;

      keyboard.typeText('a1');

      expect(sink.calls, [
        'd $_control',
        'd 61',
        'u 61',
        'u $_control',
        'd 31',
        'u 31',
      ]);
    });

    testWidgets('typed text outside ASCII goes as Unicode keysyms and a '
        'newline as Return', (tester) async {
      await pump(tester, TargetPlatform.android);

      keyboard.typeText('é\n€');

      expect(sink.calls, [
        'd e9',
        'u e9',
        'd ff0d',
        'u ff0d',
        'd 10020ac',
        'u 10020ac',
      ]);
    });

    testWidgets('a control character with no key is dropped', (tester) async {
      await pump(tester, TargetPlatform.android);

      keyboard.typeText('a\u0001b');

      expect(sink.calls, ['d 61', 'u 61', 'd 62', 'u 62']);
    });

    testWidgets('pressControl sends Control+key as the Paste chord', (
      tester,
    ) async {
      await pump(tester, TargetPlatform.android);

      keyboard.pressControl(0x76);

      expect(sink.calls, ['d $_control', 'd 76', 'u 76', 'u $_control']);
    });
  });
}
