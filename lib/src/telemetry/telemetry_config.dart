/// Telemetry settings compiled into the build via `--dart-define`.
///
/// An empty [otlpEndpoint] (the default, including plain `flutter run`)
/// turns telemetry off.
class TelemetryConfig {
  const TelemetryConfig({
    required this.otlpEndpoint,
    required this.otlpHeaders,
    required this.serviceName,
    required this.serviceVersion,
    required this.deploymentEnvironment,
  });

  factory TelemetryConfig.fromEnvironment() => TelemetryConfig(
    otlpEndpoint: _endpoint,
    otlpHeaders: parseHeaders(_headers),
    serviceName: _serviceName,
    serviceVersion: _serviceVersion,
    deploymentEnvironment: _deploymentEnvironment,
  );

  static const _endpoint = String.fromEnvironment(
    'OTEL_EXPORTER_OTLP_ENDPOINT',
  );
  static const _headers = String.fromEnvironment('OTEL_EXPORTER_OTLP_HEADERS');
  static const _serviceName = String.fromEnvironment(
    'OTEL_SERVICE_NAME',
    defaultValue: 'hermes-app',
  );
  static const _serviceVersion = String.fromEnvironment('OTEL_SERVICE_VERSION');
  static const _deploymentEnvironment = String.fromEnvironment(
    'OTEL_DEPLOYMENT_ENVIRONMENT',
    defaultValue: 'development',
  );

  final String otlpEndpoint;
  final Map<String, String> otlpHeaders;
  final String serviceName;
  final String serviceVersion;
  final String deploymentEnvironment;

  bool get enabled => otlpEndpoint.isNotEmpty;

  /// Parses the `OTEL_EXPORTER_OTLP_HEADERS` format: comma separated
  /// `key=value` pairs, split on the first `=` so values may contain `=`.
  static Map<String, String> parseHeaders(String raw) {
    final headers = <String, String>{};
    for (final pair in raw.split(',')) {
      final separator = pair.indexOf('=');
      if (separator <= 0) continue;
      final key = pair.substring(0, separator).trim();
      if (key.isEmpty) continue;
      headers[key] = pair.substring(separator + 1).trim();
    }
    return headers;
  }
}
