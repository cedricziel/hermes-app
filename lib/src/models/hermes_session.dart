/// A native-app token set minted by `/auth/native/token` (or rotated by
/// `/auth/native/refresh`). Stored in the OS keychain/keystore — never in a
/// browser cookie, since this app is a native RFC 8252 client, not the SPA.
class HermesSession {
  const HermesSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.provider,
    required this.userId,
  });

  factory HermesSession.fromTokenResponse(Map<String, dynamic> json) {
    final accessToken = json['access_token'] as String? ?? '';
    if (accessToken.isEmpty) {
      throw const FormatException('token response missing access_token');
    }
    return HermesSession(
      accessToken: accessToken,
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresAt: (json['expires_at'] as num?)?.toInt() ?? 0,
      provider: json['provider'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
    );
  }

  factory HermesSession.fromStorageJson(Map<String, dynamic> json) {
    return HermesSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: (json['expiresAt'] as num?)?.toInt() ?? 0,
      provider: json['provider'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
    );
  }

  final String accessToken;
  final String refreshToken;

  /// Unix seconds when [accessToken] expires, or 0 when the server did not say.
  final int expiresAt;
  final String provider;
  final String userId;

  Map<String, dynamic> toStorageJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt,
    'provider': provider,
    'userId': userId,
  };

  /// True when the access token is at or near expiry and should be refreshed
  /// before use. Mirrors the server's own 60s floor on cookie Max-Age.
  /// An unknown expiry never needs a proactive refresh; a 401 drives it.
  bool needsRefresh({int skewSeconds = 60, DateTime? now}) {
    if (expiresAt <= 0) return false;
    final nowSeconds = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return nowSeconds >= expiresAt - skewSeconds;
  }
}

/// The verified identity returned by `GET /api/auth/me`.
class HermesIdentity {
  const HermesIdentity({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.orgId,
    required this.provider,
  });

  factory HermesIdentity.fromJson(Map<String, dynamic> json) {
    return HermesIdentity(
      userId: json['user_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      orgId: json['org_id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
    );
  }

  final String userId;
  final String email;
  final String displayName;
  final String orgId;
  final String provider;
}
