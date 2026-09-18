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

  factory HermesStatus.fromJson(Map<String, dynamic> json) {
    return HermesStatus(
      authRequired: json['auth_required'] as bool? ?? false,
      authProviders: (json['auth_providers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      authFlows: (json['auth_flows'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      version: json['version'] as String?,
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
}
