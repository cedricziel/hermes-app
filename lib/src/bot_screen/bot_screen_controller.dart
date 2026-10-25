import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../chat/gateway_connection_transport.dart';
import 'bot_screen_models.dart';
import 'bot_screen_repository.dart';

/// How often a frame is requested while a surface asks for one.
const kFramePollInterval = Duration(seconds: 3);

/// Every this many frame requests the status is read again, because lease
/// changes made by other server processes are not broadcast.
const kStatusEveryFrames = 10;

/// A surface's claim on frames: the controller polls while any is held.
class BotScreenWatch {
  BotScreenWatch._(this._release);

  final void Function() _release;
  var _held = true;

  /// Lets go of the claim. Safe to call more than once.
  void release() {
    if (!_held) return;
    _held = false;
    _release();
  }
}

/// One profile's Bot Screen on one gateway connection: its status, the latest
/// still frame, and the Start action. Surfaces ask for frames with [watch];
/// the owner reports whether the app is in [foreground] and [unlocked].
///
/// Frames stay in memory, are dropped when the screen stops, a person takes
/// control, App Lock covers the app, the app leaves the foreground or the last
/// surface lets go, and an answer that arrives after App Lock or [dispose] is
/// discarded.
class BotScreenController extends ChangeNotifier {
  /// [connectionEvents] is the shared gateway's raw feed, in which the
  /// `display.status` and `display.lease` broadcasts arrive. A null [profile]
  /// is the server's default profile.
  BotScreenController(
    this._repository,
    Stream<GatewayConnectionEvent> connectionEvents, {
    this.profile,
    this.pollEvery = kFramePollInterval,
    this.events = noopAppEventLogger,
  }) {
    _events = connectionEvents.listen(
      _onConnectionEvent,
      onError: _onConnectionError,
    );
  }

  final BotScreenRepository _repository;

  /// The profile the screen is read for; null is the server's default.
  final String? profile;
  final Duration pollEvery;

  /// Where `bot_screen.start` is logged, with its outcome only.
  final AppEventLogger events;
  late final StreamSubscription<GatewayConnectionEvent> _events;

  /// The latest status, or null before the first answer.
  BotScreenStatus? status;

  /// The latest JPEG, or null when there is none to show.
  Uint8List? frame;

  /// Whether a person holds control, so no picture is sent.
  bool suppressed = false;

  /// Whether the server has no Bot Screen feature (it is too old).
  bool unsupported = false;

  /// Why the latest status or frame read failed; cleared by the next success.
  BotScreenFailure? failure;

  /// Whether a Start is in progress.
  bool starting = false;

  /// Why the latest Start failed.
  BotScreenFailure? startError;

  var _foreground = true;
  var _unlocked = true;
  var _demand = 0;
  var _generation = 0;
  var _busy = false;
  var _statusDue = false;
  var _frameDue = false;
  var _frameRequests = 0;
  var _broadcasts = 0;
  var _statusFailures = 0;
  var _frameFailures = 0;
  var _skipTicks = 0;
  var _disposed = false;
  Timer? _timer;
  Timer? _statusRetry;

  bool get foreground => _foreground;
  set foreground(bool value) {
    if (value == _foreground) return;
    _foreground = value;
    if (value && _demand > 0) _statusDue = true;
    if (!value) _dropFrame();
    _reconcile();
  }

  bool get unlocked => _unlocked;
  set unlocked(bool value) {
    if (value == _unlocked) return;
    _unlocked = value;
    if (!value) {
      _generation++;
      _dropFrame();
    }
    _reconcile();
  }

  void _dropFrame() {
    if (frame == null) return;
    frame = null;
    _notify();
  }

  /// Asks for frames until the returned handle is released.
  BotScreenWatch watch() {
    if (_demand++ == 0) _statusDue = true;
    _reconcile();
    return BotScreenWatch._(() {
      _demand--;
      _reconcile();
      // The release can come while the tree is being torn down, when a
      // listener must not rebuild, so listeners hear of the dropped frame
      // right after.
      if (_demand == 0 && frame != null) {
        frame = null;
        scheduleMicrotask(_notify);
      }
    });
  }

  /// Reads the screen again at once, past the waits that follow a failure.
  /// For a surface's Try Again; does nothing while nothing asks for frames.
  void retry() {
    if (_demand == 0) return;
    _statusRetry?.cancel();
    _statusRetry = null;
    _statusFailures = 0;
    _frameFailures = 0;
    _skipTicks = 0;
    _statusDue = true;
    if (_shouldPoll) _frameDue = true;
    _pump();
  }

  /// Starts the profile's screen. The status stays as it was and [starting]
  /// is set until Hermes answers; a failure is left in [startError]. Nothing
  /// is sent while the app is in the background or under App Lock.
  Future<void> start() async {
    if (starting || !_canTalk) return;
    final mark = _mark();
    starting = true;
    startError = null;
    _notify();
    final BotScreenResult<BotScreenStatus> result;
    try {
      result = await _repository.start(profile);
    } catch (_) {
      _logStart('error');
      if (!_disposed) {
        starting = false;
        _notify();
      }
      rethrow;
    }
    _logStart(switch (result) {
      BotScreenOk(:final value) when value.blocker != null => 'blocked',
      BotScreenOk(:final value) when value.running => 'started',
      _ => 'error',
    });
    if (_disposed) return;
    starting = false;
    if (mark != _mark()) {
      // The answer is dropped, but the server may have started the screen.
      _statusDue = true;
      _notify();
      _pump();
      return;
    }
    switch (result) {
      case BotScreenOk(:final value):
        _apply(value);
      case BotScreenUnsupported():
        unsupported = true;
        _reconcile();
      case BotScreenFailed(:final kind):
        startError = kind;
    }
    _notify();
  }

