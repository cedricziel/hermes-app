import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:uuid/uuid.dart';

import '../../chat/gateway/gateway_connection.dart';
import '../wav.dart';
import '../voice_audio_focus.dart';
import 'call_agent.dart';
import 'call_phase.dart';
export 'call_phase.dart';
import 'call_bridge.dart';
import 'call_config.dart';
import 'call_speech_stream.dart';
import 'call_telemetry.dart';
import 'voice_activity.dart';
import 'whisper_hallucination.dart';

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
    required this.consented,
    this.profile,
    this.speechFallback,
    this.loadConfig,
    this.echoGuard,
    this.events = noopAppEventLogger,
  });
  final CallBridge bridge;
  final CallAgent agent;
  final MixedSocketConnect connect;
  final Future<String> Function(Uint8List wav) transcribe;
  final Future<void> Function() prepare;
  final String? profile;
  final CallSpeechFallback? speechFallback;

  /// Whether the user allowed automatic sending for this call. Without it the
  /// call never opens capture.
  final bool consented;

  /// Reads the profile's voice config once, when the call starts. A failure
  /// leaves the defaults.
  final Future<VoiceCallConfig> Function()? loadConfig;

  /// Whether a transcript is the reply just spoken, heard back. It runs
  /// before the hallucination and stop-phrase checks; null drops nothing.
  final bool Function(String text)? echoGuard;

  /// Gets `voice_call.connected` when CallKit hands over the audio and one
  /// `voice_call.ended` (`outcome`, `reason`, `step`, `error_type`, buckets
  /// of turns and duration). Fixed words only: never speech, text or ids.
  final AppEventLogger events;
  VoiceActivity _vad = VoiceActivity();
  VoiceCallConfig _config = const VoiceCallConfig();
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
  bool _nativeStarted = false;
  bool _waitingForInput = false;
  bool _connectedOnce = false;
  bool _requestedMute = false;
  int _muteRequests = 0;
  int _transcriptionFailures = 0;
  int _turns = 0;
  int _fallbacks = 0;
  CallPhase phase = CallPhase.connecting;
  bool muted = false;
  bool speaker = false;
  String route = 'iPhone';
  String caption = '';
  String? error;

  /// What the screen explains, besides the state: a turn that could not be
  /// heard, or speech that failed.
  CallNotice? notice;

  /// The fixed word that ended the call (the telemetry `reason`), once ended.
  String? endReason;

  /// What the profile configured for this call.
  VoiceCallConfig get config => _config;
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
    if (!consented) {
      await _end('prepare', 'Allow automatic sending to start a call.');
      return;
    }
    var step = 'prepare';
    try {
      await prepare().timeout(const Duration(seconds: 20));
      if (!_current(epoch)) return;
      step = 'config';
      if (loadConfig case final load?) {
        try {
          _config = await load().timeout(const Duration(seconds: 5));
        } on Object {
          // The app's own defaults stand in for a profile that cannot be read.
        }
        if (!_current(epoch)) return;
        _vad = VoiceActivity(silence: _config.silence);
      }
      step = 'audio_focus';
      await VoiceAudioFocus.shared.acquire(this);
      if (!_current(epoch)) return;
      _events = bridge.events.listen(
        _event,
        onError: (Object error) => unawaited(
          _end('native_events', 'Call audio became unavailable.', error),
        ),
      );
      _nativeStarted = true;
      step = 'native_start';
      await bridge.start(const Uuid().v4(), 'Hermes');
    } on CallPreparationException catch (failure) {
      if (_current(epoch)) await _end('prepare', failure.message);
    } on PlatformException catch (error) {
      if (!_current(epoch)) return;
      if (step == 'native_start' && error.code == 'start') {
        // Natively the failed start also sends an `error` event; both orders
        // must end the same way.
        await _end(
          'native_error',
          _nativeErrorText('start_request'),
          null,
          'start_request',
        );
      } else {
        await _end(step, _startFailureText, error);
      }
    } on Object catch (error) {
      if (_current(epoch)) {
        await _end(step, _startFailureText, error);
      }
    }
  }

  void _event(Map<String, Object?> event) {
    if (_disposed || ended) return;
    switch (event['type']) {
      case 'activated':
        if (_active) return;
        _active = true;
        _connectedOnce = true;
        _log('voice_call.connected');
        _started = DateTime.now();
        _lastPCM = _started;
        phase = CallPhase.listening;
        unawaited(
          bridge.connected().catchError(
            (Object error) =>
                _end('connect', 'Could not connect call audio.', error),
          ),
        );
        _clock = Timer.periodic(const Duration(seconds: 1), (_) {
          elapsed = DateTime.now().difference(_started!);
          if (!muted &&
              !_requestedMute &&
              DateTime.now().difference(_lastPCM!) >
                  const Duration(seconds: 15)) {
            unawaited(
              _end(
                'microphone_stalled',
                'The microphone stopped. Start a new call to reconnect.',
              ),
            );
          }
          _notify();
        });
      case 'pcm':
        _lastPCM = DateTime.now();
        if (_active && !muted && !_requestedMute) {
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
        // A system mute is a request too; one this app is still making is
        // already counted.
        if (_muteRequests == 0) _requestedMute = muted;
        _vad.reset();
        if (_requestedMute && phase == CallPhase.sending) _dropTurn();
        _lastPCM = DateTime.now();
      case 'route':
        route = event['name'] as String? ?? 'iPhone';
        speaker = event['speaker'] == true;
      case 'ended':
        unawaited(_end('hang_up'));
      case 'deactivated':
        unawaited(_end('interrupted', 'The call was interrupted.'));
      case 'error':
        final step = callNativeErrorStep(event['code']);
        unawaited(
          _end(
            'native_error',
            _nativeErrorText(step),
            null,
            step,
            callNativeErrorType(event['callkit']),
          ),
        );
    }
    _notify();
  }

  void _hear(Uint8List pcm) {
    final activity = _vad.add(pcm);
    if (activity.started) {
      final previous = phase;
      notice = null;
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

  /// The turn is over for this call: nothing of it is sent and the call
  /// listens again.
  void _dropTurn() {
    _epoch++;
    _vad.reset();
    final speech = _speech;
    _speech = null;
    if (speech != null) unawaited(speech.close().catchError((Object _) {}));
    phase = CallPhase.listening;
    caption = '';
    _waitingForInput = false;
    _notify();
  }

  /// Whether the turn of [epoch] must not go on: the call moved on, or the
  /// user asked for mute, which counts before the bridge confirms it.
  bool _abandoned(int epoch) {
    if (!_current(epoch)) return true;
    if (!_requestedMute) return false;
    _dropTurn();
    return true;
  }

  Future<void> _transcriptionFailed(Object error) async {
    _transcriptionFailures++;
    if (_transcriptionFailures >= 2) {
      await _end(
        'transcription',
        "Couldn't hear that. Nothing was sent.",
        error,
        'transcribe',
        null,
        CallNotice.transcription,
      );
      return;
    }
    notice = CallNotice.transcription;
    phase = CallPhase.listening;
    _notify();
  }

  Future<void> _turn(Uint8List pcm, int epoch) async {
    if (_abandoned(epoch)) return;
    phase = CallPhase.sending;
    _notify();
    CallSpeechStream? speech;
    var step = 'transcribe';
    try {
      await _interruption;
      if (_abandoned(epoch)) return;
      final String text;
      try {
        text = (await transcribe(
          wavFromPcm16(pcm, sampleRate: VoiceActivity.sampleRate),
        ).timeout(const Duration(seconds: 60))).trim();
      } on Object catch (error) {
        if (!_abandoned(epoch)) await _transcriptionFailed(error);
        return;
      }
      if (_abandoned(epoch)) return;
      _transcriptionFailures = 0;
      // One order, the first match decides: empty, echo, hallucination, stop
      // phrase, else sent. A dropped transcript says nothing.
      if (text.isEmpty ||
          (echoGuard?.call(text) ?? false) ||
          isWhisperHallucination(text)) {
        phase = CallPhase.listening;
        _notify();
        return;
      }
      if (_config.isStopPhrase(text)) {
        await _end('stop_phrase');
        return;
      }
      notice = null;
      caption = text;
      _notify();
      step = 'speech_open';
      speech = CallSpeechStream(
        connect: connect,
        output: bridge,
        fallback: speechFallback,
        onAudio: () {
          if (_current(epoch) && !_waitingForInput) {
            phase = CallPhase.speaking;
            _notify();
          }
        },
        onFailure: (error) {
          if (_current(epoch)) {
            unawaited(
              _end(
                'speech',
                _speechFailedText,
                error,
                speech?.usedFallback == true ? 'speech_fallback' : step,
                null,
                CallNotice.speechFailed,
              ),
            );
          }
        },
      );
      _speech = speech;
      await speech.open(profile);
      // Nothing between this check and the send may await.
      if (_abandoned(epoch)) return;
      step = 'agent';
      await agent.reply(
        text,
        onSubmitted: () {
          if (_current(epoch) && phase == CallPhase.sending) {
            phase = CallPhase.thinking;
            _notify();
          }
        },
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
      step = 'speech';
      await speech.finish();
      if (speech.usedFallback) _fallbacks++;
      if (!_current(epoch)) return;
      _turns++;
      _speech = null;
      phase = CallPhase.listening;
      _notify();
    } on Object catch (error) {
      if (_current(epoch)) {
        await _end(
          'turn',
          'The conversation was interrupted. Your messages are saved in the chat.',
          error,
          speech?.usedFallback == true && step == 'speech'
              ? 'speech_fallback'
              : step,
        );
      }
    } finally {
      if (!_current(epoch) && speech != null) {
        // Never let a stale turn stop a newer turn's native speaker.
        await speech.close().catchError((Object _) {});
      }
    }
  }

  /// Mute counts at once: [_requestedMute] is set before the bridge answers,
  /// so a turn still being prepared is dropped and nothing is sent.
  Future<void> setMuted(bool value) async {
    if (ended) return;
    _requestedMute = value;
    _muteRequests++;
    if (value) {
      _vad.reset();
      if (phase == CallPhase.sending) _dropTurn();
    }
    try {
      await bridge.mute(value);
    } on Object catch (error) {
      if (!ended) {
        await _end('mute', 'Could not change microphone mute.', error);
      }
    } finally {
      _muteRequests--;
    }
  }

  Future<void> setSpeaker(bool value) async {
    try {
      await bridge.speaker(value);
    } on Object {
      /* The current route remains selected by iOS. */
    }
  }

  /// Ends the call; the app's own end (a changed chat, sign-out, the end
  /// button). A [failure] is the text shown to the user.
  Future<void> end([String? failure]) =>
      _end(failure == null ? 'app' : 'app_failure', failure);

  Future<void> _end(
    String reason, [
    String? failure,
    Object? cause,
    String? step,
    String? errorType,
    CallNotice? notice,
  ]) async {
    if (ended) return;
    endReason = reason;
    this.notice = notice;
    _log('voice_call.ended', {
      'outcome': failure == null ? 'ended' : 'failed',
      'reason': reason,
      'step': ?step,
      'error_type':
          ?(errorType ?? (cause == null ? null : callErrorKind(cause))),
      'connected': _connectedOnce,
      'turns': callTurnsBucket(_turns),
      'speech_fallbacks': callTurnsBucket(_fallbacks),
      'duration': callDurationBucket(
        _started == null ? null : DateTime.now().difference(_started!),
      ),
    });
    phase = failure == null ? CallPhase.ended : CallPhase.failed;
    error = failure;
    _active = false;
    _epoch++;
    _vad.reset();
    _clock?.cancel();
    final speech = _speech;
    _speech = null;
    _notify();
    final stopSpeech = speech?.stop().catchError((Object _) {});
    // Release native audio before waiting for any remote cancellation.
    if (_nativeStarted) await bridge.end().catchError((Object _) {});
    await _events?.cancel().catchError((Object _) {});
    _events = null;
    VoiceAudioFocus.shared.release(this);
    await Future.wait<void>([
      ?stopSpeech,
      agent.interrupt().catchError((Object _) {}),
    ]);
  }

  void _log(String name, [Map<String, Object> attributes = const {}]) {
    try {
      events(name, attributes);
    } on Object {
      // Telemetry must never break the app.
    }
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

const _speechFailedText =
    'Hermes could not speak this reply. Check your speech provider on the server. The reply is in the chat.';

const _startFailureText =
    'Could not start the call. Check microphone access and your speech providers in Settings.';

String _nativeErrorText(String step) => switch (step) {
  'start_request' || 'start_action' => 'iOS could not start the call. Try again, and restart your iPhone if it keeps happening.',
  'activation_timeout' => 'Call audio did not become available. Try again.',
  _ => 'Call audio became unavailable.',
};

/// Actionable, fixed application text for preflight failures.
class CallPreparationException implements Exception {
  const CallPreparationException(this.message);
  final String message;
}
