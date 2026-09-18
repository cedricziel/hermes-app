/// One entry from `GET /api/auth/providers` — a sign-in option the
/// dashboard's auth gate advertises (an OIDC/OAuth identity provider, or the
/// bundled username/password provider).
class AuthProviderInfo {
  const AuthProviderInfo({
    required this.name,
    required this.displayName,
    required this.supportsPassword,
  });

  factory AuthProviderInfo.fromJson(Map<String, dynamic> json) {
    return AuthProviderInfo(
      name: json['name'] as String? ?? '',
      displayName:
          json['display_name'] as String? ?? json['name'] as String? ?? '',
      supportsPassword: json['supports_password'] as bool? ?? false,
    );
  }

  final String name;
  final String displayName;
  final bool supportsPassword;
}
