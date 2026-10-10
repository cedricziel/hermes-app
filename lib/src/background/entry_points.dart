/// What every Dart entry point of a background engine (a scheduled task, an
/// App Intent, a notification action) sets up before it talks to Hermes.
library;

import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:workmanager/workmanager.dart';

import '../telemetry/telemetry.dart';
import '../telemetry/telemetry_config.dart';
import 'background_refresh.dart';

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

/// Sends what the run recorded before the system suspends the process.
Future<void> flushBackgroundTelemetry() async {
  try {
    await _telemetry?.flush().timeout(_flushBudget);
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

/// One background run: readies the isolate, refreshes, and sends the
/// telemetry. Always true, whatever happened: failing the task would make iOS
/// less willing to run it again, and a failure is in the telemetry already.
Future<bool> backgroundRefreshTask({
  Future<void> Function()? prepare,
  Future<void> Function()? run,
  Future<void> Function()? flush,
}) async {
  try {
    await (prepare ?? prepareBackgroundIsolate)();
    await (run ?? runBackgroundRefresh)();
  } on Object {
    // The run reports its own failures.
  }
  await (flush ?? flushBackgroundTelemetry)();
  return true;
}
