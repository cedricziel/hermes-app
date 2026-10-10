import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/auth/token_store.dart';
import 'package:hermes_app/src/models/hermes_session.dart';

import 'support/recorded_events.dart';

class _FakeStorage extends FlutterSecureStorage {
  _FakeStorage({this.value, this.readError, this.deleteError, this.writeError});

  String? value;
  final Object? readError;
  final Object? deleteError;
  final Object? writeError;
  final writes = <String?>[];

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
    return value;
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
  test('the session stays readable on iOS while the phone is locked', () {
    // A watch request wakes the phone app in the background, usually locked.
    final options = TokenStore.defaultStorage.iOptions;

    expect(
      options.accessibility,
      KeychainAccessibility.first_unlock_this_device,
    );
  });

  test(
    'a stored session is saved again once, under the current options',
    () async {
      final storage = _FakeStorage(value: _stored());
      final store = TokenStore(storage: storage);

      final first = await store.read();
      await store.read();

      expect(first?.accessToken, 'access');
      expect(storage.writes, [_stored()]);
    },
  );

  test('a session that cannot be saved again is still returned', () async {
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
        expect(storage.value, isNull);
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

    test('even when clearing the bad value also fails', () async {
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
