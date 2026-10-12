import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../chat/gateway/gateway_connection.dart';
import '../chat/hermes_chat_repository.dart';
import '../telemetry/breadcrumbs.dart';
import 'dictation_settings.dart';
import 'live_transcriber.dart';
import 'on_device_speech.dart';
import 'transcribe_stream.dart';
import 'voice_recorder.dart';
import 'voice_support.dart';
import 'wav.dart';

/// Where a dictation is.
enum DictationPhase {
  idle,

  /// The microphone is open.
  recording,

  /// The recording ended and its transcript is on the way.
  settling,

  /// Transcribing failed; [DictationController.retry] tries the kept
  /// recording again.
  failed,

  /// The transcript came back empty.
  noSpeech,

  /// The app may not use the microphone.
  denied,

  /// The on-device engine's language model is no longer on the device.
  modelMissing,
}

/// A lease release retained for the session owner after controller disposal.
/// The owner must prove the original session is authorized before releasing.
class DictationLeaseCleanup {
  DictationLeaseCleanup._(
    this._repository,
    this.lease,
    this.profile,
    this._acquired,
  );

  final HermesChatRepository _repository;
  final String lease;
  final String? profile;
  final Future<void> _acquired;
  Future<bool>? _releasing;
  var _released = false;

  /// Waits for acquisition, then checks [authorized] before sending cleanup.
  /// False retains the cleanup for a later authorized attempt or retry.
  Future<bool> release({required bool Function() authorized}) {
    if (_released) return Future.value(true);
    return _releasing ??= _release(authorized)
        .whenComplete(() => _releasing = null);
  }

  Future<bool> _release(bool Function() authorized) async {
    await _acquired;
    if (!authorized()) return false;
    try {
      await _repository.holdSpeechToText(
        lease,
        active: false,
        profile: profile,
      );
      return _released = true;
    } on Object {
      return false;
    }
  }
}

/// Records one dictation at a time and turns it into text.
///
/// With [DictationEngine.hermes] that happens through the profile's server:
/// live over `/api/audio/transcribe-stream` when its provider can, else (or
/// when that fails) by uploading the recording to `POST /api/audio/transcribe`.
/// With [DictationEngine.device] the operating system's recognizer does it,
/// and nothing goes to the server. The transcript goes to [onTranscript]; the
/// composer sends it only when the user asks.
/// An optional activity signal cancels voice work while false; becoming
/// active never starts a recording.
class DictationController extends ChangeNotifier {
  DictationController({
    required this._repository,
    required this._connect,
    required this._recorder,
    required this.onTranscript,
    this._breadcrumbs = Breadcrumbs.none,
    this.maxDuration = const Duration(minutes: 5),
    OnDeviceSpeech? onDevice,
    String Function()? locale,
    this._activity,
  }) : _onDevice = onDevice ?? OnDeviceSpeech(),
       _locale = locale ?? OnDeviceSpeech.deviceLocale,
       _lease = 'app:voice-input:${_randomId()}' {
    _activity?.addListener(_activityChanged);
  }

  static const sampleRate = 16000;
  static const _tick = Duration(milliseconds: 100);

  /// How many ticks of levels [levels] keeps for the waveform.
  static const levelHistory = 40;

  final HermesChatRepository _repository;
  final MixedSocketConnect _connect;
  final VoiceRecorder _recorder;
  final Breadcrumbs _breadcrumbs;
  final OnDeviceSpeech _onDevice;
  final String Function() _locale;
  final String _lease;
  final ValueListenable<bool>? _activity;
  final ValueChanged<String> onTranscript;

  /// A recording stops by itself after this long.
  final Duration maxDuration;

  String? _profile;
  VoiceSupport _support = VoiceSupport.none;
  var _engine = DictationEngine.hermes;
  var _model = OnDeviceModel.unsupported;
  var _phase = DictationPhase.idle;
  var _level = 0.0;
  final _levels = <double>[];
  var _elapsed = Duration.zero;
  var _liveTranscript = '';
  var _run = 0;
  DictationLeaseCleanup? _leased;
  final _pendingLeaseCleanup = <DictationLeaseCleanup>[];
  Future<void>? _releasingLeases;
  LiveTranscriber? _stream;
  StreamSubscription<Uint8List>? _pcm;
  Completer<void>? _pcmDone;
  StreamSubscription<String>? _partials;
  Future<void>? _closing;
  Future<void>? _starting;
  Timer? _ticker;
  BytesBuilder? _clip;
  Uint8List? _keptClip;

