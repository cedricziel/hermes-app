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
  final DateTime Function() _now;
  final SurfaceSnapshotBuilder Function(HermesRepositories) _builderFor;

  /// The signed-in repositories; null while signed out, when nothing is built.
  HermesRepositories? repositories;

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

  /// Bumped on sign-out, so a build that was under way writes nothing.
  var _generation = 0;

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
    final on = appLock?.enabled ?? false;
    if (on == _appLockWasOn) return;
    _appLockWasOn = on;
    _timer?.cancel();
    _request(const _Job(SurfaceTrigger.appLock, remote: false));
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
    if (repositories == null || _disposed) return;
    final generation = _generation;
    try {
      _previous ??= await store.read();
      // Leaving the app is the last chance to write what is known, so that
      // comes before the network does.
      if (job.trigger == SurfaceTrigger.pause) {
        await _build(repositories, generation, job.trigger, remote: false);
      }
      final stale =
          _lastRemote == null ||
          !_now().isBefore(_lastRemote!.add(remoteInterval));
      await _build(
        repositories,
        generation,
        job.trigger,
        remote: job.remote || stale,
      );
    } on Object {
      // A snapshot that could not be built leaves the last one in place.
    }
  }

  Future<void> _build(
    HermesRepositories repositories,
    int generation,
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
        previous: _previous,
        hints: _hints,
        refreshRemote: remote,
        redact: appLock?.enabled ?? false,
      );
      _endSpan(span, sourcesFailed: result.sourcesFailed);
      if (generation != _generation || _disposed) return;
      if (remote) _lastRemote = _now();
      _previous = result.snapshot;
      await store.write(result.snapshot);
    } on Object {
      _endSpan(span, failed: true);
      rethrow;
    }
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
