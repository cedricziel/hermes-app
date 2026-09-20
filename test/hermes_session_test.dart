import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/models/hermes_session.dart';

HermesSession _session(int expiresAt) => HermesSession(
  accessToken: 'a',
  refreshToken: 'r',
  expiresAt: expiresAt,
  provider: 'oidc',
  userId: 'u1',
);

void main() {
  final now = DateTime.utc(2026, 1, 1);
  final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;

  group('needsRefresh', () {
    test('is false when the expiry is unknown', () {
      expect(_session(0).needsRefresh(now: now), isFalse);
    });

    test('is false when the token has more than the skew left', () {
      expect(_session(nowSeconds + 120).needsRefresh(now: now), isFalse);
    });

    test('is true within the skew of expiry', () {
      expect(_session(nowSeconds + 59).needsRefresh(now: now), isTrue);
    });

    test('is true once expired', () {
      expect(_session(nowSeconds - 1).needsRefresh(now: now), isTrue);
    });
  });

  test('a token response without expires_at has an unknown expiry', () {
    final session = HermesSession.fromTokenResponse({
      'access_token': 'a',
      'refresh_token': 'r',
    });
    expect(session.expiresAt, 0);
    expect(session.needsRefresh(now: now), isFalse);
  });
}
