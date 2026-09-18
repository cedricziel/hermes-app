import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/hermes_session.dart';

/// Persists the native-app token set in the OS keychain (iOS/macOS) or
/// Keystore-backed encrypted prefs (Android) — the same trust boundary
/// Hermes Desktop uses for its own token store, and never a browser cookie.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _sessionKey = 'hermes.session.v1';

  final FlutterSecureStorage _storage;

  Future<HermesSession?> read() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return HermesSession.fromStorageJson(json);
    } on FormatException {
      // Corrupt/unparseable entry — treat as signed out rather than crash.
      await clear();
      return null;
    }
  }

  Future<void> write(HermesSession session) {
    return _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toStorageJson()),
    );
  }

  Future<void> clear() => _storage.delete(key: _sessionKey);
}
