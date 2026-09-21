import 'package:dart_otel_instrumentation_dio/dart_otel_instrumentation_dio.dart';
import 'package:dart_otel_instrumentation_messaging/dart_otel_instrumentation_messaging.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_otel_device_info/flutter_otel_device_info.dart';

import 'telemetry_config.dart';

/// Owns the OpenTelemetry SDK for the app.
///
/// When telemetry is off no SDK is created, so nothing is exported and no
/// `traceparent` header is added to requests.
// Streaming a reply sends one delta per chunk; a span each would drown the
// rest, so the events that mark its start, tools and end stand for it.
const _skippedGatewayEvents = {'message.delta'};

const _knownGatewayEvents = {
  'message.start',
  'message.complete',
  'tool.start',
  'tool.complete',
  'session.title',
  'sessions.changed',
  'approval.request',
  'approval.expire',
  'clarify.request',
  'clarify.expire',
};

/// How the chat gateway socket is traced, on [tracer] or, when null, nowhere.
MessagingConnectionTracer gatewayTracer(Tracer? tracer) =>
    MessagingConnectionTracer(
      tracer,
      system: 'hermes.gateway',
      jsonRpc: true,
      skippedNames: _skippedGatewayEvents,
      knownEvents: _knownGatewayEvents,
    );

class Telemetry {
  Telemetry._(this._sdk);

  final OTelSdk? _sdk;

  bool get enabled => _sdk != null;

  /// An unusable endpoint disables telemetry rather than failing app start.
  static Future<Telemetry> initialize(TelemetryConfig config) async {
    final endpoint = config.enabled ? Uri.tryParse(config.otlpEndpoint) : null;
    if (endpoint == null || !isExportableEndpoint(endpoint)) {
      return Telemetry._(null);
    }

    final sdk = await OTelSdk.initialize(
      OTelSdkConfig(
        resource: OTelResource(
          serviceName: config.serviceName,
          serviceVersion: config.serviceVersion.isEmpty
              ? null
              : config.serviceVersion,
          deploymentEnvironment: config.deploymentEnvironment,
          attributes: await detectDeviceAttributes(),
        ),
        otlpEndpoint: endpoint,
        otlpHeaders: config.otlpHeaders,
      ),
    );
    return Telemetry._(sdk);
  }

  /// The export carries a bearer header, so only https is allowed. Plain http
  /// is accepted for loopback hosts, where the traffic never leaves the device.
  @visibleForTesting
  static bool isExportableEndpoint(Uri endpoint) {
    if (endpoint.host.isEmpty) return false;
    return switch (endpoint.scheme) {
      'https' => true,
      'http' => _loopbackHosts.contains(endpoint.host),
      _ => false,
    };
  }

  static const _loopbackHosts = {'localhost', '127.0.0.1', '::1'};

  /// Traces and logs every request on the Dio client it is added to.
  Interceptor? dioInterceptor() {
    final sdk = _sdk;
    if (sdk == null) return null;
    return DioOTelInterceptor.privacy(sdk.getLogger(), tracer: sdk.getTracer());
  }

  /// Traces the gateway socket; does nothing when disabled.
  MessagingConnectionTracer gateway() => gatewayTracer(_sdk?.getTracer());

  /// Logs app events such as sign-in outcomes; does nothing when disabled.
  AppEventLogger events() {
    final sdk = _sdk;
    return sdk == null ? noopAppEventLogger : appEventLogger(sdk.getLogger());
  }

  /// Logs uncaught Flutter and async errors; does nothing when disabled.
  void logUncaughtErrors() {
    final sdk = _sdk;
    if (sdk != null) installUncaughtErrorLogging(sdk.getLogger());
  }
}