  DictationPhase get phase => _phase;

  /// The input level, from 0 (silence) to 1, updated every tick.
  double get level => _level;

  /// The levels of the last [levelHistory] ticks, oldest first.
  List<double> get levels => List.unmodifiable(_levels);

  Duration get elapsed => _elapsed;

  /// The text recognized so far, while recording live; not yet final.
  String get liveTranscript => _liveTranscript;

  /// Who turns the speech into text.
  DictationEngine get engine => _engine;

  /// Whether dictation is offered for the current profile and engine.
  bool get available =>
      _active &&
      (_onTheDevice
          ? _model == OnDeviceModel.installed
          : _support.speechToText);

  bool get _active => !_disposed && (_activity?.value ?? true);

  bool get _credentialsActive => _activity?.value ?? true;

  bool _current(int run) => _active && run == _run;

  void _activityChanged() {
    if (!_active) {
      _support = VoiceSupport.none;
      _model = OnDeviceModel.unsupported;
      unawaited(cancel());
    } else {
      unawaited(_flushLeaseCleanup());
    }
    notifyListeners();
  }

  bool get _onTheDevice => _engine == DictationEngine.device;

  bool get canRetry => _phase == DictationPhase.failed && _keptClip != null;

  /// Points dictation at [profile] and [engine]; a recording for another
  /// profile or engine is dropped, with any recording kept for a retry.
  /// [model] is the on-device model's state for the device's language.
  void configure({
    String? profile,
    required VoiceSupport support,
    DictationEngine engine = DictationEngine.hermes,
    OnDeviceModel model = OnDeviceModel.unsupported,
  }) {
    if (!_active) return;
    if (profile != _profile || engine != _engine) unawaited(cancel());
    _profile = profile;
    _support = support;
    _engine = engine;
    _model = model;
    // The composer hides dictation while it is unavailable; a recording
    // left running would have no controls.
    if (busy && !available) unawaited(cancel());
    notifyListeners();
  }

