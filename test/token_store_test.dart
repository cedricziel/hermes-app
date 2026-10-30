import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/auth/token_store.dart';
import 'package:hermes_app/src/models/hermes_session.dart';

import 'support/recorded_events.dart';

import 'package:hermes_app/src/auth/session_mutex_native.dart';

class _FakeStorage extends FlutterSecureStorage {
  _FakeStorage({this.value, this.readError, this.deleteError, this.writeError});

  String? value;
  Object? readError;
  final Object? deleteError;
  final Object? writeError;
  final writes = <String?>[];
  void Function()? afterRead;
  Future<void> Function()? beforeWrite;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (readError != null) throw readError!; // ignore: only_throw_errors
    final snapshot = value;
    afterRead?.call();
    return snapshot;
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (writeError != null) throw writeError!; // ignore: only_throw_errors
    await beforeWrite?.call();
    writes.add(value);
    this.value = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (deleteError != null) throw deleteError!; // ignore: only_throw_errors
    value = null;
  }
}

const _session = HermesSession(
  accessToken: 'access',
  refreshToken: 'refresh',
  expiresAt: 4102444800,
  provider: 'basic',
  userId: 'u1',
);

String _stored() => jsonEncode(_session.toStorageJson());

void main() {
  test(
    'replace and logout serialize across independent store connections',
    () async {
      final dir = await Directory.systemTemp.createTemp('hermes-token-cas-');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/lock.sqlite';
      final storage = _FakeStorage(value: _stored());
      final foreground = TokenStore(
        storage: storage,
        mutex: SqliteSessionMutex(path: path),
      );
      final background = TokenStore(
        storage: storage,
        mutex: SqliteSessionMutex(path: path),
      );
      final started = Completer<void>();
      final release = Completer<void>();
      storage.beforeWrite = () async {
        started.complete();
        await release.future;
      };
      final next = HermesSession.fromStorageJson({
        ..._session.toStorageJson(),
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
      });
      final refresh = background.replace(_session, next);
      await started.future;
      final logout = foreground.clear();
      release.complete();
      expect(await refresh, isTrue);
      await logout;
      expect(storage.value, isNull);
      expect(await background.replace(_session, next), isFalse);
      expect(storage.value, isNull);
    },
  );

  test(
    'conditional writes preserve replacement accounts and unreadable storage',
    () async {
      final storage = _FakeStorage(value: _stored());
      final store = TokenStore(storage: storage);
      final other = HermesSession.fromStorageJson({
        ..._session.toStorageJson(),
        'userId': 'other',
      });
      await store.write(other);
      expect(await store.replace(_session, _session), isFalse);
      expect(await store.replace(_session, null), isFalse);
      expect((await store.read())?.userId, 'other');
      final before = storage.value;
      storage.readError = PlatformException(code: '-25308');
      await expectLater(store.replace(other, _session), throwsStateError);
      expect(storage.value, before);
    },
  );

  test('conditional mutations accept the same credentials rebound after a redirect', () async {
    final original = _session.boundTo('https://old.hermes.test');
    final rebound = original.boundTo('https://new.hermes.test');
    final rotated = HermesSession.fromStorageJson({
      ...rebound.toStorageJson(),
      'accessToken': 'new-access',
      'refreshToken': 'new-refresh',
    });
    final storage = _FakeStorage(value: jsonEncode(original.toStorageJson()));
    final store = TokenStore(storage: storage);
    expect(await store.replace(rebound, rotated), isTrue);
    expect((await store.read())?.serverUrl, rebound.serverUrl);
    await store.write(original);
    expect(await store.replace(rebound, null), isTrue);
    expect(storage.value, isNull);
  });

  for (final initial in [_stored(), '{invalid json']) {
    for (final replacement in [
      jsonEncode({
        ..._session.toStorageJson(),
        'accessToken': 'new-access',
        'refreshToken': 'new-refresh',
      }),
      null,
    ]) {
      test(
        'read preserves concurrent change: $initial -> $replacement',
        () async {
          final storage = _FakeStorage(value: initial);
          storage.afterRead = () => storage.value = replacement;
          await TokenStore(storage: storage).readState();
          expect(storage.value, replacement);
          expect(storage.writes, isEmpty);
        },
      );
    }
  }

  test('the session stays readable on iOS while the phone is locked', () {
    // A watch request wakes the phone app in the background, usually locked.
    final options = TokenStore.defaultStorage.iOptions;

    expect(
      options.accessibility,
      KeychainAccessibility.first_unlock_this_device,
    );
  });

  test('reading a stored session never writes it back', () async {
    final storage = _FakeStorage(value: _stored());
    final store = TokenStore(storage: storage);

    final first = await store.read();
    await store.read();

    expect(first?.accessToken, 'access');
    expect(storage.writes, isEmpty);
  });

  test('a session stays readable when writes are unavailable', () async {
    final storage = _FakeStorage(
      value: _stored(),
      writeError: PlatformException(code: '-25299'),
    );

    expect((await TokenStore(storage: storage).read())?.accessToken, 'access');
  });

  test('a debug build keeps the session in the login keychain on macOS', () {
    // An ad hoc signed debug build may not use the data protection keychain.
    final options = TokenStore.defaultStorage.mOptions as MacOsOptions;

    expect(options.usesDataProtectionKeychain, isFalse);
  });

  test(
    'records keychain read failure without exception details or tokens',
    () async {
      final events = RecordedEvents();
      final storage = _FakeStorage(
        value: _stored(),
        readError: PlatformException(
          code: '-25308',
          message: 'private details',
        ),
      );

      final session = await TokenStore(
        storage: storage,
        events: events.call,
      ).read();

      expect(session, isNull);
      expect(storage.value, _stored());
      expect(events.named('auth.session.read_failed'), [
        {'error.type': 'PlatformException'},
      ]);
    },
  );

  test(
    'telemetry failure leaves an unreadable stored session untouched',
    () async {
      final storage = _FakeStorage(
        value: _stored(),
        readError: PlatformException(code: '-25308'),
      );
      final store = TokenStore(
        storage: storage,
        events: (name, [attributes = const {}]) =>
            throw StateError('logger failed'),
      );

      expect(await store.read(), isNull);
      expect(storage.value, _stored());
    },
  );

  group('TokenStore.read treats an unreadable session as signed out', () {
    for (final entry in {
      'a JSON array': '[1, 2]',
      'a JSON string': '"token"',
      'a JSON number': '42',
      'invalid JSON': '{not json',
      'a field of the wrong type': '{"accessToken": 7}',
    }.entries) {
      test('when the stored value is ${entry.key}', () async {
        final storage = _FakeStorage(value: entry.value);

        expect(await TokenStore(storage: storage).read(), isNull);
        expect(storage.value, entry.value);
      });
    }

    test(
      'when the keychain throws, and leaves the stored value alone',
      () async {
        final storage = _FakeStorage(
          value: '{}',
          readError: PlatformException(code: '-25308'),
        );

        expect(await TokenStore(storage: storage).read(), isNull);
        expect(storage.value, '{}');
      },
    );

    test('without trying to clear the bad value', () async {
      final storage = _FakeStorage(
        value: '[]',
        deleteError: PlatformException(code: '-25308'),
      );

      expect(await TokenStore(storage: storage).read(), isNull);
    });
  });

  group('TokenStore.readState', () {
    test('tells a stored session from an empty store', () async {
      final found = await TokenStore(storage: _FakeStorage(value: _stored()))
          .readState();
      final empty = await TokenStore(storage: _FakeStorage()).readState();

      expect((found as SessionFound).session.accessToken, 'access');
      expect(empty, isA<SessionEmpty>());
    });

    test('tells a keychain that cannot be read from an empty one', () async {
      final storage = _FakeStorage(
        value: _stored(),
        readError: PlatformException(code: '-25308'),
      );

      expect(
        await TokenStore(storage: storage).readState(),
        isA<SessionUnreadable>(),
      );
      expect(storage.value, _stored());
    });

    test('knows a locked keychain from another read failure', () async {
      final locked = await TokenStore(
        storage: _FakeStorage(
          readError: PlatformException(
            code: 'Unexpected security result code',
            message: 'Code: -25308, Message: User interaction is not allowed.',
          ),
        ),
      ).readState();
      final other = await TokenStore(
        storage: _FakeStorage(readError: PlatformException(code: 'other')),
      ).readState();

      expect((locked as SessionUnreadable).locked, isTrue);
      expect((other as SessionUnreadable).locked, isFalse);
    });

    test('without repair neither saves nor clears what it reads', () async {
      final good = _FakeStorage(value: _stored());
      final bad = _FakeStorage(value: '{not json');

      final found = await TokenStore(storage: good).readState(repair: false);
      final empty = await TokenStore(storage: bad).readState(repair: false);

      expect(found, isA<SessionFound>());
      expect(good.writes, isEmpty);
      expect(empty, isA<SessionEmpty>());
      expect(bad.value, '{not json');
    });
  });
}
