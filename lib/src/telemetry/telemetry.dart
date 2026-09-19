import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_otel_instrumentation_dio/flutter_otel_instrumentation_dio.dart';

import 'telemetry_config.dart';

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
        ),
        otlpEndpoint: endpoint,
        otlpHeaders: config.otlpHeaders,
      ),
    );
    return Telemetry._(sdk);
  }

  /// Logs and traces every request on the Dio client it is added to.
  Interceptor? dioInterceptor() {
    final sdk = _sdk;
    if (sdk == null) return null;
    return DioOTelInterceptor(sdk.getLogger(), tracer: sdk.getTracer());
  }
}
