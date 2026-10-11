/// What every Dart entry point of a background engine (a scheduled task, an
/// App Intent, a notification action) sets up before it talks to Hermes.
library;

import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:workmanager/workmanager.dart';

import '../intents/request_intents.dart';
import '../telemetry/telemetry.dart';
import '../telemetry/telemetry_config.dart';
import 'background_refresh.dart';
import 'headless_hermes.dart';

/// How long telemetry may take to start: a run has about 30 seconds.
const _telemetryBudget = Duration(seconds: 3);

/// How long sending the run's telemetry may take once the run is over.
const _flushBudget = Duration(seconds: 2);

Telemetry? _telemetry;
Future<void>? _prepared;

/// Readies the isolate: bindings, plugins and telemetry. Call it first from
/// each `@pragma('vm:entry-point')` function; later calls return the first.
Future<void> prepareBackgroundIsolate() => _prepared ??= _prepare();

Future<void> _prepare() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    _telemetry = await Telemetry.initialize(TelemetryConfig.fromEnvironment())
        .timeout(_telemetryBudget);
  } on Object {
    // Telemetry must never keep background work from running.
  }
}

/// The telemetry of a connection made in this isolate: the one
/// [prepareBackgroundIsolate] set up, or nothing before that.
ConnectionTelemetry backgroundTelemetry(Map<String, Object> serverAttributes) =>
    _telemetry?.forConnection(serverAttributes) ?? const ConnectionTelemetry();

/// How long the whole background task, from readying the isolate to the last
/// telemetry, may take. iOS allows about 30 seconds and workmanager's
/// expiration handler only logs, so the engine's start-up is left outside it.
const kBackgroundTaskBudget = Duration(seconds: 25);

/// Sends what the run recorded before the system suspends the process.
Future<void> flushBackgroundTelemetry() async {
  try {
    await _telemetry?.flush();
  } on Object {
    // Telemetry must never fail a background run.
  }
}

/// What the periodic background run starts in: a task of the system's
/// scheduler, in an engine of its own.
@pragma('vm:entry-point')
void backgroundRefreshDispatcher() {
  Workmanager().executeTask((task, input) => backgroundRefreshTask());
}

/// What the Runner starts to serve "Pending Requests" and "Answer Approval":
/// an engine that answers `hermes_app/request_intents` and says when it is
/// ready.
@pragma('vm:entry-point')
Future<void> requestIntentsMain() async {
  await prepareBackgroundIsolate();
  await RequestIntentsChannel(RequestIntents()).serve();
}

/// One background run: readies the isolate, refreshes, and sends the
/// telemetry, all within [budget]. The run gets what is left after the
/// isolate is ready, less the [closeGrace] its wind-down may wait and the
/// [flushBudget]. Always true, whatever happened: failing the task would make
/// iOS less willing to run it again, and a failure is in the telemetry
/// already.
Future<bool> backgroundRefreshTask({
  Duration budget = kBackgroundTaskBudget,
  Duration closeGrace = const Duration(seconds: 3),
  Duration flushBudget = _flushBudget,
  Future<void> Function()? prepare,
  Future<void> Function(Duration timeout, Duration closeGrace)? run,
  Future<void> Function()? flush,
}) async {
  final started = DateTime.now();
  try {
    await (prepare ?? prepareBackgroundIsolate)();
    final left = budget - DateTime.now().difference(started);
    final runBudget = left - closeGrace - flushBudget;
    await (run ?? _refresh)(
      runBudget < _minimumRun ? _minimumRun : runBudget,
      closeGrace,
    );
  } on Object {
    // The run reports its own failures.
  }
  try {
    await (flush ?? flushBackgroundTelemetry)().timeout(flushBudget);
  } on Object {
    // Telemetry must never fail a background run.
  }
  return true;
}

/// Less than this is not worth starting a run for; the run is cut off by its
/// own timeout anyway.
const _minimumRun = Duration(milliseconds: 500);

Future<void> _refresh(Duration timeout, Duration closeGrace) =>
    runBackgroundRefresh(
      deps: BackgroundRefreshDeps(
        timeout: timeout,
        headless: HeadlessDeps(closeGrace: closeGrace),
      ),
    );
