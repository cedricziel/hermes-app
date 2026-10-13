import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class QueueKeys {
  Future<List<int>?> read(String account);
  Future<void> write(String account, List<int> key);
  Future<void> delete(String account);
}

class SecureQueueKeys implements QueueKeys {
  SecureQueueKeys({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: 'hermes_queue_v1',
              resetOnError: false,
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
              usesDataProtectionKeychain: !kDebugMode,
            ),
          );
  final FlutterSecureStorage _storage;
  String _name(String account) => 'hermes.queue.key.v1.$account';
  @override
  Future<List<int>?> read(String account) async {
    final raw = await _storage.read(key: _name(account));
    return raw == null ? null : base64Decode(raw);
  }

  @override
  Future<void> write(String account, List<int> key) =>
      _storage.write(key: _name(account), value: base64Encode(key));
  @override
  Future<void> delete(String account) => _storage.delete(key: _name(account));
}
