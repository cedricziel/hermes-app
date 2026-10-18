import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/voice_activity.dart';

import 'fakes.dart';

void main() {
  test(
    'ignores a brief click; preserves onset and ends after a natural pause',
    () {
      final vad = VoiceActivity();
      for (var i = 0; i < 5; i++) {
        expect(vad.add(pcm(amplitude: 0)).utterance, isNull);
      }
      expect(vad.add(pcm(milliseconds: 50)).started, isFalse);
      expect(vad.add(pcm(amplitude: 0)).started, isFalse);
      expect(vad.add(pcm()).started, isTrue);
      for (var i = 0; i < 8; i++) {
        expect(vad.add(pcm(amplitude: 0)).utterance, isNull);
      }
      final recording = vad.add(pcm(amplitude: 0)).utterance!;
      expect(recording.length, greaterThanOrEqualTo(32000));
      expect(recording.length, lessThan(64000));
    },
  );
  test('bounds continuous speech at one minute', () {
    final vad = VoiceActivity();
    expect(vad.add(pcm()).started, isTrue);
    for (var i = 0; i < 598; i++) {
      expect(vad.add(pcm()).utterance, isNull);
    }
    expect(vad.add(pcm()).utterance!.length, 16000 * 2 * 60);
  });
  test('mute/reset discards the whole utterance', () {
    final vad = VoiceActivity();
    vad.add(pcm());
    vad.reset();
    for (var i = 0; i < 12; i++) {
      expect(vad.add(pcm(amplitude: 0)).utterance, isNull);
    }
  });
}
