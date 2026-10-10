/// What every Dart entry point of a background engine (a scheduled task, an
/// App Intent, a notification action) sets up before it talks to Hermes.
library;

import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

import '../telemetry/telemetry.dart';
import '../telemetry/telemetry_config.dart';

Telemetry? _telemetry;
Future<void>? _prepared;

/// Readies the isolate: bindings, plugins and telemetry. Call it first from
/// each `@pragma('vm:entry-point')` function; later calls return the first.
Future<void> prepareBackgroundIsolate() => _prepared ??= _prepare();

Future<void> _prepare() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    _telemetry = await Telemetry.initialize(TelemetryConfig.fromEnvironment());
  } on Object {
    // Telemetry must never keep background work from running.
  }
}

/// The telemetry of a connection made in this isolate: the one
/// [prepareBackgroundIsolate] set up, or nothing before that.
ConnectionTelemetry backgroundTelemetry(Map<String, Object> serverAttributes) =>
    _telemetry?.forConnection(serverAttributes) ?? const ConnectionTelemetry();
