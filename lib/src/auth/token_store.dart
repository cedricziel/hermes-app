import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../models/hermes_session.dart';
import 'session_mutex.dart';
import 'session_mutex_stub.dart'
    if (dart.library.io) 'session_mutex_native.dart';

/// Persists the native-app token set in the OS keychain (iOS/macOS) or
/// Keystore-encrypted prefs (Android) — the same trust boundary
/// Hermes Desktop uses for its own token store, and never a browser cookie.
class TokenStore {
  TokenStore({
    FlutterSecureStorage? storage,
    SessionMutex? mutex,
    this._events = noopAppEventLogger,
  }) : _storage = storage ?? defaultStorage,
       _mutex =
           mutex ??
           (storage == null ? createSessionMutex() : MemorySessionMutex());

  final SessionMutex _mutex;
  static final _lockZone = Object();

  Future<T> _exclusive<T>(Future<T> Function() body) {
    final held = Zone.current[_lockZone];
    if (held is _HeldLock && held.active && identical(held.owner, this)) {
      return body();
    }
    return _mutex.run(() async {
      final lease = _HeldLock(this);
      try {
        return await runZoned(body, zoneValues: {_lockZone: lease});
      } finally {
        lease.active = false;
      }
    });
  }

  /// Compare and mutate under the same lock used by sign-in and sign-out.
  /// Unreadable storage never authorizes overwriting or deleting a session.
  Future<bool> replace(HermesSession expected, HermesSession? next) =>
      _exclusive(() async {
        final stored = await readState(repair: false);
        if (stored is SessionUnreadable) {
          throw StateError('Secure storage is temporarily unreadable');
        }
        // The connection validates the issuer before binding a redirected URL.
        // Compare the actual credential pair, not its potentially rebound URL.
        final current = stored.session;
        if (current == null ||
            current.refreshToken != expected.refreshToken ||
            current.accessToken != expected.accessToken ||
            current.userId != expected.userId ||
            current.provider != expected.provider) {
          return false;
        }
        if (next == null) {
          await clear();
        } else {
          await write(next);
        }
        return true;
      });

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

  Future<HermesSession?> read() async => (await readState()).session;

  /// Like [read], but says why there is no session: nothing is stored, or the
  /// keychain cannot be read right now (on iOS: before the first unlock since
  /// the device started).
  ///
  /// Reads never write or delete: another engine may rotate the session or
  /// sign out after the snapshot was read. New sign-ins and successful
  /// refreshes apply the current storage options when writing their tokens.
  /// [repair] is retained for callers that already request read-only access;
  /// both values now leave storage untouched.
  Future<SessionRead> readState({bool repair = true}) async {
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
      return SessionUnreadable(locked: _isLocked(error));
    }
    if (raw == null || raw.isEmpty) return const SessionEmpty();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('stored session is not an object');
      }
      final session = HermesSession.fromStorageJson(json);
      return SessionFound(session);
    } on Object {
      return const SessionEmpty();
    }
  }

  /// `errSecInteractionNotAllowed`: the plugin reports the status in the
  /// message and details of its "Unexpected security result code" error.
  static bool _isLocked(Object error) =>
      error is PlatformException &&
      (error.code == '-25308' ||
          error.details == -25308 ||
          (error.message?.contains('-25308') ?? false));

  Future<void> write(HermesSession session) {
    return _exclusive(
      () => _storage.write(
        key: _sessionKey,
        value: jsonEncode(session.toStorageJson()),
      ),
    );
  }

  Future<void> clear() => _exclusive(() => _storage.delete(key: _sessionKey));
}

/// What [TokenStore.readState] found.
sealed class SessionRead {
  const SessionRead();

  /// The stored session, or null when there is none to use.
  HermesSession? get session => null;
}

/// A stored session.
final class SessionFound extends SessionRead {
  const SessionFound(this.session);

  @override
  final HermesSession session;
}

/// Nothing usable is stored.
final class SessionEmpty extends SessionRead {
  const SessionEmpty();
}

/// The keychain could not be read, so nothing is known about the session.
final class SessionUnreadable extends SessionRead {
  const SessionUnreadable({this.locked = false});

  /// Whether the keychain is locked, as on iOS before the first unlock since
  /// the device started, rather than failing for another reason.
  final bool locked;
}

class _HeldLock {
  _HeldLock(this.owner);
  final TokenStore owner;
  bool active = true;
}
