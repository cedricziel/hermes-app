import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../chat/gateway/gateway_connection.dart';
import '../wav.dart';
import 'call_agent.dart';
import 'call_phase.dart';
export 'call_phase.dart';
import 'call_bridge.dart';
import 'call_speech_stream.dart';
import 'voice_activity.dart';

/// Owns one outgoing call, independent of the foreground route. Audio capture
/// begins only on CallKit activation and stops on native end, auth/context loss,
/// interruption, failure or disposal. Epochs discard late STT/agent/TTS work.
class VoiceCall extends ChangeNotifier {
  VoiceCall({
    required this.bridge,
    required this.agent,
    required this.connect,
    required this.transcribe,
    required this.prepare,
    this.profile,
  });
  final CallBridge bridge;
  final CallAgent agent;
  final MixedSocketConnect connect;
  final Future<String> Function(Uint8List wav) transcribe;
  final Future<void> Function() prepare;
  final String? profile;
  final _vad = VoiceActivity();
  StreamSubscription<Map<String, Object?>>? _events;
  Timer? _clock;
  CallSpeechStream? _speech;
  Future<void> _interruption = Future.value();
  DateTime? _started;
  DateTime? _lastPCM;
  int _epoch = 0;
  bool _disposed = false;
  bool _active = false;
  bool _startedOnce = false;
  bool _waitingForInput = false;
  CallPhase phase = CallPhase.connecting;
  bool muted = false;
  bool speaker = false;
  String route = 'iPhone';
  String caption = '';
  String? error;
  Duration elapsed = Duration.zero;
  bool get ended => phase == CallPhase.ended || phase == CallPhase.failed;
  bool _current(int epoch) => !_disposed && !ended && epoch == _epoch;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (_startedOnce || _disposed) return;
    _startedOnce = true;
    final epoch = _epoch;
    try {
      await prepare().timeout(const Duration(seconds: 20));
      if (!_current(epoch)) return;
      _events = bridge.events.listen(
        _event,
        onError: (Object _) => unawaited(end('Call audio became unavailable.')),
      );
      await bridge.start(const Uuid().v4(), 'Hermes');
    } on CallPreparationException catch (failure) {
      if (_current(epoch)) await end(failure.message);
    } on Object {
      if (_current(epoch)) {
        await end(
          'Could not start the call. Check microphone access and your speech providers in Settings.',
        );
      }
    }
  }

  void _event(Map<String, Object?> event) {
    if (_disposed || ended) return;
    switch (event['type']) {
      case 'activated':
        if (_active) return;
        _active = true;
        _started = DateTime.now();
        _lastPCM = _started;
        phase = CallPhase.listening;
        unawaited(
          bridge.connected().catchError(
            (Object _) => end('Could not connect call audio.'),
          ),
        );
        _clock = Timer.periodic(const Duration(seconds: 1), (_) {
          elapsed = DateTime.now().difference(_started!);
          if (!muted &&
              DateTime.now().difference(_lastPCM!) >
                  const Duration(seconds: 15)) {
            unawaited(
              end('The microphone stopped. Start a new call to reconnect.'),
            );
          }
          _notify();
        });
      case 'pcm':
        _lastPCM = DateTime.now();
        if (_active && !muted) {
          if (event['data'] case final Uint8List pcm) _hear(pcm);
        }
      case 'audioReset':
        _epoch++;
        _vad.reset();
        final speech = _speech;
        _speech = null;
        _interruption = Future.wait<void>([
          if (speech != null) speech.stop(),
          agent.interrupt(),
        ]).then<void>((_) {}).catchError((Object _) {});
        phase = CallPhase.listening;
        _waitingForInput = false;
        caption = 'Audio route changed. Please repeat if needed.';
        _lastPCM = DateTime.now();
      case 'muted':
        muted = event['muted'] == true;
        _vad.reset();
        if (muted && phase == CallPhase.transcribing) {
          _epoch++;
          phase = CallPhase.listening;
        }
        _lastPCM = DateTime.now();
      case 'route':
        route = event['name'] as String? ?? 'iPhone';
        speaker = event['speaker'] == true;
      case 'ended':
        unawaited(end());
      case 'deactivated':
        unawaited(end('The call was interrupted.'));
      case 'error':
        unawaited(end('Call audio became unavailable.'));
    }
    _notify();
  }

  void _hear(Uint8List pcm) {
    final activity = _vad.add(pcm);
    if (activity.started) {
      final previous = phase;
      _epoch++;
      if (previous != CallPhase.listening) {
        final speech = _speech;
        _speech = null;
        _interruption = Future.wait<void>([
          if (speech != null) speech.stop(),
          agent.interrupt(),
        ]).then<void>((_) {}).catchError((Object _) {});
      }
      phase = CallPhase.listening;
      caption = '';
      _waitingForInput = false;
      _notify();
    }
    if (activity.utterance case final utterance?) {
      unawaited(_turn(utterance, _epoch));
    }
  }

  Future<void> _turn(Uint8List pcm, int epoch) async {
    phase = CallPhase.transcribing;
    _notify();
    CallSpeechStream? speech;
    try {
      await _interruption;
      if (!_current(epoch) || muted) return;
      final text = (await transcribe(
        wavFromPcm16(pcm, sampleRate: VoiceActivity.sampleRate),
      ).timeout(const Duration(seconds: 60))).trim();
      if (!_current(epoch) || muted) return;
      if (text.isEmpty) {
        phase = CallPhase.listening;
        _notify();
        return;
      }
      if (RegExp(
        r'^(?:hang up|end (?:the )?call)[.!?]?$',
        caseSensitive: false,
      ).hasMatch(text)) {
        await end();
        return;
      }
      caption = text;
      phase = CallPhase.thinking;
      _notify();
      speech = CallSpeechStream(
        connect: connect,
        output: bridge,
        onAudio: () {
          if (_current(epoch) && !_waitingForInput) {
            phase = CallPhase.speaking;
            _notify();
          }
        },
        onFailure: () {
          if (_current(epoch)) {
            unawaited(
              end(
                'Hermes could not speak this reply. Check your speech provider and reconnect.',
              ),
            );
          }
        },
      );
      _speech = speech;
      await speech.open(profile);
      if (!_current(epoch)) return;
      await agent.reply(
        text,
        onText: (part) {
          if (_current(epoch)) speech!.append(part);
        },
        onAttention: (waiting) {
          if (!_current(epoch)) return;
          if (waiting && !_waitingForInput) {
            speech!.append(
              'Please open the chat to answer Hermes before we continue.',
            );
          }
          _waitingForInput = waiting;
          if (waiting) {
            phase = CallPhase.attention;
          } else if (phase == CallPhase.attention) {
            phase = CallPhase.thinking;
          }
          _notify();
        },
      );
      if (!_current(epoch)) return;
      // A tool-only turn may have nothing to read. Keep it conversational.
      if (!speech.hasText) {
        speech.append('I have finished. You can see the details in the chat.');
      }
      await speech.finish();
      if (!_current(epoch)) return;
      _speech = null;
      phase = CallPhase.listening;
      _notify();
    } on Object {
      if (_current(epoch)) {
        await end(
          'The conversation was interrupted. Your messages are saved in the chat.',
        );
      }
    } finally {
      if (!_current(epoch) && speech != null) {
        // Never let a stale turn stop a newer turn's native speaker.
        await speech.close().catchError((Object _) {});
      }
    }
  }

  Future<void> setMuted(bool value) async {
    try {
      await bridge.mute(value);
    } on Object {
      if (!ended) await end('Could not change microphone mute.');
    }
  }

  Future<void> setSpeaker(bool value) async {
    try {
      await bridge.speaker(value);
    } on Object {
      /* The current route remains selected by iOS. */
    }
  }

  Future<void> end([String? failure]) async {
    if (ended) return;
    phase = failure == null ? CallPhase.ended : CallPhase.failed;
    error = failure;
    _active = false;
    _epoch++;
    _vad.reset();
    _clock?.cancel();
    final speech = _speech;
    _speech = null;
    _notify();
    // Release native audio before waiting for any remote cancellation.
    await bridge.end().catchError((Object _) {});
    await _events?.cancel().catchError((Object _) {});
    _events = null;
    await Future.wait<void>([
      if (speech != null) speech.stop().catchError((Object _) {}),
      agent.interrupt().catchError((Object _) {}),
    ]);
  }

  @override
  void dispose() {
    if (_disposed) return;
    unawaited(end());
    _disposed = true;
    agent.dispose();
    super.dispose();
  }
}

/// Actionable, fixed application text for preflight failures.
class CallPreparationException implements Exception {
  const CallPreparationException(this.message);
  final String message;
}
