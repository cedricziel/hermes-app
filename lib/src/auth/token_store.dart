import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../models/hermes_session.dart';

/// Persists the native-app token set in the OS keychain (iOS/macOS) or
/// Keystore-encrypted prefs (Android) — the same trust boundary
/// Hermes Desktop uses for its own token store, and never a browser cookie.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage, this._events = noopAppEventLogger})
    : _storage = storage ?? defaultStorage;

  /// On iOS the session stays readable while the phone is locked, once it has
  /// been unlocked since it started: a request from the watch wakes the phone
  /// app in the background, usually with the phone in a pocket.
  ///
  /// macOS only grants the data protection keychain to a team signed app, and
  /// a local debug build is signed ad hoc, so it uses the login keychain.
  @visibleForTesting
  static const defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(usesDataProtectionKeychain: !kDebugMode),
  );

  static const _sessionKey = 'hermes.session.v1';

  final FlutterSecureStorage _storage;
  final AppEventLogger _events;

  /// Whether the stored session was written again under the current options.
  bool _resaved = false;

  Future<HermesSession?> read() async {
    final String? raw;
    try {
      raw = await _storage.read(key: _sessionKey);
    } on Object catch (error) {
      try {
        _events('auth.session.read_failed', {
          'error.type': error.runtimeType.toString(),
        });
      } on Object {
        // Telemetry failure must not change session restoration.
      }
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
      final session = HermesSession.fromStorageJson(json);
      await _resaveOnce(raw);
      return session;
    } on Object {
      try {
        await clear();
      } on Object {
        // The next sign-in overwrites the entry.
      }
      return null;
    }
  }

  /// A session saved by an older version keeps the options it was saved
  /// with until it is written again.
  Future<void> _resaveOnce(String raw) async {
    if (_resaved) return;
    _resaved = true;
    try {
      await _storage.write(key: _sessionKey, value: raw);
    } on Object {
      // The next token refresh writes it again.
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
