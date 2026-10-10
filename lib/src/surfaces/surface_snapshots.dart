import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span, StatusCode;

import '../api/hermes_repositories.dart';
import '../app_lock/app_lock_controller.dart';
import 'chat_hints.dart';
import 'surface_snapshot.dart';
import 'surface_snapshot_builder.dart';
import 'surface_snapshot_store.dart';

/// How long chat changes are gathered before a snapshot is built.
const kSurfaceDebounce = Duration(seconds: 2);

/// How long the chats of other profiles, Kanban and schedules are trusted
/// while the app is in front.
const kSurfaceRemoteInterval = Duration(minutes: 5);

/// How long a move to the background waits for the server before it writes
/// what is known; an answer within it makes the one write.
const kSurfacePauseWindow = Duration(milliseconds: 800);

class _Job {
  const _Job(this.trigger, {required this.remote});

  final SurfaceTrigger trigger;
  final bool remote;

  _Job merge(_Job next) => _Job(next.trigger, remote: remote || next.remote);
}

/// Keeps the [SurfaceSnapshot] current while the app is in front: the chat
/// screen reports what changed, the server is asked about everything else at
/// most every [remoteInterval] and whenever the app goes to the background.
class SurfaceSnapshots with WidgetsBindingObserver {
  SurfaceSnapshots({
    required this.store,
    Stream<void>? signedOut,
    this.appLock,
    this.debounce = kSurfaceDebounce,
    this.remoteInterval = kSurfaceRemoteInterval,
    this.pauseWindow = kSurfacePauseWindow,
    DateTime Function()? now,
    SurfaceSnapshotBuilder Function(HermesRepositories)? builderFor,
  }) : _now = now ?? DateTime.now,
       _builderFor = builderFor ?? SurfaceSnapshotBuilder.new {
    WidgetsBinding.instance.addObserver(this);
    _signedOut = signedOut?.listen((_) => unawaited(_clear()));
    _appLockWasOn = appLock?.enabled ?? false;
    appLock?.addListener(_onAppLock);
  }

  final SurfaceSnapshotStore store;
  final AppLockController? appLock;
  final Duration debounce;
  final Duration remoteInterval;
  final Duration pauseWindow;
  final DateTime Function() _now;
  final SurfaceSnapshotBuilder Function(HermesRepositories) _builderFor;

  /// The repositories of the connection, which stay after a session ended.
  HermesRepositories? repositories;

  /// Whether the connection has a session. Nothing is built or written
  /// without one, so the signed-out snapshot stays.
  bool signedIn = false;

  StreamSubscription<void>? _signedOut;
  Timer? _timer;
  SurfaceSnapshotBuilder? _builder;
  HermesRepositories? _builderOf;
  ChatHints? _hints;
  SurfaceSnapshot? _previous;
  DateTime? _lastRemote;
  _Job? _queued;
  var _running = false;
  var _disposed = false;
  var _appLockWasOn = false;

  /// Bumped on sign-out, so a build or a read that was under way leaves
  /// nothing behind.
  var _generation = 0;

  bool get _lockOn => appLock?.enabled ?? false;

