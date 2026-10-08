import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hermes_api/hermes_api.dart';

import '../api/hermes_api_client.dart';
import '../api/request_timeout.dart';
import '../chat/gateway/gateway_connection.dart';
import '../telemetry/breadcrumbs.dart';
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
}

/// Records one dictation at a time and turns it into text through Hermes:
/// live over `/api/audio/transcribe-stream` when the profile's provider can,
/// else (or when that fails) by uploading the recording to
/// `POST /api/audio/transcribe`. The transcript goes to [onTranscript]; it is
/// never sent.
class DictationController extends ChangeNotifier {
  DictationController({
    required this._api,
    required this._connect,
    required this._recorder,
    required this.onTranscript,
    this._breadcrumbs = Breadcrumbs.none,
    this.maxDuration = const Duration(minutes: 5),
  }) : _lease = 'app:voice-input:${_randomId()}';

  static const sampleRate = 16000;
  static const _tick = Duration(milliseconds: 100);

  final HermesApiClient _api;
  final MixedSocketConnect _connect;
  final VoiceRecorder _recorder;
  final Breadcrumbs _breadcrumbs;
  final String _lease;
  final ValueChanged<String> onTranscript;

  /// A recording stops by itself after this long.
  final Duration maxDuration;

  String? _profile;
  VoiceSupport _support = VoiceSupport.none;
  var _phase = DictationPhase.idle;
  var _level = 0.0;
  var _elapsed = Duration.zero;
  var _liveTranscript = '';
  var _run = 0;
  var _leased = false;
  TranscribeStream? _stream;
  StreamSubscription<Uint8List>? _pcm;
  Completer<void>? _pcmDone;
  Timer? _ticker;
  BytesBuilder? _clip;
  Uint8List? _keptClip;

  DictationPhase get phase => _phase;

  /// The input level of the latest chunk, from 0 (silence) to 1.
  double get level => _level;

  Duration get elapsed => _elapsed;

  /// The text recognized so far, while recording live; not yet final.
  String get liveTranscript => _liveTranscript;

  /// Whether dictation is offered for the current profile.
  bool get available => _support.speechToText;

  bool get canRetry => _phase == DictationPhase.failed && _keptClip != null;

  /// Points dictation at [profile]; a recording for another profile is
  /// dropped.
  void configure({String? profile, required VoiceSupport support}) {
    if (profile != _profile) unawaited(cancel());
    _profile = profile;
    _support = support;
    notifyListeners();
  }

  Future<void> start() async {
    if (_phase case DictationPhase.recording || DictationPhase.settling) {
      return;
    }
    final run = ++_run;
    _keptClip = null;
    if (!await _recorder.requestPermission()) {
      if (run != _run) return;
      _breadcrumbs('voice.dictation.ended', {'outcome': 'denied'});
      _setPhase(DictationPhase.denied);
      return;
    }
    if (run != _run) return;
    _acquireLease();
    final query = {'profile': ?_profile};
    _stream = _support.liveTranscription
        ? TranscribeStream.start(
            connect: _connect,
            sampleRate: sampleRate,
            query: query,
          )
        : null;
    _stream?.partials.listen((text) {
      _liveTranscript = text;
      notifyListeners();
    });
    final Stream<Uint8List> pcm;
    try {
      pcm = await _recorder.start(sampleRate: sampleRate);
    } on Object {
      _stream?.cancel();
      _releaseLease();
      _breadcrumbs('voice.dictation.ended', {'outcome': 'failed'});
      _setPhase(DictationPhase.failed);
      return;
    }
    _clip = BytesBuilder(copy: false);
    _elapsed = Duration.zero;
    _level = 0;
    _liveTranscript = '';
    final done = _pcmDone = Completer();
    _pcm = pcm.listen(_onPcm, onDone: done.complete);
    _ticker = Timer.periodic(_tick, (_) {
      _elapsed += _tick;
      notifyListeners();
      if (_elapsed >= maxDuration) unawaited(stop());
    });
    _breadcrumbs('voice.dictation.started');
    _setPhase(DictationPhase.recording);
  }

  void _onPcm(Uint8List chunk) {
    _clip?.add(chunk);
    _stream?.add(chunk);
    _level = _levelOf(chunk);
    notifyListeners();
  }

  /// Ends the recording and inserts its transcript.
  Future<void> stop() async {
    if (_phase != DictationPhase.recording) return;
    final run = _run;
    _setPhase(DictationPhase.settling);
    await _closeMicrophone();
    if (run != _run) return;
    final clip = _clip?.takeBytes() ?? Uint8List(0);
    _clip = null;
    final live = await _stream?.finish();
    _stream = null;
    if (run != _run) return;
    if (live != null && live.isNotEmpty) {
      _settle(live, path: 'stream');
    } else {
      await _transcribeClip(clip, run);
    }
  }