  /// Logs the outcome of a Start. Telemetry must never break the app.
  void _logStart(String outcome) {
    try {
      events('bot_screen.start', {'outcome': outcome});
    } on Object {
      return;
    }
  }

  /// What an answer must still match to be used: App Lock and a broadcast
  /// both make an answer that was asked for before them out of date.
  (int, int) _mark() => (_generation, _broadcasts);

  bool _stale((int, int) mark) => _disposed || mark != _mark();

  bool get _canTalk => !_disposed && _unlocked && _foreground && !unsupported;

  bool get _shouldPoll => _canTalk && _demand > 0 && (status?.running ?? false);

  void _onConnectionEvent(GatewayConnectionEvent signal) {
    if (!signal.connected) return _missedBroadcasts();
    final event = signal.event;
    final key = status?.profileKey;
    if (event == null || key == null) return;
    final payload = event.payload;
    if (payload['profile_key'] != key) return;
    switch (event.type) {
      case 'display.status':
        _broadcasts++;
        _apply(BotScreenStatus.fromJson(payload));
        _notify();
      case 'display.lease':
        final current = status;
        if (current == null) return;
        _broadcasts++;
        _apply(current.withLease(BotScreenLease.fromJson(payload['lease'])));
        _notify();
    }
  }

  /// The feed ended in an error, as the session transport's does when its
  /// connection is swapped or retired: broadcasts may have been missed.
  void _onConnectionError(Object error, StackTrace stackTrace) =>
      _missedBroadcasts();

  /// Reads the status again, if a surface is showing the screen.
  void _missedBroadcasts() {
    if (_demand == 0) return;
    _statusDue = true;
    _pump();
  }

  /// Takes [next] as the status. A stopped screen or a person in control
  /// leaves no frame.
  void _apply(BotScreenStatus next) {
    status = next;
    unsupported = false;
    failure = null;
    suppressed = next.lease.holder == BotScreenHolder.human;
    if (!next.running || suppressed) frame = null;
    _reconcile();
  }

  /// Starts or stops the poll timer to match the gates, then sends whatever
  /// is due.
  void _reconcile() {
    if (_shouldPoll) {
      if (_timer == null) {
        _timer = Timer.periodic(pollEvery, (_) {
          if (_skipTicks > 0) {
            _skipTicks--;
            return;
          }
          _frameDue = true;
          _pump();
        });
        _frameDue = true;
      }
    } else {
      _timer?.cancel();
      _timer = null;
      _frameDue = false;
      _frameFailures = 0;
      _skipTicks = 0;
    }
    if (_demand == 0) {
      _statusRetry?.cancel();
      _statusRetry = null;
      _statusFailures = 0;
    }
    _pump();
  }

  /// Sends the next due call, one at a time: the status first, then a frame.
  void _pump() {
    if (_busy || !_canTalk) return;
    if (_statusDue) {
      _statusDue = false;
      _run(_readStatus);
    } else if (_frameDue && _shouldPoll) {
      _frameDue = false;
      if (++_frameRequests % kStatusEveryFrames == 0) _statusDue = true;
      _run(_readFrame);
    }
  }

  void _run(Future<void> Function((int, int) mark) call) {
    _busy = true;
    call(_mark()).whenComplete(() {
      _busy = false;
      if (!_disposed) _pump();
    });
  }

  Future<void> _readStatus((int, int) mark) async {
    final result = await _repository.status(profile);
    if (_stale(mark)) return;
    switch (result) {
      case BotScreenOk(:final value):
        _statusFailures = 0;
        _statusRetry?.cancel();
        _statusRetry = null;
        _apply(value);
      case BotScreenUnsupported():
        unsupported = true;
        _reconcile();
      case BotScreenFailed(:final kind):
        failure = kind;
        _retryStatusLater();
    }
    _notify();
  }

  /// Reads the status again after a growing wait (1 s, doubling to 32 s) for
  /// as long as a surface asks, because nothing else would: with no status
  /// there is no polling and no broadcast to match.
  void _retryStatusLater() {
    if (_demand == 0 || _statusRetry != null) return;
    final seconds = 1 << (_statusFailures++).clamp(0, 5);
    _statusRetry = Timer(Duration(seconds: seconds), () {
      _statusRetry = null;
      if (_demand == 0) return;
      _statusDue = true;
      _pump();
    });
  }

  Future<void> _readFrame((int, int) mark) async {
    final result = await _repository.thumbnail(profile);
    if (_stale(mark)) return;
    switch (result) {
      case BotScreenOk(value: BotScreenJpeg(:final bytes)):
        _frameFailures = 0;
        failure = null;
        if (status?.lease.holder != BotScreenHolder.human) {
          frame = bytes;
          suppressed = false;
        }
      case BotScreenOk(value: BotScreenSuppressed()):
        frame = null;
        suppressed = true;
        _statusDue = true;
      case BotScreenOk(value: BotScreenStopped()):
        frame = null;
        _statusDue = true;
      case BotScreenUnsupported():
        unsupported = true;
        _reconcile();
      case BotScreenFailed(:final kind):
        failure = kind;
        // Wait out 1, 3, 7 and then at most 9 ticks before the next try.
        _skipTicks = ((1 << ++_frameFailures) - 1).clamp(0, 9);
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _timer?.cancel();
    _timer = null;
    _statusRetry?.cancel();
    _statusRetry = null;
    frame = null;
    unawaited(_events.cancel());
    super.dispose();
  }
}
