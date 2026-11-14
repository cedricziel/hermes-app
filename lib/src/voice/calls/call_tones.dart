import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'call_bridge.dart';

/// The three sounds of a call: rising when the microphone opens, a soft tick
/// when the words are sent, falling when the call stops. Speaking is the
/// voice itself.
enum CallTone { listening, sent, stop }

/// Plays [CallTone]s. [VoiceCall] pauses capture around [play], so the call
/// never hears its own tones.
abstract interface class CallTones {
  Future<void> play(CallTone tone);
}

/// A light tap when the words are sent and a medium one when the call stops.
abstract interface class CallHaptics {
  void submit();
  void stop();
}

const callToneSampleRate = 24000;

Duration callToneLength(CallTone tone) => switch (tone) {
  CallTone.listening || CallTone.stop => const Duration(milliseconds: 200),
  CallTone.sent => const Duration(milliseconds: 50),
};

/// The tone as s16le mono PCM at [callToneSampleRate]: two short glides with
/// a soft attack and decay, quiet enough not to startle.
Uint8List callTonePcm(CallTone tone) {
  final length =
      callToneLength(tone).inMilliseconds * callToneSampleRate ~/ 1000;
  final (from, to, peak) = switch (tone) {
    CallTone.listening => (440.0, 660.0, 0.22),
    CallTone.stop => (660.0, 440.0, 0.22),
    CallTone.sent => (1000.0, 1000.0, 0.14),
  };
  final bytes = ByteData(length * 2);
  var phase = 0.0;
  for (var i = 0; i < length; i++) {
    final t = i / length;
    final frequency = from + (to - from) * t;
    phase += 2 * math.pi * frequency / callToneSampleRate;
    // Attack over the first tenth, decay over the rest.
    final envelope = t < 0.1 ? t / 0.1 : math.pow(1 - (t - 0.1) / 0.9, 2);
    final sample = math.sin(phase) * peak * envelope;
    bytes.setInt16(i * 2, (sample * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

/// Plays tones through the call's own output, which shares the audio session
/// the call owns. Waits the tone's length rather than the bridge's drain, so
/// it never cancels the drain of speech that follows.
class BridgeCallTones implements CallTones {
  BridgeCallTones(this.bridge);
  final CallBridge bridge;

  @override
  Future<void> play(CallTone tone) async {
    await bridge.play(callTonePcm(tone), callToneSampleRate);
    await Future<void>.delayed(callToneLength(tone));
  }
}

/// [HapticFeedback] on iOS and Android; nothing elsewhere.
class SystemCallHaptics implements CallHaptics {
  SystemCallHaptics({TargetPlatform? platform})
    : _on = switch (platform ?? defaultTargetPlatform) {
        TargetPlatform.iOS || TargetPlatform.android => !kIsWeb,
        _ => false,
      };
  final bool _on;

  @override
  void submit() {
    if (_on) unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
  }

  @override
  void stop() {
    if (_on) unawaited(HapticFeedback.mediumImpact().catchError((Object _) {}));
  }
}
