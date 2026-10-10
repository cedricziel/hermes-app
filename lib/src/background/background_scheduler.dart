/// Asks the system for periodic background runs while someone is signed in.
///
/// iOS (BGTaskScheduler) and Android (WorkManager) decide when, and whether,
/// a run happens; nothing here promises any timing.
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show Listenable, TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workmanager/workmanager.dart';

import '../auth/auth_controller.dart';
import 'entry_points.dart';

/// The least time between two runs; both platforms refuse less.
const kBackgroundRefreshInterval = Duration(minutes: 15);

/// The task's name on Android. On iOS it is the BGTaskScheduler identifier,
/// [iosRefreshIdentifier].
const kAndroidRefreshName = 'hermes.background.refresh';

/// What `BGTaskSchedulerPermittedIdentifiers` in the Info.plist lists:
/// `$(PRODUCT_BUNDLE_IDENTIFIER).refresh`, so a debug build has its own.
Future<String> backgroundRefreshName() async =>
    defaultTargetPlatform == TargetPlatform.iOS
    ? '${(await PackageInfo.fromPlatform()).packageName}.refresh'
    : kAndroidRefreshName;

/// The system's periodic-task API, as far as the app uses it.
abstract interface class PeriodicTasks {
  /// Names the top-level function the system starts a run in.
  Future<void> initialize(Function dispatcher);

  /// Asks for a run no earlier than [interval] from now, and about that often
  /// after. A task already registered under [name] stays as it is.
  Future<void> register(String name, {required Duration interval});

  Future<void> cancel(String name);
}

/// [PeriodicTasks] on the `workmanager` plugin.
class WorkmanagerTasks implements PeriodicTasks {
  @override
  Future<void> initialize(Function dispatcher) =>
      Workmanager().initialize(dispatcher);

  @override
  Future<void> register(
    String name, {
    required Duration interval,
  }) => Workmanager().registerPeriodicTask(
    name,
    name,
    // Android reads the frequency; iOS reads the delay, which BGTaskScheduler
    // takes as the earliest start and the plugin repeats after each run.
    frequency: interval,
    initialDelay: interval,
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  @override
  Future<void> cancel(String name) => Workmanager().cancelByUniqueName(name);
}

/// Registers the periodic run once the app is signed in, and cancels it when
/// the session ends: sign-out, expiry or a change of server.
class BackgroundScheduler {
  BackgroundScheduler({
    required this._changes,
    required this._state,
    required this._ended,
    PeriodicTasks? tasks,
    this.events = noopAppEventLogger,
    TargetPlatform? platform,
    Future<String> Function()? name,
    this._dispatcher = backgroundRefreshDispatcher,
  }) : _tasks = tasks ?? WorkmanagerTasks(),
       _platform = platform ?? defaultTargetPlatform,
       _name = name ?? backgroundRefreshName;

  /// Follows [auth]: a run is wanted while it is ready, and ends with its
  /// sign-outs.
  factory BackgroundScheduler.forAuth(
    AuthController auth, {
    AppEventLogger events = noopAppEventLogger,
  }) => BackgroundScheduler(
    changes: auth,
    state: () => auth.state,
    ended: auth.signedOut,
    events: events,
  );

  final Listenable _changes;
  final HermesConnectionState Function() _state;
  final Stream<void> _ended;
  final PeriodicTasks _tasks;
  final AppEventLogger events;
  final TargetPlatform _platform;
  final Future<String> Function() _name;
  final void Function() _dispatcher;

  StreamSubscription<void>? _signedOut;
  var _registered = false;
  var _initialized = false;
  var _disposed = false;

  /// Phones only: other platforms never schedule a run.
  bool get _supported =>
      !kIsWeb &&
      (_platform == TargetPlatform.iOS || _platform == TargetPlatform.android);

  void start() {
    if (!_supported) return;
    _signedOut = _ended.listen((_) => unawaited(_cancel()));
    _changes.addListener(_onAuth);
    _onAuth();
  }

  void _onAuth() {
    if (_state() == HermesConnectionState.ready && !_registered) {
      _registered = true;
      unawaited(_register());
    }
  }

  Future<void> _register() async {
    try {
      if (!_initialized) {
        await _tasks.initialize(_dispatcher);
        _initialized = true;
      }
      // A sign-out while this was under way cancels after it, not before.
      if (_disposed || !_registered) return;
      await _tasks.register(
        await _name(),
        interval: kBackgroundRefreshInterval,
      );
    } on Object catch (error) {
      _registered = false;
      _log('background.refresh.schedule_failed', error);
    }
  }

  Future<void> _cancel() async {
    _registered = false;
    try {
      await _tasks.cancel(await _name());
    } on Object catch (error) {
      _log('background.refresh.schedule_failed', error);
    }
  }

  void _log(String name, Object error) {
    try {
      events(name, {
        'error.type': error.runtimeType.toString(),
        'platform': _platform.name,
      });
    } on Object {
      // Telemetry must not break the app.
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_signedOut?.cancel());
    if (_supported) _changes.removeListener(_onAuth);
  }
}

/// Cancels the periodic run from a background isolate that found nobody
/// signed in. The app in front registers it again on the next sign-in.
Future<void> cancelBackgroundRefresh({PeriodicTasks? tasks}) async {
  try {
    await (tasks ?? WorkmanagerTasks()).cancel(await backgroundRefreshName());
  } on Object {
    // The next run finds nobody signed in again and tries once more.
  }
}