  /// Tries the recording of a failed transcription again.
  Future<void> retry() async {
    final clip = _keptClip;
    if (!canRetry || clip == null) return;
    final run = ++_run;
    _setPhase(DictationPhase.settling);
    await _transcribeClip(clip, run);
  }

  Future<void> _transcribeClip(Uint8List clip, int run) async {
    final text = clip.isEmpty ? '' : await _upload(clip);
    if (run != _run) return;
    if (text == null) {
      _keptClip = clip;
      _releaseLease();
      _breadcrumbs('voice.dictation.ended', {
        'outcome': 'failed',
        'path': 'upload',
      });
      _setPhase(DictationPhase.failed);
    } else {
      _settle(text, path: 'upload');
    }
  }

  void _settle(String text, {required String path}) {
    _keptClip = null;
    _liveTranscript = '';
    _releaseLease();
    _breadcrumbs('voice.dictation.ended', {
      'outcome': text.isEmpty ? 'empty' : 'inserted',
      'path': path,
    });
    if (text.isEmpty) {
      _setPhase(DictationPhase.noSpeech);
      return;
    }
    _setPhase(DictationPhase.idle);
    onTranscript(text);
  }

  /// Uploads [clip] as WAV; the transcript, or null when that failed.
  Future<String?> _upload(Uint8List clip) async {
    final wav = wavFromPcm16(clip, sampleRate: sampleRate);
    final dataUrl = 'data:audio/wav;base64,${base64Encode(wav)}';
    try {
      final response = await _api.raw
          .transcribeAudioUploadApiAudioTranscribePost(
            audioTranscriptionRequest: AudioTranscriptionRequest(
              dataUrl: dataUrl,
              mimeType: 'audio/wav',
            ),
            profile: _profile,
            extra: receiveTimeoutExtra(_uploadTimeout(dataUrl.length)),
          );
      final data = response.data;
      return data is Map && data['transcript'] is String
          ? (data['transcript'] as String).trim()
          : null;
    } on Object {
      return null;
    }
  }

  /// At least three minutes, and longer for a long recording, as Hermes'
  /// desktop allows.
  static Duration _uploadTimeout(int dataUrlLength) => Duration(
    milliseconds: math.min(
      600000,
      math.max(180000, (dataUrlLength * 0.1).round()),
    ),
  );

  /// Drops the recording, or the transcript on its way.
  Future<void> cancel() async {
    final wasActive =
        _phase == DictationPhase.recording || _phase == DictationPhase.settling;
    _run++;
    _stream?.cancel();
    _stream = null;
    _clip = null;
    _keptClip = null;
    _liveTranscript = '';
    await _closeMicrophone();
    _releaseLease();
    if (wasActive) {
      _breadcrumbs('voice.dictation.ended', {'outcome': 'cancelled'});
    }
    _setPhase(DictationPhase.idle);
  }

  /// Clears a notice (failed, no speech, denied).
  void dismiss() {
    if (_phase case DictationPhase.recording || DictationPhase.settling) {
      return;
    }
    _keptClip = null;
    _setPhase(DictationPhase.idle);
  }

  Future<void> _closeMicrophone() async {
    _ticker?.cancel();
    _ticker = null;
    _level = 0;
    if (_pcm == null) return;
    await _recorder.stop();
    await _pcmDone?.future;
    unawaited(_pcm?.cancel());
    _pcm = null;
    _pcmDone = null;
  }

  void _acquireLease() {
    _leased = true;
    unawaited(_sendLease(active: true));
  }

  void _releaseLease() {
    if (!_leased) return;
    _leased = false;
    unawaited(_sendLease(active: false));
  }

  /// Warms (or releases) the profile's speech-to-text model; a failure only
  /// means the first transcript may be slower.
  Future<void> _sendLease({required bool active}) async {
    try {
      await _api.raw.sttLeaseApiAudioSttLeasePost(
        sTTLeaseRequest: STTLeaseRequest(lease: _lease, active: active),
        profile: _profile,
      );
    } on Object {
      // Warm-up only.
    }
  }

  void _setPhase(DictationPhase phase) {
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(cancel());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  /// The loudness of a chunk of 16-bit PCM, mapped from -50 dBFS (0) to
  /// full scale (1).
  static double _levelOf(Uint8List chunk) {
    final samples = chunk.lengthInBytes ~/ 2;
    if (samples == 0) return 0;
    final data = ByteData.sublistView(chunk);
    var sum = 0.0;
    for (var i = 0; i < samples; i++) {
      final s = data.getInt16(i * 2, Endian.little) / 32768;
      sum += s * s;
    }
    final rms = math.sqrt(sum / samples);
    if (rms == 0) return 0;
    final db = 20 * math.log(rms) / math.ln10;
    return ((db + 50) / 50).clamp(0, 1).toDouble();
  }

  static String _randomId() {
    final random = math.Random();
    return List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join();
  }
}