  /// The chat screen's account of its profile after something changed.
  void chatChanged(SurfaceTrigger trigger, ChatHints hints) {
    _hints = hints;
    _timer?.cancel();
    _timer = Timer(debounce, () => _request(_Job(trigger, remote: false)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    _timer?.cancel();
    _request(const _Job(SurfaceTrigger.pause, remote: true));
  }

  void _onAppLock() {
    final on = _lockOn;
    if (on == _appLockWasOn) return;
    _appLockWasOn = on;
    _timer?.cancel();
    if (on) {
      // Titles must not stay in the App Group while the server is read.
      unawaited(_hideStored());
      _request(const _Job(SurfaceTrigger.appLock, remote: false));
    } else {
      // What was written meanwhile had no titles, so everything is read again.
      _request(const _Job(SurfaceTrigger.appLock, remote: true));
    }
  }

  Future<void> _hideStored() async {
    final generation = _generation;
    try {
      final known = _previous ?? await store.read();
      if (known == null || generation != _generation || _disposed) return;
      if (!_lockOn) return;
      final hidden = _previous = known.redacted();
      await store.write(hidden);
    } on Object {
      // The job requested alongside writes it again.
    }
  }

  void _request(_Job job) {
    if (_disposed) return;
    _queued = _queued?.merge(job) ?? job;
    if (!_running) unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    try {
      for (var job = _queued; job != null; job = _queued) {
        _queued = null;
        await _run(job);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _run(_Job job) async {
    final repositories = this.repositories;
    if (repositories == null || !signedIn || _disposed) return;
    final generation = _generation;
    try {
      if (_previous == null) {
        final stored = await store.read();
        if (generation != _generation) return;
        _previous = stored;
      }
      final stale =
          _lastRemote == null ||
          !_now().isBefore(_lastRemote!.add(remoteInterval));
      if (job.trigger == SurfaceTrigger.pause) {
        await _pause(repositories, generation);
      } else {
        final remote = job.remote || stale;
        await _publish(
          await _compose(repositories, job.trigger, remote: remote),
          generation,
          remote: remote,
        );
      }
    } on Object {
      // A snapshot that could not be built leaves the last one in place.
    }
  }

  /// Leaving the app is the last chance to write what is known, so when the
  /// server does not answer within [pauseWindow] that is written first.
  Future<void> _pause(HermesRepositories repositories, int generation) async {
    const trigger = SurfaceTrigger.pause;
    final remote = _compose(repositories, trigger, remote: true);
    final answer = remote.then<SnapshotBuild?>((r) => r, onError: (_) => null);
    final early = await Future.any([
      answer,
      Future<SnapshotBuild?>.delayed(pauseWindow),
    ]);
    if (early == null) {
      await _publish(
        await _compose(repositories, trigger, remote: false),
        generation,
      );
    }
    final built = early ?? await answer;
    if (built != null) await _publish(built, generation, remote: true);
  }

  Future<SnapshotBuild> _compose(
    HermesRepositories repositories,
    SurfaceTrigger trigger, {
    required bool remote,
  }) async {
    if (!identical(_builderOf, repositories)) {
      _builderOf = repositories;
      _builder = _builderFor(repositories);
    }
    final span = _startSpan(repositories, trigger);
    try {
      final result = await _builder!.build(
        signedIn: signedIn,
        previous: _previous,
        hints: _hints,
        refreshRemote: remote,
        redact: _lockOn,
      );
      _endSpan(span, sourcesFailed: result.sourcesFailed);
      return result;
    } on Object {
      _endSpan(span, failed: true);
      rethrow;
    }
  }

  Future<void> _publish(
    SnapshotBuild result,
    int generation, {
    bool remote = false,
  }) async {
    if (generation != _generation || _disposed || !signedIn) return;
    if (remote) _lastRemote = _now();
    // App Lock may have changed while the build was under way.
    final snapshot = _previous = _lockOn
        ? result.snapshot.redacted()
        : result.snapshot;
    await store.write(snapshot);
  }

  Future<void> _clear() async {
    _generation++;
    _timer?.cancel();
    _queued = null;
    _hints = null;
    _previous = null;
    _lastRemote = null;
    await store.clear(now: _now());
  }

  Span? _startSpan(HermesRepositories repositories, SurfaceTrigger trigger) {
    try {
      final telemetry = repositories.telemetry;
      return telemetry.tracer?.startSpan(
        'surface.snapshot.build',
        attributes: {...telemetry.serverAttributes, 'trigger': trigger.slug},
      );
    } on Object {
      return null;
    }
  }

  void _endSpan(Span? span, {int sourcesFailed = 0, bool failed = false}) {
    if (span == null) return;
    try {
      span.setAttribute('sources_failed', sourcesFailed);
      if (failed) span.setStatus(StatusCode.error);
      span.end();
    } on Object {
      // Telemetry must not break the app.
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    unawaited(_signedOut?.cancel());
    appLock?.removeListener(_onAppLock);
    WidgetsBinding.instance.removeObserver(this);
  }
}
