import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/input/screen_keyboard.dart';
import 'package:hermes_app/src/bot_screen/input/screen_paste.dart';
import 'package:hermes_app/src/bot_screen/rfb/rfb_input_sink.dart';

/// Records what is sent in order, and refuses clipboard text the way the real
/// client does.
class _Sink implements RfbInputSink {
  final calls = <String>[];
  final cuts = <String>[];
  bool closed = false;

  @override
  void key(int keysym, {required bool down}) {
    if (closed) throw StateError('closed');
    calls.add('${down ? 'd' : 'u'} ${keysym.toRadixString(16)}');
  }

  @override
  void cutText(String text) {
    if (closed) throw StateError('closed');
    if (text.runes.any((r) => r > 0xff)) throw RfbClipboardError.notLatin1;
    if (text.length > maxCutTextBytes) throw RfbClipboardError.tooLarge;
    cuts.add(text);
    calls.add('cut ${text.length}');
  }

  @override
  void pointer(int x, int y, int buttonMask) => fail('no pointer');

  @override
  void scroll(int x, int y, {int dx = 0, int dy = 0}) => fail('no scroll');
}

void main() {
  late _Sink sink;
  late ScreenKeyboard keyboard;
  late ScreenPaste paste;
  String? clipboard;

  void scenario(void Function(FakeAsync async) body) {
    fakeAsync((async) {
      sink = _Sink();
      keyboard = ScreenKeyboard(sink, platform: TargetPlatform.macOS);
      clipboard = 'hunter2';
      paste = ScreenPaste(sink, keyboard, readClipboard: () async => clipboard);
      try {
        body(async);
      } finally {
        paste.dispose();
        keyboard.dispose();
        async.flushMicrotasks();
      }
    });
  }

  Future<PasteOutcome> run(FakeAsync async) {
    final outcome = paste.paste();
    async.flushMicrotasks();
    return outcome;
  }

  test('sends the text, presses Control+V, then clears the clipboard after '
      '500 milliseconds', () {
    scenario((async) {
      PasteOutcome? outcome;
      run(async).then((value) => outcome = value);
      async.flushMicrotasks();

      expect(sink.calls, ['cut 7', 'd ffe3', 'd 76', 'u 76', 'u ffe3']);
      expect(outcome, PasteOutcome.pasted);

      async.elapse(const Duration(milliseconds: 499));
      expect(sink.cuts, ['hunter2']);
      async.elapse(const Duration(milliseconds: 1));
      expect(sink.cuts, ['hunter2', '']);
    });
  });

  test('the clipboard is cleared once however often it was pasted', () {
    scenario((async) {
      run(async);
      async.elapse(const Duration(milliseconds: 300));
      run(async);

      async.elapse(const Duration(milliseconds: 499));
      expect(sink.cuts, ['hunter2', 'hunter2']);
      async.elapse(const Duration(milliseconds: 1));
      expect(sink.cuts, ['hunter2', 'hunter2', '']);
      async.elapse(const Duration(seconds: 5));
      expect(sink.cuts, hasLength(3));
    });
  });

  test('text outside Latin-1 is refused and nothing is sent', () {
    scenario((async) {
      clipboard = 'café \u{1F600}';
      PasteOutcome? outcome;
      run(async).then((value) => outcome = value);
      async.flushMicrotasks();

      expect(outcome, PasteOutcome.notLatin1);
      expect(sink.calls, isEmpty);
      async.elapse(const Duration(seconds: 5));
      expect(sink.calls, isEmpty);
    });
  });

  test('text over 256 KiB is refused and nothing is sent', () {
    scenario((async) {
      clipboard = 'a' * (maxCutTextBytes + 1);
      PasteOutcome? outcome;
      run(async).then((value) => outcome = value);
      async.flushMicrotasks();

      expect(outcome, PasteOutcome.tooLarge);
      expect(sink.calls, isEmpty);
    });
  });

  test('an empty or unreadable clipboard sends nothing', () {
    scenario((async) {
      for (final text in [null, '']) {
        clipboard = text;
        PasteOutcome? outcome;
        run(async).then((value) => outcome = value);
        async.flushMicrotasks();

        expect(outcome, PasteOutcome.empty);
      }
      expect(sink.calls, isEmpty);

      paste = ScreenPaste(
        sink,
        keyboard,
        readClipboard: () async => throw PlatformException(code: 'denied'),
      );
      PasteOutcome? outcome;
      paste.paste().then((value) => outcome = value);
      async.flushMicrotasks();
      expect(outcome, PasteOutcome.empty);
      expect(sink.calls, isEmpty);
    });
  });

  test('a closed stream drops the paste without throwing', () {
    scenario((async) {
      sink.closed = true;
      PasteOutcome? outcome;
      run(async).then((value) => outcome = value);
      async.flushMicrotasks();

      expect(outcome, PasteOutcome.closed);
      async.elapse(const Duration(seconds: 5));
    });
  });

  test('disposing before the delay clears the clipboard at once', () {
    scenario((async) {
      run(async);
      sink.calls.clear();

      paste.dispose();

      expect(sink.cuts, ['hunter2', '']);
      async.elapse(const Duration(seconds: 5));
      expect(sink.cuts, hasLength(2));
    });
  });

  test('disposing with nothing pending sends nothing', () {
    scenario((async) {
      paste.dispose();

      expect(sink.calls, isEmpty);
    });
  });
}
