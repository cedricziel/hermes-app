import 'json_fields.dart';

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
    this.serverUrl,
    this.mintedAt,
  });

  factory HermesSession.fromTokenResponse(Map<String, dynamic> json) {
    final accessToken = json['access_token'] as String? ?? '';
    if (accessToken.isEmpty) {
      throw const FormatException('token response missing access_token');
    }
    return HermesSession(
      accessToken: accessToken,
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresAt: _expiry(json['expires_at']),
      provider: json['provider'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
    );
  }

  factory HermesSession.fromStorageJson(Map<String, dynamic> json) {
    return HermesSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      expiresAt: _expiry(json['expiresAt']),
      provider: json['provider'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      serverUrl: json['serverUrl'] as String?,
      mintedAt: (json['mintedAt'] as num?)?.toInt(),
    );
  }

  /// Sessions stored before [expiresAt] became nullable hold 0 for an unknown
  /// expiry, so a non-positive value reads as unknown.
  static int? _expiry(Object? value) {
    final seconds = (value as num?)?.toInt();
    return seconds == null || seconds <= 0 ? null : seconds;
  }

  final String accessToken;
  final String refreshToken;

  /// Unix seconds when [accessToken] expires, or null when the server did not
  /// say.
  final int? expiresAt;
  final String provider;
  final String userId;

  /// The dashboard the tokens were minted by. Null for a session stored
  /// before it was recorded.
  final String? serverUrl;

  /// When this app received the tokens, in milliseconds since the epoch, so
  /// that of two pairs of one user the newer is known. Null for a session
  /// stored before it was recorded.
  final int? mintedAt;

  /// The same tokens, recorded as minted by [serverUrl].
  HermesSession boundTo(String? serverUrl) => HermesSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: expiresAt,
    provider: provider,
    userId: userId,
    serverUrl: serverUrl,
    mintedAt: mintedAt,
  );

  /// These tokens, just received by signing in at [serverUrl].
  HermesSession mintedBy(String serverUrl) => HermesSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: expiresAt,
    provider: provider,
    userId: userId,
    serverUrl: serverUrl,
    mintedAt: DateTime.now().millisecondsSinceEpoch,
  );

  /// These tokens, just received by refreshing [previous]: the same owner,
  /// whose user and provider carry over when the answer leaves them out.
  HermesSession rotatedFrom(HermesSession previous) => HermesSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    expiresAt: expiresAt,
    provider: provider.isEmpty ? previous.provider : provider,
    userId: userId.isEmpty ? previous.userId : userId,
    serverUrl: previous.serverUrl,
    mintedAt: DateTime.now().millisecondsSinceEpoch,
  );

  /// Whether this pair was received after [other], so it replaced it.
  bool isNewerThan(HermesSession other) =>
      (mintedAt ?? 0) > (other.mintedAt ?? 0);

  /// Whether [other] holds tokens of the same user on the same dashboard, so
  /// one may stand in for the other.
  bool sameOwner(HermesSession other) =>
      serverUrl != null &&
      serverUrl == other.serverUrl &&
      userId == other.userId &&
      provider == other.provider;

  Map<String, dynamic> toStorageJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt,
    'provider': provider,
    'userId': userId,
    'serverUrl': ?serverUrl,
    'mintedAt': ?mintedAt,
  };

  /// True when the access token is at or near expiry and should be refreshed
  /// before use. Mirrors the server's own 60s floor on cookie Max-Age.
  /// An unknown expiry never needs a proactive refresh; a 401 drives it.
  bool needsRefresh({int skewSeconds = 60, DateTime? now}) {
    final expiresAt = this.expiresAt;
    if (expiresAt == null) return false;
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

  /// Throws [FormatException] when a field has the wrong type.
  factory HermesIdentity.fromJson(Map<String, dynamic> json) {
    return HermesIdentity(
      userId: jsonField(json, 'user_id', ''),
      email: jsonField(json, 'email', ''),
      displayName: jsonField(json, 'display_name', ''),
      orgId: jsonField(json, 'org_id', ''),
      provider: jsonField(json, 'provider', ''),
    );
  }

  final String userId;
  final String email;
  final String displayName;
  final String orgId;
  final String provider;
}
