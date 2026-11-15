import 'dart:async';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart'
    show AudioInterruptionEvent, AudioInterruptionType;
import 'package:clock/clock.dart';

import 'call_bridge.dart';

/// The microphone as 16 kHz mono s16le PCM, echo cancellation and noise
/// suppression asked for. [start] resolves once the capture runs; [stop] ends
/// it and may be called at any time, a pending [start] included.
abstract interface class CallRecorder {
  Future<Stream<Uint8List>> start();
  Future<void> stop();
  Future<void> dispose();
}

/// Plays s16le mono PCM pushed in pieces.
abstract interface class CallPlayer {
  Future<void> init();

  /// Queues [pcm] (an even number of bytes) behind what is playing.
  Future<void> play(Uint8List pcm, int rate);

  /// Completes when everything queued has been played.
  Future<void> drain();
  Future<void> stop();
  Future<void> dispose();
}

/// The platform's audio focus and routing (Android).
abstract interface class CallAudioSession {
  /// Takes audio focus for a call and configures the communication audio
  /// mode. Throws when focus is refused.
  Future<void> activate();
  Future<void> deactivate();

  /// What happens to the focus after [activate].
  Stream<AudioInterruptionEvent> get interruptions;

  /// An output or input device came or went.
  Stream<void> get routeChanges;
  Future<void> setSpeaker(bool enabled);
}

/// [CallBridge] for the platforms without CallKit: Android, macOS, Windows and
/// Linux. The microphone comes from [recorder] and the voice goes out through
/// [player], with no platform echo cancellation of the played audio unless
/// [bargeIn] says there is. Where there is none the microphone is closed
/// while a tone or the reply plays and for [echoTail] after, so the call never
/// hears itself. A closed microphone is a closed recorder, not dropped audio.
///
/// Nothing is opened before [start], which the call makes only after the user
/// consented. [stopCapture] and [end] close the microphone first; a [start]
/// still waiting for the recorder is cancelled and its capture closed when it
/// resolves.
class PortableCallBridge implements CallBridge {
  PortableCallBridge({
    required this.recorder,
    required this.player,
    this.session,
    this.bargeIn = false,
    this.echoTail = const Duration(milliseconds: 400),
  });

  final CallRecorder recorder;
  final CallPlayer player;
  final CallAudioSession? session;
  final Duration echoTail;

  @override
  final bool bargeIn;

  final _events = StreamController<Map<String, Object?>>.broadcast();
  final _watches = <StreamSubscription<Object?>>[];

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  String? _id;
  bool _started = false, _captureStopped = false, _ended = false;
  bool _muted = false, _requestPaused = false, _playbackBlocked = false;

  /// Bumped whenever a capture is closed or cancelled: a pending open, and the
  /// callbacks of a stream, belong to one generation.
  int _generation = 0;
  bool _open = false, _opening = false;
  // Cancelled in _closeCapture, which nothing waits for.
  // ignore: cancel_subscriptions
  StreamSubscription<Uint8List>? _capture;
  int? _captureOdd;
  Future<void>? _applying;
  bool _dirty = false;

  /// What the last `capturePaused` event said, by its reason.
  String? _pausedReason;
  DateTime? _playUntil;
  Timer? _tail;
  int? _playOdd, _playRate;
  DateTime _speakerAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _want =>
      _started &&
      !_captureStopped &&
      !_ended &&
      !_muted &&
      !_requestPaused &&
      !_playbackBlocked;

  void _emit(String type, [Map<String, Object?> data = const {}]) {
    if (!_events.isClosed) _events.add({'type': type, ...data});
  }

  @override
  Future<void> start(String id, String name) async {
    _id = id;
    try {
      await session?.activate();
      if (_captureStopped || _ended) {
        // End came while the focus was being taken: give it back.
        await _guard(() async => await session?.deactivate());
        return;
      }
      _watchSession();
      await player.init();
      if (_captureStopped || _ended) {
        // End came while the engine started; its release ran before that.
        await _guard(player.dispose);
        await _guard(() async => await session?.deactivate());
        return;
      }
      if (!await _openCapture()) return;
      _started = true;
      _emit('activated');
      // A pause, mute or tone that came while the recorder was starting.
      await _apply();
      _pausedChanged();
    } on Object {
      // An End that arrived meanwhile has already closed everything.
      if (_captureStopped || _ended) return;
      await _releaseAll();
      rethrow;
    }
  }

