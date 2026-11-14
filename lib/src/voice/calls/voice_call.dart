import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
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
import 'call_tones.dart';
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
    this.tones,
    this.haptics,
    this.releaseLease,
    this.deviceSpeech = false,
    TargetPlatform? platform,
    DateTime Function()? now,
    this.events = noopAppEventLogger,
  }) : _platform = platform ?? defaultTargetPlatform,
       _now = now ?? DateTime.now {
    _attentionThread = agent.attention;
    agent.watchAttention((waiting) {
      _attentionThread = waiting;
      _attentionChanged();
    });
  }
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

  /// The call's three sounds and its haptics. Null is silence.
  final CallTones? tones;
  final CallHaptics? haptics;

  /// Releases the `tts-lease` when the call holds one, as a teardown step.
  final Future<void> Function()? releaseLease;

  /// Whether the device's own recognizer transcribes the turns, for the
  /// `voice_call.turn` event.
  final bool deviceSpeech;
  final TargetPlatform _platform;
  final DateTime Function() _now;

  /// Gets `voice_call.connected` when CallKit hands over the audio and one
  /// `voice_call.ended` (`outcome`, `reason`, `step`, `error_type`, buckets
  /// of turns, retries and duration), plus one `voice_call.turn` per reply
  /// with its latency buckets. Fixed words only: never speech, text or ids.
  final AppEventLogger events;
  VoiceActivity _vad = VoiceActivity();
  VoiceCallConfig _config = const VoiceCallConfig();
  StreamSubscription<Map<String, Object?>>? _events;
  Timer? _clock;
  CallSpeechStream? _speech;
  Future<void> _interruption = Future.value();
  DateTime? _started;
  DateTime? _lastPCM;
  DateTime? _lastActivity;
  int _epoch = 0;
  bool _ending = false;
  Future<void>? _endFuture;
  bool _lateClosed = false;
  bool _attentionThread = false, _attentionReply = false, _wasWaiting = false;
  int _attentionReplyBy = -1;

  /// Capture paused by this call (Waiting for you, a tone) and what the
  /// bridge reports; either one means no microphone audio arrives.
  bool _paused = false, _bridgePaused = false, _bridgeOwnPause = false;
  int _tonesPlaying = 0;

  /// Replies of this call still running in the chat, and the epoch of the one
  /// whose speech is still current.
  int _running = 0;
  int? _replyEpoch;
  bool _disposed = false;
  bool _active = false;
  bool _startedOnce = false;
  bool _nativeStarted = false;

  /// The id given to the native call, so a late `stopCapture` of this call
  /// cannot close the microphone of the next one.
  String? _callId;
  bool _connectedOnce = false;
  bool _requestedMute = false;
  int _muteRequests = 0;
  int _transcriptionFailures = 0;
  int _turns = 0;
  int _fallbacks = 0;
  int _speechRetries = 0;
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

  /// Another call or app, or the system, took the audio.
  bool get interruptedEnd =>
      endReason == 'interrupted' || endReason == 'focus_lost';

  /// Whether the call ended without confirming that the microphone closed.
  bool microphoneUnconfirmed = false;

  /// Whether the thread waits for the user, whoever raised the request.
  bool get waitingForYou => _attentionThread || _attentionReply;

  /// Whether no microphone audio is taken right now, by this call's choice or
  /// the bridge's.
  bool get capturePaused => _paused || _bridgePaused;

  /// Whether the user asked for mute, which counts before the bridge confirms
  /// it. A control that toggles mute toggles this, so a second quick tap
  /// unmutes.
  bool get mutedRequested => _requestedMute;

  /// Whether the microphone is closed for longer than a tone: Waiting for you
  /// or the bridge's own pause (desktop playback). The strip says "paused"
  /// for these only; a tone's few hundred milliseconds stay "open".
  bool get capturePausedForLong => waitingForYou || _bridgeOwnPause;

  /// Whether the user can speak over the reply: the platform cancels echo and
  /// the profile did not turn `voice.barge_in` off.
  bool get bargeInActive => bridge.bargeIn && (_config.bargeIn ?? true);

  /// What the profile configured for this call.
  VoiceCallConfig get config => _config;
  Duration elapsed = Duration.zero;
  bool get ended => phase == CallPhase.ended || phase == CallPhase.failed;
  bool _current(int epoch) =>
      !_disposed && !ended && !_ending && epoch == _epoch;
  CallPhase get _idlePhase =>
      waitingForYou ? CallPhase.attention : CallPhase.listening;
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
    var opened = false;
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
      final callId = _callId = const Uuid().v4();
      _nativeStarted = true;
      step = 'native_start';
      await bridge.start(callId, 'Hermes');
      opened = true;
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
    } finally {
      // A start that resolves after the call ended may have opened capture
      // behind the teardown's back.
      if (opened && !_current(epoch)) unawaited(_closeLate());
    }
  }

  Future<void> _closeLate() async {
    if (_lateClosed || !_ending && !ended && !_disposed) return;
    _lateClosed = true;
    await _endFuture;
    await _step(_stopCapture);
  }

  Future<void> _stopCapture() => bridge.stopCapture(_callId ?? '');

  /// One teardown step: at most two seconds, a throw counts as a miss, and
  /// neither stops the steps after it.
  Future<bool> _step(Future<void> Function() run) async {
    try {
      await run().timeout(const Duration(seconds: 2));
      return true;
    } on Object {
      return false;
    }
  }

  void _event(Map<String, Object?> event) {
    if (_disposed || ended || _ending) return;
    switch (event['type']) {
      case 'activated':
        if (_active) return;
        _active = true;
        _connectedOnce = true;
        _log('voice_call.connected');
        _started = _now();
        _lastPCM = _started;
        _lastActivity = _started;
        phase = CallPhase.listening;
        // Natively `start` clears a pause that arrived before it ran, and
        // `_syncCapture` sends nothing when the want has not changed.
        if (_paused) unawaited(_guard(bridge.pauseCapture));
        if (waitingForYou) {
          _wasWaiting = true;
          phase = CallPhase.attention;
          _syncCapture();
        }
        unawaited(
          bridge.connected().catchError(
            (Object error) =>
                _end('connect', 'Could not connect call audio.', error),
          ),
        );
        unawaited(_tone(CallTone.listening));
        _clock = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      case 'pcm':
        _lastPCM = _now();
        if (_active && !muted && !_requestedMute) {
          if (event['data'] case final Uint8List pcm) _hear(pcm);
        }
      case 'capturePaused':
        _bridgePaused = event['paused'] == true;
        // The echo of this call's own request is not the bridge's choice.
        _bridgeOwnPause = _bridgePaused && event['reason'] != 'request';
        _vad.reset();
        _lastPCM = _now();
      case 'audioReset':
        // The route changed: what was being heard and spoken is dropped. The
        // reply keeps running in the chat, and so does a pending approval.
        _epoch++;
        _vad.reset();
        _stopSpeech();
        // A reply of an earlier turn that is still going has been sent.
        final submitted = _running > 0;
        phase = _idlePhase;
        caption = '';
        notice = submitted
            ? CallNotice.routeChangedNeutral
            : CallNotice.routeChanged;
        _lastPCM = _now();
        // The native reset reopened capture; Waiting for you needs it closed.
        _bridgePaused = false;
        _bridgeOwnPause = false;
        if (_paused) unawaited(_guard(bridge.pauseCapture));
      case 'muted':
        muted = event['muted'] == true;
        // A system mute is a request too; one this app is still making is
        // already counted.
        if (_muteRequests == 0) _requestedMute = muted;
        _vad.reset();
        if (_requestedMute && phase == CallPhase.sending) _dropTurn();
        _lastPCM = _now();
      case 'route':
        route = event['name'] as String? ?? 'iPhone';
        speaker = event['speaker'] == true;
      case 'ended':
        unawaited(_end('hang_up'));
      case 'deactivated':
        unawaited(
          _end(
            event['reason'] == 'focus' ? 'focus_lost' : 'interrupted',
            'The call was interrupted.',
          ),
        );
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

  Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } on Object {
      // A pause or resume that failed is seen as a stalled microphone.
    }
  }

  /// Runs once a second while the call is active.
  @visibleForTesting
  void tick() => _tick();

  void _tick() {
    final started = _started;
    if (started == null || ended || _ending) return;
    final now = _now();
    elapsed = now.difference(started);
    // Capture closed or paused by design is not a stall: a mute, a pause, and
    // the phases where the profile or platform has no barge-in.
    final closedByDesign =
        muted ||
        _requestedMute ||
        capturePaused ||
        (!bargeInActive && phase != CallPhase.listening);
    if (closedByDesign) {
      _lastPCM = now;
    } else if (now.difference(_lastPCM!) > const Duration(seconds: 15)) {
      unawaited(
        _end(
          'microphone_stalled',
          'The microphone stopped. Start a new call to reconnect.',
        ),
      );
      return;
    }
    if (phase != CallPhase.listening || _running > 0 || waitingForYou) {
      _lastActivity = now;
    } else if (now.difference(_lastActivity ?? now) >= callIdleLimit) {
      unawaited(_end('idle', null, null, null, null, CallNotice.idle));
      return;
    }
    _notify();
  }

  /// The app went to the background. iOS keeps the call (CallKit holds the
  /// audio); everywhere else it ends, so a hidden app never keeps listening.
  void lifecycleChanged(AppLifecycleState state) {
    if (_platform == TargetPlatform.iOS || ended || _ending) return;
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_end('background', null, null, null, null, CallNotice.left));
    }
  }

  /// Hermes' own voice mode stopped the turn (wired with the voice turn
  /// flags): the call ends.
  Future<void> voiceStopped() => _end('voice_stopped');

  /// Pauses or resumes capture to match what the call wants: closed while it
  /// waits for the user or plays a tone. Pausing drops what was half heard.
  void _syncCapture() {
    final want = waitingForYou || _tonesPlaying > 0;
    if (want == _paused || ended || _ending) return;
    _paused = want;
    if (want) _vad.reset();
    _lastPCM = _now();
    unawaited(_guard(want ? bridge.pauseCapture : bridge.resumeCapture));
  }

  Future<void> _tone(CallTone tone) async {
    final tones = this.tones;
    if (tones == null || ended || _ending) return;
    _tonesPlaying++;
    _syncCapture();
    try {
      await tones.play(tone).timeout(const Duration(seconds: 2));
    } on Object {
      // A tone that cannot play is not worth a call.
    } finally {
      _tonesPlaying--;
      _syncCapture();
    }
  }

  void _attentionChanged() {
    if (_disposed || ended || _ending) return;
    final waiting = waitingForYou;
    if (waiting == _wasWaiting) return;
    _wasWaiting = waiting;
    _lastActivity = _now();
    if (_active) {
      if (waiting) {
        if (phase == CallPhase.sending) _dropTurn();
        if (phase == CallPhase.thinking || phase == CallPhase.speaking) {
          // Spoken by the server's voice, which Hermes picks per profile: the
          // words are sent as text, so they cannot follow the app's language.
          _speech?.append(
            'Please open the chat to answer Hermes before we continue.',
          );
        }
        phase = CallPhase.attention;
      } else if (phase == CallPhase.attention) {
        phase = _replyEpoch == _epoch
            ? CallPhase.thinking
            : CallPhase.listening;
      }
    }
    _syncCapture();
    _notify();
  }

  /// Stops the speech socket and playback, and keeps the future so a turn
  /// waits for it.
  void _stopSpeech() {
    final speech = _speech;
    _speech = null;
    if (speech != null) _after(speech.stop());
  }

  void _after(Future<void> work) {
    final before = _interruption;
    _interruption = Future.wait<void>([before, work.catchError((Object _) {})])
        .then<void>((_) {});
  }

  void _hear(Uint8List pcm) {
    // Waiting for you and tones close the microphone; where there is no
    // barge-in, so does everything but Listening.
    if (capturePaused || waitingForYou) return;
    if (!bargeInActive && phase != CallPhase.listening) return;
    final activity = _vad.add(pcm);
    if (activity.started) {
      _lastActivity = _now();
      notice = null;
      _epoch++;
      // Speaking over the reply stops the voice. The reply itself goes on in
      // the chat until a real turn is about to be sent.
      _stopSpeech();
      phase = CallPhase.listening;
      caption = '';
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
    phase = _idlePhase;
    caption = '';
    _notify();
  }

  /// Whether the turn of [epoch] must not go on: the call moved on, the user
  /// asked for mute (which counts before the bridge confirms it), or Hermes
  /// waits for an answer.
  bool _abandoned(int epoch) {
    if (!_current(epoch)) return true;
    if (!_requestedMute && !waitingForYou) return false;
    _dropTurn();
    return true;
  }

  /// Stops what this call's earlier reply still does in the chat, so the next
  /// turn is not refused as "still answering". At most eight seconds.
  ///
  /// With an [epoch] (a turn about to be sent) it checks again after waiting
  /// for the playback to stop: an approval or a mute that came meanwhile
  /// interrupts nothing.
  Future<void> _settleReply([int? epoch]) async {
    await _interruption;
    if (epoch != null && _abandoned(epoch)) return;
    if (_running == 0) return;
    try {
      await agent.interrupt().timeout(const Duration(seconds: 8));
    } on Object {
      // A reply that will not stop is left to the chat's own refusal.
    }
  }

  /// The orb tap: stops the voice and the reply that is running, then listens.
  Future<void> interruptReply() async {
    if (phase != CallPhase.speaking || _ending || ended) return;
    _epoch++;
    _vad.reset();
    _stopSpeech();
    _after(_settleReply());
    phase = CallPhase.listening;
    caption = '';
    _notify();
    await _interruption;
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
    phase = _idlePhase;
    _notify();
  }

  Future<void> _turn(Uint8List pcm, int epoch) async {
    if (_abandoned(epoch)) return;
    phase = CallPhase.sending;
    _notify();
    CallSpeechStream? speech;
    var step = 'transcribe';
    var replying = false;
    var outcome = 'interrupted';
    DateTime? submitted, firstText, firstAudio, replyDone;
    Duration? transcription, speechOpen;
    try {
      final String text;
      final heard = _now();
      try {
        text = (await transcribe(
          wavFromPcm16(pcm, sampleRate: VoiceActivity.sampleRate),
        ).timeout(const Duration(seconds: 60))).trim();
      } on Object catch (error) {
        if (!_abandoned(epoch)) await _transcriptionFailed(error);
        return;
      }
      transcription = _now().difference(heard);
      if (_abandoned(epoch)) return;
      _transcriptionFailures = 0;
      // One order, the first match decides: empty, echo, hallucination, stop
      // phrase, else sent. A dropped transcript says nothing, and the reply
      // that may still be running is left alone.
      if (text.isEmpty ||
          (echoGuard?.call(text) ?? false) ||
          isWhisperHallucination(text)) {
        phase = _idlePhase;
        _notify();
        return;
      }
      if (_config.isStopPhrase(text)) {
        await _end('stop_phrase');
        return;
      }
      // A real turn is about to go out: only now does an earlier reply stop.
      // Waiting for you is re-checked before and after it.
      if (_abandoned(epoch)) return;
      notice = null;
      caption = text;
      _notify();
      step = 'interrupt';
      await _settleReply(epoch);
      if (_abandoned(epoch)) return;
      step = 'speech_open';
      speech = CallSpeechStream(
        connect: connect,
        output: bridge,
        fallback: speechFallback,
        onAudio: () {
          firstAudio ??= _now();
          if (_current(epoch) && !waitingForYou) {
            phase = CallPhase.speaking;
            _notify();
          }
        },
        onFailure: (error) {
          outcome = 'failed';
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
      final opening = _now();
      try {
        await speech.open(profile);
      } finally {
        speechOpen = _now().difference(opening);
        _speechRetries += speech.openRetries;
      }
      // Nothing between this check and the send may await.
      if (_abandoned(epoch)) return;
      step = 'agent';
      _running++;
      replying = true;
      _replyEpoch = epoch;
      submitted = _now();
      // Sending ends here: from this call on, End or mute can no longer
      // withdraw the words (that comes back with the queue restore and
      // `authorize`, task 5.0), so the screen stops promising a cancel.
      phase = CallPhase.thinking;
      _notify();
      await agent.reply(
        text,
        onSubmitted: () {
          if (_current(epoch) && !waitingForYou) {
            haptics?.submit();
            unawaited(_tone(CallTone.sent));
          }
        },
        onText: (part) {
          firstText ??= _now();
          if (_current(epoch)) speech!.append(part);
        },
        onAttention: (waiting) {
          _attentionReply = waiting;
          _attentionReplyBy = epoch;
          _attentionChanged();
        },
      );
      replyDone = _now();
      if (!_current(epoch)) return;
      // A tool-only turn may have nothing to read. Keep it conversational.
      if (!speech.hasText) {
        // Spoken by the server's voice, like the sentence above: kept English.
        speech.append('I have finished. You can see the details in the chat.');
      }
      step = 'speech';
      await speech.finish();
      if (speech.usedFallback) _fallbacks++;
      if (!_current(epoch)) return;
      _turns++;
      _speech = null;
      outcome = 'spoken';
      phase = _idlePhase;
      _notify();
    } on Object catch (error) {
      outcome = 'failed';
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
      if (replying) {
        Duration? since(DateTime? at) =>
            at == null || submitted == null ? null : at.difference(submitted);
        _log('voice_call.turn', {
          'transcription': callLatencyBucket(transcription),
          'speech_open': callLatencyBucket(speechOpen),
          'first_text': callLatencyBucket(since(firstText)),
          'first_audio': callLatencyBucket(since(firstAudio)),
          'reply_complete': callLatencyBucket(since(replyDone)),
          'device_speech': deviceSpeech,
          'fallback': speech?.usedFallback ?? false,
          'outcome': outcome,
        });
        _running--;
        if (_replyEpoch == epoch) _replyEpoch = null;
        if (_attentionReplyBy == epoch && _attentionReply) {
          _attentionReply = false;
          _attentionChanged();
        }
      }
      if (!_current(epoch) && speech != null) {
        // Never let a stale turn stop a newer turn's native speaker.
        await speech.close().catchError((Object _) {});
      }
    }
  }

  /// Mute counts at once: [_requestedMute] is set before the bridge answers,
  /// so a turn still being prepared is dropped and nothing is sent.
  Future<void> setMuted(bool value) async {
    if (ended || _ending) return;
    _requestedMute = value;
    _muteRequests++;
    _notify();
    if (value) {
      _vad.reset();
      if (phase == CallPhase.sending) _dropTurn();
    }
    try {
      await bridge.mute(value);
    } on Object catch (error) {
      if (!ended && !_ending) {
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

  /// Every exit runs this once, in this order, each step with its own two
  /// seconds and its own guard: capture closes first (before the state or any
  /// notice shows), then the speech socket and playback, the tone, the audio
  /// session and focus, the `tts-lease`, and last the agent.
  Future<void> _end(
    String reason, [
    String? failure,
    Object? cause,
    String? step,
    String? errorType,
    CallNotice? notice,
  ]) {
    if (_ending) return _endFuture ?? Future.value();
    _ending = true;
    return _endFuture = _runEnd(
      reason,
      failure,
      cause,
      step,
      errorType,
      notice,
    );
  }

  Future<void> _runEnd(
    String reason,
    String? failure,
    Object? cause,
    String? step,
    String? errorType,
    CallNotice? notice,
  ) async {
    endReason = reason;
    _active = false;
    _epoch++;
    _vad.reset();
    _clock?.cancel();
    final speech = _speech;
    _speech = null;
    final connected = _connectedOnce;
    final closed = !_nativeStarted || await _step(_stopCapture);
    microphoneUnconfirmed = !closed;
    this.notice = closed ? notice : CallNotice.microphoneMayBeOpen;
    _log('voice_call.ended', {
      'outcome': failure == null && closed ? 'ended' : 'failed',
      'reason': reason,
      'step': ?step,
      'error_type':
          ?(errorType ?? (cause == null ? null : callErrorKind(cause))),
      'connected': connected,
      'turns': callTurnsBucket(_turns),
      'speech_fallbacks': callTurnsBucket(_fallbacks),
      'speech_retries': callTurnsBucket(_speechRetries),
      'duration': callDurationBucket(
        _started == null ? null : _now().difference(_started!),
      ),
      if (!closed) 'capture': 'unconfirmed',
    });
    phase = failure == null && closed ? CallPhase.ended : CallPhase.failed;
    error = closed ? failure : _microphoneOpenText;
    _notify();
    if (speech != null) await _step(speech.close);
    if (_nativeStarted) await _step(bridge.stopPlayback);
    if (connected && _nativeStarted && _stopToneReasons.contains(reason)) {
      if (!_disposed) {
        haptics?.stop();
        if (tones case final tones?) {
          await _step(() => tones.play(CallTone.stop));
        }
      }
    }
    if (_nativeStarted) await _step(bridge.end);
    await _step(() async => await _events?.cancel());
    _events = null;
    VoiceAudioFocus.shared.release(this);
    if (releaseLease case final release?) await _step(release);
    await _step(agent.interrupt);
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

/// How long a call may go without speech and without a reply.
const callIdleLimit = Duration(minutes: 5);

const _stopToneReasons = {'app', 'stop_phrase', 'voice_stopped', 'idle'};

const _microphoneOpenText =
    'The call ended, but the microphone may still be open.';

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
