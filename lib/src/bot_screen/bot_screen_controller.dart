import 'dart:async';

import 'package:flutter/foundation.dart';

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
/// control or App Lock covers the app, and an answer that arrives after App
/// Lock or [dispose] is discarded.
class BotScreenController extends ChangeNotifier {
  /// [connectionEvents] is the shared gateway's raw feed, in which the
  /// `display.status` and `display.lease` broadcasts arrive. A null [profile]
  /// is the server's default profile.
  BotScreenController(
    this._repository,
    Stream<GatewayConnectionEvent> connectionEvents, {
    this.profile,
    this.pollEvery = kFramePollInterval,
  }) {
    _events = connectionEvents.listen(_onConnectionEvent);
  }

  final BotScreenRepository _repository;

  /// The profile the screen is read for; null is the server's default.
  final String? profile;
  final Duration pollEvery;
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
  var _disposed = false;
  Timer? _timer;

  bool get foreground => _foreground;
  set foreground(bool value) {
    if (value == _foreground) return;
    _foreground = value;
    if (value && _demand > 0) _statusDue = true;
    _reconcile();
  }

  bool get unlocked => _unlocked;
  set unlocked(bool value) {
    if (value == _unlocked) return;
    _unlocked = value;
    if (!value) {
      _generation++;
      frame = null;
      _notify();
    }
    _reconcile();
  }

  /// Asks for frames until the returned handle is released.
  BotScreenWatch watch() {
    if (_demand++ == 0) _statusDue = true;
    _reconcile();
    return BotScreenWatch._(() {
      _demand--;
      _reconcile();
    });
  }

  /// Starts the profile's screen. The status stays as it was and [starting]
  /// is set until Hermes answers; a failure is left in [startError].
  Future<void> start() async {
    if (starting || _disposed) return;
    final generation = _generation;
    starting = true;
    startError = null;
    _notify();
    final result = await _repository.start(profile);
    if (_disposed) return;
    starting = false;
    if (generation != _generation) {
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
      case BotScreenFailed(:final kind):
        startError = kind;
    }
    _notify();
  }

  bool _stale(int generation) => _disposed || generation != _generation;

  bool get _canTalk => !_disposed && _unlocked && _foreground && !unsupported;

  bool get _shouldPoll => _canTalk && _demand > 0 && (status?.running ?? false);

  void _onConnectionEvent(GatewayConnectionEvent signal) {
    if (!signal.connected) {
      if (_demand > 0) {
        _statusDue = true;
        _pump();
      }
      return;
    }
    final event = signal.event;
    final key = status?.profileKey;
    if (event == null || key == null) return;
    final payload = event.payload;
    if (payload['profile_key'] != key) return;
    switch (event.type) {
      case 'display.status':
        _apply(BotScreenStatus.fromJson(payload));
        _notify();
      case 'display.lease':
        final current = status;
        if (current == null) return;
        _apply(current.withLease(BotScreenLease.fromJson(payload['lease'])));
        _notify();
    }
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
          _frameDue = true;
          _pump();
        });
        _frameDue = true;
      }
    } else {
      _timer?.cancel();
      _timer = null;
      _frameDue = false;
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

  void _run(Future<void> Function(int generation) call) {
    _busy = true;
    call(_generation).whenComplete(() {
      _busy = false;
      if (!_disposed) _pump();
    });
  }

  Future<void> _readStatus(int generation) async {
    final result = await _repository.status(profile);
    if (_stale(generation)) return;
    switch (result) {
      case BotScreenOk(:final value):
        _apply(value);
      case BotScreenUnsupported():
        unsupported = true;
        _reconcile();
      case BotScreenFailed(:final kind):
        failure = kind;
    }
    _notify();
  }

  Future<void> _readFrame(int generation) async {
    final result = await _repository.thumbnail(profile);
    if (_stale(generation)) return;
    switch (result) {
      case BotScreenOk(value: BotScreenJpeg(:final bytes)):
        frame = bytes;
        suppressed = false;
        failure = null;
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
    frame = null;
    unawaited(_events.cancel());
    super.dispose();
  }
}