  Future<void> start() {
    if (!_active || busy || _starting != null || _closing != null) {
      return Future.value();
    }
    return _starting = _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    final run = ++_run;
    _keptClip = null;
    if (!await _recorder.requestPermission()) {
      if (_current(run)) _end(DictationPhase.denied, 'denied');
      return;
    }
    if (!_current(run)) return;
    final LiveTranscriber? stream;
    if (_onTheDevice) {
      stream = await _startOnDevice(run);
      if (stream == null) return;
    } else {
      await _flushLeaseCleanup();
      if (!_current(run)) return;
      _acquireLease();
      stream = _support.liveTranscription
          ? TranscribeStream.start(
              connect: _connect,
              sampleRate: sampleRate,
              query: {'profile': ?_profile},
            )
          : null;
    }
    if (!_current(run)) {
      stream?.cancel();
      return;
    }
    _stream = stream;
    _partials = stream?.partials.listen((text) {
      if (!_current(run)) return;
      _liveTranscript = text;
      notifyListeners();
    });
    final Stream<Uint8List> pcm;
    try {
      pcm = await _recorder.start(sampleRate: sampleRate);
    } on Object {
      if (!_current(run)) return;
      _stream?.cancel();
      _stream = null;
      _end(DictationPhase.failed, 'failed');
      return;
    }
    final done = _pcmDone = Completer<void>();
    _pcm = pcm.listen(
      (chunk) {
        if (_current(run)) _onPcm(chunk);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );
    if (!_current(run)) {
      _discardPcm();
      await _closeMicrophone();
      return;
    }
    // The on-device engine has no retry, so it keeps no recording.
    _clip = _onTheDevice ? null : BytesBuilder(copy: false);
    _elapsed = Duration.zero;
    _level = 0;
    _levels.clear();
    _liveTranscript = '';
    _ticker = Timer.periodic(_tick, (_) {
      if (!_current(run)) return;
      _elapsed += _tick;
      _levels.add(_level);
      if (_levels.length > levelHistory) _levels.removeAt(0);
      notifyListeners();
      if (_elapsed >= maxDuration) unawaited(stop());
    });
    _breadcrumbs('voice.dictation.started', {'engine': _engine.name});
    _setPhase(DictationPhase.recording);
  }

  /// Whether a recording or its transcription is in progress.
  bool get busy =>
      _phase == DictationPhase.recording || _phase == DictationPhase.settling;

  /// Listeners hear of a new level on the next tick, not on every chunk.
  void _onPcm(Uint8List chunk) {
    _clip?.add(chunk);
    _stream?.add(chunk);
    _level = _levelOf(chunk);
  }

  /// Completes once no recording or transcription is in progress, or the
  /// controller is disposed; [lastOutcome] then says how it ended.
  Future<void> whenSettled() {
    if (!busy || _disposed) return Future.value();
    final settled = Completer<void>();
    _settledWaiters.add(settled);
    return settled.future;
  }

  final _settledWaiters = <Completer<void>>[];

  void _completeSettledWaiters() {
    for (final waiter in _settledWaiters) {
      waiter.complete();
    }
    _settledWaiters.clear();
  }

  /// How the last dictation ended, as its breadcrumb records it:
  /// `inserted`, `empty`, `cancelled`, `failed`, `denied` or
  /// `model_missing`; null before the first one ended.
  String? get lastOutcome => _lastOutcome;
  String? _lastOutcome;

  /// Ends the recording and inserts its transcript.
  Future<void> stop() async {
    if (!_active || _phase != DictationPhase.recording) return;
    final run = _run;
    _setPhase(DictationPhase.settling);
    await _closeMicrophone();
    if (!_current(run)) return;
    final clip = _clip?.takeBytes() ?? Uint8List(0);
    _clip = null;
    final live = await _stream?.finish();
    if (!_current(run)) return;
    _stream = null;
    if (_onTheDevice) {
      _settleOnDevice(live);
    } else if (live != null && live.isNotEmpty) {
      _settle(live, path: 'stream');
    } else {
      await _transcribeClip(clip, run);
    }
  }

  /// Opens a recognizer session; null when the dictation ended instead,
  /// which it does when the system removed the model since [configure].
  Future<OnDeviceSession?> _startOnDevice(int run) async {
    try {
      final session = await _onDevice.start(
        locale: _locale(),
        sampleRate: sampleRate,
      );
      if (_current(run)) return session;
      session.cancel();
    } on OnDeviceSpeechException catch (e) {
      if (!_current(run)) return null;
      if (e.code == 'modelMissing') {
        _end(DictationPhase.modelMissing, 'model_missing');
      } else {
        _end(DictationPhase.failed, 'failed', path: 'device');
      }
    }
    return null;
  }

  /// The on-device recognizer's [transcript], or its failure: there is no
  /// recording to retry or upload.
  void _settleOnDevice(String? transcript) => transcript == null
      ? _end(DictationPhase.failed, 'failed', path: 'device')
      : _settle(transcript, path: 'device');

  /// Tries the recording of a failed transcription again.
  Future<void> retry() async {
    if (!_active || !canRetry || _starting != null || _closing != null) return;
    final run = ++_run;
    _setPhase(DictationPhase.settling);
    await _transcribeClip(_keptClip!, run);
  }

  Future<void> _transcribeClip(Uint8List clip, int run) async {
    if (!_current(run)) return;
    final text = clip.isEmpty ? '' : await _upload(clip);
    if (!_current(run)) return;
    if (text == null) {
      _keptClip = clip;
      _end(DictationPhase.failed, 'failed', path: 'upload');
    } else {
      _settle(text, path: 'upload');
    }
  }

  void _settle(String text, {required String path}) {
    final run = _run;
    _keptClip = null;
    _liveTranscript = '';
    _end(
      text.isEmpty ? DictationPhase.noSpeech : DictationPhase.idle,
      text.isEmpty ? 'empty' : 'inserted',
      path: path,
    );
    if (!_current(run)) {
      _lastOutcome = 'cancelled';
      return;
    }
    if (text.isNotEmpty) onTranscript(text);
  }

  /// Uploads [clip] as WAV; the transcript, or null when that failed.
  Future<String?> _upload(Uint8List clip) async {
    try {
      return await _repository.transcribe(
        wavFromPcm16(clip, sampleRate: sampleRate),
        mimeType: 'audio/wav',
        profile: _profile,
        timeout: HermesChatRepository.transcribeTimeout(clip.length),
      );
    } on Object {
      return null;
    }
  }

  /// Drops the recording, or the transcript on its way.
  Future<void> cancel() async {
    final wasBusy = busy;
    final run = ++_run;
    unawaited(_partials?.cancel());
    _partials = null;
    _stream?.cancel();
    _stream = null;
    _clip = null;
    _keptClip = null;
    _liveTranscript = '';
    _releaseLease();
    if (!_active) _discardPcm();
    await _closeMicrophone();
    if (run != _run) return;
    if (wasBusy) {
      _end(DictationPhase.idle, 'cancelled');
    } else {
      _setPhase(DictationPhase.idle);
    }
  }

  /// Clears a notice (failed, no speech, denied).
  void dismiss() {
    if (busy) return;
    _keptClip = null;
    _setPhase(DictationPhase.idle);
  }

  /// Releases the lease, records how the dictation ended and moves to
  /// [phase].
  void _end(DictationPhase phase, String outcome, {String? path}) {
    _lastOutcome = outcome;
    // A partial from a dictation that ended must not show again on retry.
    _liveTranscript = '';
    unawaited(_partials?.cancel());
    _partials = null;
    _releaseLease();
    _breadcrumbs('voice.dictation.ended', {
      'engine': _engine.name,
      'outcome': outcome,
      'path': ?path,
    });
    _setPhase(phase);
  }

  Future<void> _closeMicrophone() {
    if (_closing case final closing?) return closing;
    _ticker?.cancel();
    _ticker = null;
    _level = 0;
    final pcm = _pcm;
    final done = _pcmDone;
    if (pcm == null) return Future.value();
    return _closing = () async {
      try {
        await _recorder.stop();
        await done?.future;
        unawaited(pcm.cancel());
      } finally {
        _pcm = null;
        _pcmDone = null;
        _closing = null;
      }
    }();
  }

  void _discardPcm() {
    unawaited(_pcm?.cancel());
    final done = _pcmDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  void _acquireLease() {
    if (!_active || _pendingLeaseCleanup.isNotEmpty) return;
    final profile = _profile;
    _leased = DictationLeaseCleanup._(
      _repository,
      _lease,
      profile,
      _holdLease(profile),
    );
  }

  void _releaseLease() {
    final lease = _leased;
    if (lease != null) {
      _leased = null;
      _pendingLeaseCleanup.add(lease);
    }
    unawaited(_flushLeaseCleanup());
  }

  Future<void> _flushLeaseCleanup() {
    if (!_credentialsActive || _pendingLeaseCleanup.isEmpty) {
      return Future.value();
    }
    return _releasingLeases ??= () async {
      while (_credentialsActive && _pendingLeaseCleanup.isNotEmpty) {
        final cleanup = _pendingLeaseCleanup.first;
        if (!await cleanup.release(authorized: () => _credentialsActive)) {
          return;
        }
        _pendingLeaseCleanup.remove(cleanup);
      }
    }().whenComplete(() => _releasingLeases = null);
  }

  /// Transfers cleanup queued by cancellation or disposal to the session owner.
  /// Call after disposal; the owner retains failed or unauthorized
  /// releases and never retries using another session's credentials.
  List<DictationLeaseCleanup> takePendingLeaseCleanup() {
    final cleanup = List<DictationLeaseCleanup>.of(_pendingLeaseCleanup);
    _pendingLeaseCleanup.clear();
    return cleanup;
  }

  /// Warms the profile's speech-to-text model; a failure only
  /// means the first transcript may be slower.
  Future<void> _holdLease(String? profile) async {
    if (!_active) return;
    try {
      await _repository.holdSpeechToText(
        _lease,
        active: true,
        profile: profile,
      );
    } on Object {
      // Recording goes on without the warm-up.
    }
  }

  void _setPhase(DictationPhase phase) {
    _phase = phase;
    notifyListeners();
    if (!busy) _completeSettledWaiters();
  }

  var _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _activity?.removeListener(_activityChanged);
    _lastOutcome = 'cancelled';
    _completeSettledWaiters();
    unawaited(() async {
      await cancel();
      await _starting;
      await _recorder.dispose();
    }());
    super.dispose();
  }

  /// The loudness of a chunk of 16-bit PCM, mapped from -50 dBFS (0) to
  /// full scale (1). Every fourth sample is enough for a meter.
  static double _levelOf(Uint8List chunk) {
    final data = ByteData.sublistView(chunk);
    final samples = chunk.lengthInBytes ~/ 2;
    var sum = 0.0;
    var counted = 0;
    for (var i = 0; i < samples; i += 4) {
      final s = data.getInt16(i * 2, Endian.little) / 32768;
      sum += s * s;
      counted++;
    }
    if (counted == 0 || sum == 0) return 0;
    final db = 10 * math.log(sum / counted) / math.ln10;
    return ((db + 50) / 50).clamp(0, 1).toDouble();
  }

  static String _randomId() {
    final random = math.Random();
    return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
  }
}
