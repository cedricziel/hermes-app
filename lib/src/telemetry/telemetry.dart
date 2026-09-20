import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';

import 'device_attributes.dart';
import 'gateway_telemetry.dart';
import 'http_telemetry_interceptor.dart';
import 'telemetry_config.dart';
import 'telemetry_event.dart';
import 'uncaught_error_logging.dart';

/// Owns the OpenTelemetry SDK for the app.
///
/// When telemetry is off no SDK is created, so nothing is exported and no
/// `traceparent` header is added to requests.
class Telemetry {
  Telemetry._(this._sdk);

  final OTelSdk? _sdk;

  bool get enabled => _sdk != null;

  /// A malformed endpoint disables telemetry rather than failing app start.
  static Future<Telemetry> initialize(TelemetryConfig config) async {
    final endpoint = config.enabled ? Uri.tryParse(config.otlpEndpoint) : null;
    if (endpoint == null || !endpoint.hasScheme || endpoint.host.isEmpty) {
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
          attributes: await deviceAttributes(),
        ),
        otlpEndpoint: endpoint,
        otlpHeaders: config.otlpHeaders,
      ),
    );
    return Telemetry._(sdk);
  }

  /// Traces and logs every request on the Dio client it is added to.
  Interceptor? dioInterceptor() {
    final sdk = _sdk;
    if (sdk == null) return null;
    return HttpTelemetryInterceptor(sdk.getTracer(), sdk.getLogger());
  }

  /// Traces the gateway socket; does nothing when disabled.
  GatewayTelemetry gateway() => GatewayTelemetry(_sdk?.getTracer());

  /// Logs app events such as sign-in outcomes; does nothing when disabled.
  TelemetryEvent events() {
    final sdk = _sdk;
    return sdk == null
        ? ignoreTelemetryEvent
        : logTelemetryEvents(sdk.getLogger());
  }

  /// Logs uncaught Flutter and async errors; does nothing when disabled.
  void logUncaughtErrors() {
    final sdk = _sdk;
    if (sdk != null) installUncaughtErrorLogging(sdk.getLogger());
  }
}
