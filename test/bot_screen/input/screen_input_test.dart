import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/input/screen_input.dart';
import 'package:hermes_app/src/bot_screen/input/screen_paste.dart';
import 'package:hermes_app/src/bot_screen/rfb/rfb_input_sink.dart';

class _Client implements RfbInputSink {
  final calls = <String>[];

  @override
  void key(int keysym, {required bool down}) =>
      calls.add('key ${keysym.toRadixString(16)} ${down ? 'd' : 'u'}');

  @override
  void cutText(String text) => calls.add('cut ${text.length}');

  @override
  void pointer(int x, int y, int buttonMask) =>
      calls.add('pointer $x,$y,$buttonMask');

  @override
  void scroll(int x, int y, {int dx = 0, int dy = 0}) =>
      calls.add('scroll $x,$y');
}

void main() {
  late _Client client;
  late int events;
  late ScreenInput input;

  void scenario(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      client = _Client();
      events = 0;
      input = ScreenInput(
        client,
        platform: TargetPlatform.macOS,
        readClipboard: () async => 'secret',
        onEvent: () => events++,
      );
      body(async);
    });
  }

  test('dispose lets go of a pointer button that is still down, where it '
      'was', () {
    scenario((async) {
      input.sink.pointer(10, 20, 1);
      input.sink.pointer(30, 40, 1);
      client.calls.clear();

      input.dispose();

      expect(client.calls, ['pointer 30,40,0']);
    });
  });

  test('dispose sends no pointer release when no button is down', () {
    scenario((async) {
      input.sink.pointer(10, 20, 1);
      input.sink.pointer(10, 20, 0);
      client.calls.clear();

      input.dispose();

      expect(client.calls, isEmpty);
    });
  });

  test('nothing is sent after dispose, and nothing is counted', () {
    scenario((async) {
      input.dispose();
      client.calls.clear();
      final counted = events;

      expect(() => input.sink.pointer(1, 2, 1), throwsStateError);
      expect(() => input.sink.key(0x61, down: true), throwsStateError);
      expect(() => input.sink.scroll(1, 2, dy: 1), throwsStateError);
      expect(() => input.sink.cutText('x'), throwsStateError);
      input.keyboard.typeText('abc');

      expect(client.calls, isEmpty);
      expect(events, counted);
    });
  });

  test('a paste that was reading the clipboard when the input was disposed '
      'sends nothing and never arms the clear', () {
    fakeAsync((async) {
      client = _Client();
      PasteOutcome? outcome;
      input = ScreenInput(
        client,
        platform: TargetPlatform.macOS,
        readClipboard: () async => 'secret',
        onEvent: () {},
      );
      input.paste.paste().then((value) => outcome = value);
      input.dispose();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));

      expect(outcome, PasteOutcome.closed);
      expect(client.calls, isEmpty);
    });
  });
}
