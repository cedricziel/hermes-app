/// Asks the system for periodic background runs while someone is signed in.
///
/// iOS (BGTaskScheduler) and Android (WorkManager) decide when, and whether,
/// a run happens; nothing here promises any timing.
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show Listenable, TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workmanager/workmanager.dart';

import '../auth/auth_controller.dart';
import 'app_presence.dart';
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

  /// Whether a run is registered under [name]; null where the system cannot
  /// say.
  Future<bool?> isScheduled(String name);
}

/// Whether the user lets the app refresh in the background (iOS).
abstract interface class BackgroundRefreshStatus {
  /// `available`, `denied` or `restricted`; null where there is no such
  /// setting.
  Future<String?> read();
}

/// [BackgroundRefreshStatus] over the Runner's channel. It is asked on iOS
/// only; elsewhere the channel is not there.
class ChannelRefreshStatus implements BackgroundRefreshStatus {
  static const _channel = MethodChannel('hermes_app/background_refresh');

  @override
  Future<String?> read() async {
    try {
      return await _channel.invokeMethod<String>('status');
    } on Object {
      return null;
    }
  }
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

  @override
  Future<bool?> isScheduled(String name) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await Workmanager().isScheduledByUniqueName(name);
      }
      // BGTaskScheduler has no query of its own; the plugin lists its pending
      // requests as text.
      return (await Workmanager().printScheduledTasks()).contains(name);
    } on Object {
      return null;
    }
  }
}

/// Registers the periodic run once the app is signed in, checks on every
/// resume that the system still has it, and cancels it when the session
/// ends: sign-out, expiry or a change of server.
class BackgroundScheduler with WidgetsBindingObserver {
  BackgroundScheduler({
    required this._changes,
    required this._state,
    required this._ended,
    PeriodicTasks? tasks,
    this.events = noopAppEventLogger,
    TargetPlatform? platform,
    Future<String> Function()? name,
    this._dispatcher = backgroundRefreshDispatcher,
    BackgroundRefreshStatus? status,
    AppPresence? presence,
    this._observeLifecycle = true,
  }) : _tasks = tasks ?? WorkmanagerTasks(),
       _platform = platform ?? defaultTargetPlatform,
       _name = name ?? backgroundRefreshName,
       _status = status ?? ChannelRefreshStatus(),
       _presence = presence ?? AppPresence();

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
  final BackgroundRefreshStatus _status;
  final AppPresence _presence;
  final bool _observeLifecycle;

  StreamSubscription<void>? _signedOut;
  var _registered = false;
  var _initialized = false;
  var _disposed = false;
  var _statusLogged = false;

  /// Moves on with every register and cancel, so one that was waiting for
  /// the platform gives way to the one that came after it.
  var _generation = 0;

  /// Phones only: other platforms never schedule a run.
  bool get _supported =>
      !kIsWeb &&
      (_platform == TargetPlatform.iOS || _platform == TargetPlatform.android);

  void start() {
    if (!_supported) return;
    _presence.start();
    _signedOut = _ended.listen((_) => unawaited(_cancel()));
    _changes.addListener(_onAuth);
    if (_observeLifecycle) WidgetsBinding.instance.addObserver(this);
    _onAuth();
  }

  bool get _signedIn => _state() == HermesConnectionState.ready;

  void _onAuth() {
    if (!_signedIn) return;
    if (!_registered) unawaited(_register());
    unawaited(_logStatus());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _supported && _signedIn) {
      unawaited(_verify());
    }
  }

  /// The system can drop a task (a cleared app state, a reinstall of the
  /// work database), and nothing else would put it back.
  Future<void> _verify() async {
    if (!_registered) return _register();
    try {
      final scheduled = await _tasks.isScheduled(await _name());
      if (scheduled == false && _signedIn && !_disposed) await _register();
    } on Object catch (error) {
      _log('background.refresh.schedule_failed', error);
    }
  }

  Future<void> _register() async {
    final generation = ++_generation;
    _registered = true;
    try {
      if (!_initialized) {
        await _tasks.initialize(_dispatcher);
        _initialized = true;
      }
      final name = await _name();
      // A sign-out while this was under way cancels after it, not before.
      if (_disposed || generation != _generation) return;
      await _tasks.register(name, interval: kBackgroundRefreshInterval);
    } on Object catch (error) {
      if (generation == _generation) _registered = false;
      _log('background.refresh.schedule_failed', error);
    }
  }

  Future<void> _cancel() async {
    _generation++;
    _registered = false;
    try {
      await _tasks.cancel(await _name());
    } on Object catch (error) {
      _log('background.refresh.schedule_failed', error);
    }
  }

  /// Once per launch, says when the user has turned Background App Refresh
  /// off for the app: without it the feature fails invisibly.
  Future<void> _logStatus() async {
    if (_statusLogged || _platform != TargetPlatform.iOS) return;
    _statusLogged = true;
    try {
      final status = await _status.read();
      if (status != null && status != 'available') {
        events('background.refresh.unavailable', {'status': status});
      }
    } on Object {
      // Telemetry must not break the app.
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
    if (_supported) {
      _changes.removeListener(_onAuth);
      _presence.dispose();
      if (_observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    }
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
