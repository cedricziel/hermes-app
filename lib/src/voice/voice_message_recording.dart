import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../share/shared_item.dart';
import 'voice_audio_focus.dart';
import 'voice_recorder.dart';
import 'voice_recording_view.dart';
import 'wav.dart';

/// Captures a draft audio attachment. Nothing is uploaded or transcribed here.
/// Releasing during a permission prompt prevents a later microphone start.
class VoiceMessageRecording extends ChangeNotifier with WidgetsBindingObserver {
  VoiceMessageRecording({
    required this._recorder,
    required this.onAttach,
    required this.onError,
    this.canRecord,
    this._activity,
    Future<Directory> Function()? directory,
    VoiceAudioFocus? focus,
    this.maxDuration = const Duration(minutes: 5),
  }) : _directory = directory ?? getTemporaryDirectory,
       _focus = focus ?? VoiceAudioFocus.shared {
    _activity?.addListener(_activityChanged);
    _focus.register(_pauseForCall);
    WidgetsBinding.instance.addObserver(this);
  }

  static const sampleRate = 16000;
  final VoiceRecorder _recorder;
  final ValueChanged<SharedFile> onAttach;
  final ValueChanged<String> onError;
  final bool Function()? canRecord;
  final ValueListenable<bool>? _activity;
  final Future<Directory> Function() _directory;
  final VoiceAudioFocus _focus;
  final Duration maxDuration;
  final _files = <File>[];
  Directory? _folder;
  var phase = VoiceRecordingPhase.idle;
  Duration elapsed = Duration.zero;
  var _disposed = false;
  var _held = false;
  var _epoch = 0;
  var _bytes = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _subscription;
  Completer<void>? _drained;
  Future<void>? _starting;
  Future<void>? _ending;
  Timer? _ticker;
  final _clock = Stopwatch();

  bool get busy => phase != VoiceRecordingPhase.idle;
  bool get _allowed =>
      !_disposed &&
      (_activity?.value ?? true) &&
      !_focus.inCall &&
      (canRecord?.call() ?? true);

  VoiceRecordingView get view => VoiceRecordingView(
    phase: phase,
    elapsed: elapsed,
    onStart: () => unawaited(start()),
    onFinish: () => unawaited(finish()),
    onCancel: () => unawaited(cancel()),
  );

  Future<void> start() async {
    if (busy || !_allowed) return;
    _held = true;
    final epoch = ++_epoch;
    _bytes = BytesBuilder(copy: false);
    elapsed = Duration.zero;
    phase = VoiceRecordingPhase.preparing;
    _notify();
    await (_starting = _start(epoch));
  }

  Future<void> _start(int epoch) async {
    try {
      await _focus.pausePlayers(except: _pauseForCall);
      if (!_held || epoch != _epoch || !_allowed) return;
      final permission = await _recorder.requestPermission();
      if (!_held || epoch != _epoch || !_allowed) return;
      if (!permission) {
        _held = false;
        phase = VoiceRecordingPhase.idle;
        onError(
          'Microphone access is off. Allow it in Settings to record a voice message.',
        );
        _notify();
        return;
      }
      final stream = await _recorder.start(sampleRate: sampleRate);
      _drained = Completer<void>();
      _subscription = stream.listen(
        (chunk) {
          if (epoch != _epoch) return;
          final limit = sampleRate * 2 * maxDuration.inMilliseconds ~/ 1000;
          final remaining = limit - _bytes.length;
          if (remaining > 0) {
            _bytes.add(
              chunk.length > remaining
                  ? Uint8List.sublistView(chunk, 0, remaining)
                  : chunk,
            );
          }
          if (_bytes.length >= limit) unawaited(finish());
        },
        onDone: () {
          if (_drained?.isCompleted == false) _drained!.complete();
          if (_held) unawaited(finish());
        },
        onError: (Object error, StackTrace stack) {
          unawaited(
            cancel(error: 'Could not record this voice message. Try again.'),
          );
        },
      );
      if (!_held || epoch != _epoch || !_allowed) return;
      phase = VoiceRecordingPhase.recording;
      _clock
        ..reset()
        ..start();
      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
        elapsed = _clock.elapsed;
        if (elapsed >= maxDuration) {
          unawaited(finish());
        } else {
          _notify();
        }
      });
      _notify();
    } on Object {
      if (epoch != _epoch || _disposed) return;
      _held = false;
      phase = VoiceRecordingPhase.idle;
      onError('Could not start the microphone. Try again.');
      _notify();
    }
  }

  Future<void> finish() {
    if (!busy) return Future.value();
    _held = false;
    return _ending ??= _finish(_epoch);
  }

  Future<void> _finish(int epoch) async {
    // Awaiting start also covers release while the platform is opening audio.
    try {
      await _starting;
      phase = VoiceRecordingPhase.attaching;
      _ticker?.cancel();
      _clock.stop();
      _notify();
      await _stop();
      if (epoch != _epoch || !_allowed) return;
      final pcm = _bytes.takeBytes();
      if (pcm.length < sampleRate * 2 ~/ 5) {
        onError('Recording too short. Hold Send while you speak.');
        return;
      }
      // Whole PCM frames only, even if a platform ends on an odd byte.
      final audio = wavFromPcm16(
        Uint8List.sublistView(pcm, 0, pcm.length - pcm.length % 2),
        sampleRate: sampleRate,
      );
      final root = await _directory();
      if (epoch != _epoch || !_allowed) return;
      final folder = _folder ??= await root.createTemp('hermes_voice_draft_');
      final file = File(
        '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      _files.add(file);
      await file.writeAsBytes(audio, flush: true);
      if (epoch != _epoch || !_allowed) {
        await file.delete();
        return;
      }
      final seconds = (pcm.length / (sampleRate * 2)).ceil();
      onAttach(
        SharedFile(
          path: file.path,
          name: 'Voice message ${seconds}s.wav',
          mimeType: 'audio/wav',
        ),
      );
    } on Object {
      if (!_disposed && epoch == _epoch) {
        onError('Could not attach this recording. Try again.');
      }
    } finally {
      _bytes.clear();
      _ending = null;
      phase = VoiceRecordingPhase.idle;
      _notify();
    }
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    _ticker = null;
    _clock.stop();
    if (_subscription == null) return;
    try {
      await _recorder.stop().timeout(const Duration(seconds: 5));
      await _drained?.future.timeout(const Duration(seconds: 2));
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      _drained = null;
    }
  }

  Future<void> cancel({String? error}) async {
    if (!busy) return;
    ++_epoch;
    _held = false;
    // Keep new recordings blocked until native start/stop has settled.
    await (_ending ??= _finish(_epoch - 1));
    if (error != null && !_disposed) {
      onError(error);
    }
  }

  Future<void> _pauseForCall() => cancel();
  void _activityChanged() {
    if (_activity?.value == false) unawaited(cancel());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(cancel());
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void>? _cleanupFuture;

  /// Completes after disposal has stopped capture and removed temporary files.
  Future<void> get whenClosed => _cleanupFuture ?? Future.value();

  Future<void> _cleanup() async {
    await cancel();
    try {
      await _recorder.dispose();
    } on Object {
      /* The draft still needs cleanup. */
    }
    for (final file in _files) {
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        /* Best effort temporary-file cleanup. */
      }
    }
    try {
      await _folder?.delete();
    } on FileSystemException {
      /* Already removed. */
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _activity?.removeListener(_activityChanged);
    _focus.unregister(_pauseForCall);
    WidgetsBinding.instance.removeObserver(this);
    _cleanupFuture = _cleanup();
    super.dispose();
  }
}
