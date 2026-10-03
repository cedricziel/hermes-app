import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/hermes_session.dart';

/// Persists the native-app token set in the OS keychain (iOS/macOS) or
/// Keystore-encrypted prefs (Android) — the same trust boundary
/// Hermes Desktop uses for its own token store, and never a browser cookie.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? defaultStorage;

  /// macOS only grants the data protection keychain to a team signed app, and
  /// a local debug build is signed ad hoc, so it uses the login keychain.
  @visibleForTesting
  static const defaultStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: !kDebugMode),
  );

  static const _sessionKey = 'hermes.session.v1';

  final FlutterSecureStorage _storage;

  Future<HermesSession?> read() async {
    final String? raw;
    try {
      raw = await _storage.read(key: _sessionKey);
    } on Object {
      // A keychain that cannot be read right now (locked, unavailable) says
      // nothing about the stored session, so it is left alone.
      return null;
    }
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('stored session is not an object');
      }
      return HermesSession.fromStorageJson(json);
    } on Object {
      try {
        await clear();
      } on Object {
        // The next sign-in overwrites the entry.
      }
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
