import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PKCE (RFC 7636) code_verifier / code_challenge pair for the S256 method,
/// plus a CSRF `state` value. Mirrors Hermes Desktop's `generatePkcePair` /
/// `generateState` (apps/desktop/electron/native-oauth.ts) so this app's
/// native login flow matches the reference implementation byte for byte.
class PkcePair {
  const PkcePair({required this.verifier, required this.challenge});

  /// 32 random bytes, base64url-encoded (43 chars — within RFC 7636's 43-128
  /// range).
  factory PkcePair.generate() {
    final verifier = _base64UrlNoPad(_randomBytes(32));
    final challenge = _base64UrlNoPad(
      Uint8List.fromList(sha256.convert(ascii.encode(verifier)).bytes),
    );
    return PkcePair(verifier: verifier, challenge: challenge);
  }

  final String verifier;
  final String challenge;
}

/// A high-entropy CSRF `state` value for the loopback round trip.
String generatePkceState() => _base64UrlNoPad(_randomBytes(24));

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

/// base64url without `=` padding, per RFC 7636 §4.
String _base64UrlNoPad(Uint8List bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
