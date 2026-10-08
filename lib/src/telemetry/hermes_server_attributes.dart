/// The `hermes.*` attributes that describe a Hermes server, read from its
/// `GET /api/status` answer.
///
/// Reads only these named fields, so the paths, ports and profile names an
/// ungated server adds to its answer never reach telemetry. A field that is
/// missing or has an unexpected type is left out; this never throws.
Map<String, Object> hermesServerAttributes(Map<String, dynamic> status) {
  final profiles = _stringList(status['profiles']);
  final gatewayMode = _string(status['gateway_mode']);
  return {
    'hermes.version': ?_string(status['version']),
    'hermes.release_date': ?_string(status['release_date']),
    'hermes.config_version': ?_int(status['config_version']),
    'hermes.install_id': ?_string(status['install_id']),
    'hermes.auth.required': ?_bool(status['auth_required']),
    'hermes.auth.providers': ?_stringList(status['auth_providers']),
    'hermes.gateway.mode': ?gatewayMode,
    // Hermes sends an empty list when it could not read its profiles.
    if (gatewayMode != 'unknown') 'hermes.profile.count': ?profiles?.length,
    'hermes.gateway.state': ?_string(status['gateway_state']),
    'hermes.overall': ?_string(status['overall']),
  };
}

String? _string(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;

bool? _bool(Object? value) => value is bool ? value : null;

List<String>? _stringList(Object? value) =>
    value is List && value.every((item) => item is String)
    ? List<String>.unmodifiable(value)
    : null;
