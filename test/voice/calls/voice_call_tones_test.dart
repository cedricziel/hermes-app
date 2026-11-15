import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/voice/calls/call_tones.dart';
import 'package:hermes_app/src/voice/calls/voice_call.dart';
import 'package:hermes_app/src/voice/widgets/voice_call_view.dart';

import '../widgets/voice_call_widgets_support.dart';
import 'call_harness.dart';
import 'fakes.dart';

/// How often the waveform crosses zero in [from, to) of [pcm].
int _crossings(Uint8List pcm, double from, double to) {
  final samples = ByteData.sublistView(pcm);
  final count = pcm.length ~/ 2;
  var crossings = 0;
  for (var i = (count * from).floor() + 1; i < (count * to).floor(); i++) {
    final a = samples.getInt16((i - 1) * 2, Endian.little);
    final b = samples.getInt16(i * 2, Endian.little);
    if ((a < 0) != (b < 0)) crossings++;
  }
  return crossings;
}

void main() {
  group('generated tones', () {
    test('are s16le mono, short and quiet', () {
      for (final tone in CallTone.values) {
        final pcm = callTonePcm(tone);
        expect(pcm.length.isEven, isTrue);
        final samples = pcm.length ~/ 2;
        expect(
          samples * 1000 ~/ callToneSampleRate,
          callToneLength(tone).inMilliseconds,
        );
        final view = ByteData.sublistView(pcm);
        var peak = 0;
        for (var i = 0; i < samples; i++) {
          peak = peak < view.getInt16(i * 2, Endian.little).abs()
              ? view.getInt16(i * 2, Endian.little).abs()
              : peak;
        }
        expect(peak, inInclusiveRange(1000, 32767 ~/ 3), reason: '$tone');
      }
    });

    test('listening rises, stop falls, the tick is a single pitch', () {
      final rising = callTonePcm(CallTone.listening);
      expect(
        _crossings(rising, 0.5, 0.9),
        greaterThan(_crossings(rising, 0.0, 0.4)),
      );
      final falling = callTonePcm(CallTone.stop);
      expect(
        _crossings(falling, 0.5, 0.9),
        lessThan(_crossings(falling, 0.0, 0.4)),
      );
      expect(
        callToneLength(CallTone.sent),
        lessThan(callToneLength(CallTone.stop)),
      );
    });

    test('the bridge player plays them at the tone rate', () async {
      final bridge = FakeCallBridge();
      await BridgeCallTones(bridge).play(CallTone.sent);
      expect(bridge.played.single.$2, callToneSampleRate);
      expect(bridge.played.single.$1, callTonePcm(CallTone.sent));
    });
  });

  group('in a call', () {
    late CallHarness h;
    setUp(() => h = CallHarness());
    tearDown(() => h.dispose());

    test('a rising tone starts the call, played with capture paused', () async {
      await h.rebuild(withTones: true);
      await h.activate();
      expect(h.tones.played, [CallTone.listening]);
      final log = h.bridge.log;
      expect(log.sublist(log.indexOf('pauseCapture')), [
        'pauseCapture',
        'tone:listening',
        'resumeCapture',
      ]);
      expect(h.call.capturePaused, isFalse);
    });

    test('a tick and a light haptic mark the send', () async {
      await h.rebuild(withTones: true);
      await h.activate();
      h.bridge.log.clear();
      await h.say('Hello');
      expect(h.tones.played, [CallTone.listening, CallTone.sent]);
      expect(h.haptics.calls, ['submit']);
      expect(h.bridge.log, ['pauseCapture', 'tone:sent', 'resumeCapture']);
    });

    test('no tick or haptic while Waiting for you', () async {
      await h.rebuild(withTones: true);
      h.tones.gate = null;
      await h.activate();
      h.agent.holdSubmit = true;
      await h.say('Hello');
      h.agent.setThreadAttention(true);
      h.tones.played.clear();
      h.agent.submitted();
      await pumpEventQueue();
      expect(h.tones.played, isEmpty);
      expect(h.haptics.calls, isEmpty);
    });

    test('speech heard during a tone is not taken', () async {
      await h.rebuild(withTones: true);
      h.tones.gate = null;
      await h.activate();
      h.agent.holdSubmit = true;
      await h.say('Hello');
      // The tick has not been requested yet; hold the next tone open.
      h.tones.gate = Completer<void>();
      h.agent.submitted();
      await pumpEventQueue();
      expect(h.call.capturePaused, isTrue);
      final uploads = h.uploads;
      await h.say('Heard during the tone');
      expect(h.uploads, uploads);
      h.tones.gate!.complete();
      await pumpEventQueue();
      expect(h.call.capturePaused, isFalse);
    });

    test(
      'a falling tone and a medium haptic close a call the user ended',
      () async {
        await h.rebuild(withTones: true);
        await h.activate();
        h.bridge.log.clear();
        await h.call.end();
        expect(h.tones.played.last, CallTone.stop);
        expect(h.haptics.calls, ['stop']);
        expect(h.bridge.log, [
          'stopCapture',
          'stopPlayback',
          'tone:stop',
          'end',
          'interrupt',
        ]);
      },
    );

    test('no stop tone when the system ended the call', () async {
      await h.rebuild(withTones: true);
      await h.activate();
      h.bridge.emit('ended');
      await pumpEventQueue();
      expect(h.tones.played, [CallTone.listening]);
      expect(h.haptics.calls, isEmpty);
    });

    test('a call without tones or haptics is silent and works', () async {
      await h.activate();
      await h.say('Hello');
      expect(h.tones.played, isEmpty);
      expect(h.call.phase, CallPhase.thinking);
    });
  });

  group('announcements', () {
    testWidgets('the live region says the state word of each phase', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final words = {
          CallPhase.connecting: 'Connecting…',
          CallPhase.listening: 'Listening',
          CallPhase.sending: 'Sending',
          CallPhase.thinking: 'Thinking',
          CallPhase.speaking: 'Speaking',
          CallPhase.attention: 'Waiting for you',
          CallPhase.failed: 'Stopped',
        };
        for (final MapEntry(key: phase, value: word) in words.entries) {
          await pumpVoice(
            tester,
            VoiceCallView(
              phase: phase,
              elapsed: Duration.zero,
              muted: false,
              speaker: false,
              route: 'iPhone',
              onMute: () {},
              onSpeaker: () {},
              onEnd: () {},
              onShowChat: () {},
              stoppedWord: true,
            ),
          );
          final node = tester.getSemantics(find.text(word));
          expect(node.flagsCollection.isLiveRegion, isTrue, reason: '$phase');
          expect(node.label, word, reason: '$phase');
        }
      } finally {
        semantics.dispose();
      }
    });
  });
}