  /// Opens the recorder. False when the capture was cancelled while it was
  /// starting: it is closed here, once the recorder answers.
  Future<bool> _openCapture() async {
    final token = ++_generation;
    _opening = true;
    final Stream<Uint8List> stream;
    try {
      stream = await recorder.start();
    } on Object {
      if (token == _generation) _opening = false;
      if (token != _generation) return false;
      rethrow;
    }
    if (token != _generation) {
      await _guard(recorder.stop);
      return false;
    }
    _opening = false;
    _open = true;
    _captureOdd = null;
    _capture = stream.listen(
      (chunk) => _pcm(token, chunk),
      onError: (Object _) => _captureFailed(token),
      onDone: () => _captureFailed(token),
    );
    return true;
  }

  /// Ends the capture, or cancels one that is starting. The recorder is told
  /// to stop in every case; a failure to stop is the caller's.
  Future<void> _closeCapture() async {
    _generation++;
    final sub = _capture;
    _capture = null;
    _open = _opening = false;
    _captureOdd = null;
    // The recorder's stop is what closes the microphone; the subscription
    // only has to stop listening, which nothing waits for.
    if (sub != null) unawaited(sub.cancel().catchError((Object _) {}));
    await recorder.stop();
  }

  void _pcm(int token, Uint8List chunk) {
    if (token != _generation) return;
    final odd = _captureOdd;
    var bytes = chunk;
    if (odd != null) {
      bytes = Uint8List(chunk.length + 1)
        ..[0] = odd
        ..setRange(1, chunk.length + 1, chunk);
    }
    _captureOdd = bytes.length.isOdd ? bytes.last : null;
    final even = bytes.length - (bytes.length % 2);
    if (even == 0) return;
    _emit('pcm', {'data': Uint8List.sublistView(bytes, 0, even)});
  }

  void _captureFailed(int token) {
    if (token != _generation || _ended) return;
    _generation++;
    _open = false;
    _emit('error', {'code': 'audio_start'});
  }

  /// Brings the recorder in line with what the call wants right now.
  Future<void> _apply() {
    _dirty = true;
    // A start that is still pending is cancelled at once, not after it hangs.
    // The start's own open belongs to start; only stopCapture and end cancel it.
    if (!_want && _opening && _started) _generation++;
    return _applying ??= _converge();
  }

  Future<void> _converge() async {
    // Never finish before the caller has stored this future.
    await Future<void>.value();
    try {
      while (_dirty) {
        _dirty = false;
        // Until start has opened the first capture there is nothing to tune.
        if (!_started) continue;
        try {
          if (_want && !_open && !_opening) {
            await _openCapture();
          } else if (!_want && (_open || _opening)) {
            await _closeCapture();
          }
        } on Object {
          if (!_ended) _emit('error', {'code': 'audio_start'});
        }
      }
    } finally {
      _applying = null;
    }
  }

  void _pausedChanged() {
    final reason = _requestPaused
        ? 'request'
        : _playbackBlocked
        ? 'playback'
        : null;
    if (reason == _pausedReason) return;
    final was = _pausedReason;
    _pausedReason = reason;
    _emit('capturePaused', {
      'paused': reason != null,
      'reason': reason ?? was ?? 'request',
    });
  }

  @override
  Future<void> connected() async {}

  @override
  Future<void> mute(bool muted) async {
    _muted = muted;
    await _apply();
    _emit('muted', {'muted': muted});
  }

  @override
  Future<void> speaker(bool enabled) async {
    final session = this.session;
    if (session == null) return;
    _speakerAt = clock.now();
    await session.setSpeaker(enabled);
    _speakerAt = clock.now();
    _emit('route', {'name': enabled ? 'Speaker' : 'Phone', 'speaker': enabled});
  }

  @override
  Future<void> pauseCapture() async {
    _requestPaused = true;
    await _apply();
    _pausedChanged();
  }

