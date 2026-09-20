import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/auth/token_store.dart';

class _FakeStorage extends FlutterSecureStorage {
  _FakeStorage({this.value, this.readError, this.deleteError});

  String? value;
  final Object? readError;
  final Object? deleteError;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (readError != null) throw readError!;
    return value;
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (deleteError != null) throw deleteError!;
    value = null;
  }
}

void main() {
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

    test('when the keychain throws', () async {
      final storage = _FakeStorage(
        value: '{}',
        readError: PlatformException(code: '-25308'),
      );

      expect(await TokenStore(storage: storage).read(), isNull);
    });

    test('even when clearing the bad value also fails', () async {
      final storage = _FakeStorage(
        value: '[]',
        deleteError: PlatformException(code: '-25308'),
      );

      expect(await TokenStore(storage: storage).read(), isNull);
    });
  });
}
