import 'json_fields.dart';

/// `GET /api/status` — public, unauthenticated. Tells the app whether the
/// dashboard's auth gate is engaged and which login flows it supports before
/// any credentials are exchanged.
class HermesStatus {
  const HermesStatus({
    required this.authRequired,
    required this.authProviders,
    required this.authFlows,
    this.version,
  });

  /// Throws [FormatException] when a field has the wrong type.
  factory HermesStatus.fromJson(Map<String, dynamic> json) {
    return HermesStatus(
      authRequired: jsonField(json, 'auth_required', false),
      authProviders: jsonStringList(json, 'auth_providers'),
      authFlows: jsonStringList(json, 'auth_flows'),
      version: jsonFieldOrNull<String>(json, 'version'),
    );
  }

  /// Whether requests must be authenticated at all. False on a loopback
  /// (`127.0.0.1`) bind — the dashboard's default, unauthenticated dev mode.
  final bool authRequired;

  /// Registered session-provider names, e.g. `["basic"]` or `["nous"]`.
  final List<String> authProviders;

  /// Supported auth flows. `native_pkce` means the RFC 8252 system-browser +
  /// loopback + PKCE flow this app uses is available.
  final List<String> authFlows;

  final String? version;

  bool get supportsNativePkce => authFlows.contains('native_pkce');

  /// True only when the server names its flows and `native_pkce` isn't one of
  /// them. A server that advertises nothing is treated as unknown, not
  /// unsupported, so it isn't locked out.
  bool get lacksNativePkce => authFlows.isNotEmpty && !supportsNativePkce;
}