  @override
  Future<void> resumeCapture() async {
    _requestPaused = false;
    await _apply();
    _pausedChanged();
  }

  @override
  Future<void> stopCapture(String id) async {
    // A stop of an earlier call does nothing to this one.
    if (_id != null && id != _id) return;
    _captureStopped = true;
    _tail?.cancel();
    await _closeCapture();
  }

  @override
  Future<void> play(Uint8List pcm, int sampleRate) async {
    if (_ended) return;
    if (sampleRate != _playRate) {
      _playRate = sampleRate;
      _playOdd = null;
    }
    final odd = _playOdd;
    final bytes = odd == null
        ? pcm
        : (Uint8List(pcm.length + 1)
            ..[0] = odd
            ..setRange(1, pcm.length + 1, pcm));
    _playOdd = bytes.length.isOdd ? bytes.last : null;
    final even = bytes.length - (bytes.length % 2);
    if (even == 0) return;
    final audio = even == bytes.length
        ? bytes
        : Uint8List.sublistView(bytes, 0, even);
    await player.play(audio, sampleRate);
    if (bargeIn) return;
    final now = clock.now();
    final from = _playUntil != null && _playUntil!.isAfter(now)
        ? _playUntil!
        : now;
    _playUntil = from.add(
      Duration(
        microseconds: even * Duration.microsecondsPerSecond ~/ (2 * sampleRate),
      ),
    );
    if (!_playbackBlocked) {
      _playbackBlocked = true;
      unawaited(_apply().then((_) => _pausedChanged()));
    }
    _scheduleRelease();
  }

  /// The block on the microphone ends [echoTail] after the audio it was
  /// raised for.
  void _scheduleRelease() {
    final until = _playUntil;
    if (until == null) return;
    _tail?.cancel();
    final wait = until.add(echoTail).difference(clock.now());
    _tail = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (_ended) return;
      _playbackBlocked = false;
      unawaited(_apply().then((_) => _pausedChanged()));
    });
  }

  /// The audio is over now; only the tail remains.
  void _playbackOver() {
    _playOdd = null;
    if (bargeIn || _playUntil == null) return;
    _playUntil = clock.now();
    _scheduleRelease();
  }

  @override
  Future<void> drain() async {
    if (_ended) return;
    await player.drain();
    _playbackOver();
  }

  @override
  Future<void> stopPlayback() async {
    await player.stop();
    _playbackOver();
  }

  void _watchSession() {
    final session = this.session;
    if (session == null) return;
    _watches
      ..add(
        session.interruptions.listen((event) {
          // Ducking keeps the call; any other loss of focus ends it.
          if (event.begin && event.type != AudioInterruptionType.duck) {
            _emit('deactivated', {'reason': 'focus'});
          }
        }),
      )
      ..add(session.routeChanges.listen((_) => unawaited(_routeChanged())));
  }

  Future<void> _routeChanged() async {
    if (_ended || !_started || _captureStopped) return;
    // Our own speaker switch moves the route too.
    if (clock.now().difference(_speakerAt) <
        const Duration(milliseconds: 800)) {
      return;
    }
    try {
      if (_open) await _closeCapture();
    } on Object {
      // The reopen below reports a microphone that is gone.
    }
    await _apply();
    _emit('audioReset');
  }

  @override
  Future<void> end() async {
    if (_ended) return;
    _ended = true;
    _captureStopped = true;
    _tail?.cancel();
    // Capture first, then what plays, then the audio session.
    try {
      // A recorder that hangs must not keep the rest from being released.
      await _closeCapture().timeout(const Duration(seconds: 2));
    } on Object {
      // stopCapture reports whether the microphone closed; this is the backup.
    }
    await _releaseAll();
  }

  Future<void> _releaseAll() async {
    for (final watch in _watches) {
      await _guard(watch.cancel);
    }
    _watches.clear();
    await _guard(player.stop);
    await _guard(player.dispose);
    await _guard(recorder.dispose);
    final session = this.session;
    if (session != null) await _guard(session.deactivate);
    if (!_events.isClosed) unawaited(_events.close());
  }

  Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } on Object {
      // Releasing one resource never stops the release of the next.
    }
  }
}
