import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_user_certificates_android/flutter_user_certificates_android.dart';

/// Makes Dart trust the CA certificates the user installed on Android, as the
/// browser that signs in already does. Dart reads only the system store
/// there, so a server with a certificate from the user's own authority
/// (Caddy's `tls internal`, a home CA) could not be reached otherwise. iOS
/// and macOS verify against the system's trust settings and need nothing.
class UserCertificates {
  UserCertificates({
    Future<Map<String, Uint8List>?> Function()? read,
    SecurityContext? context,
  }) : _read = read ?? FlutterUserCertificatesAndroid().getUserCertificates,
       _context = context ?? SecurityContext.defaultContext;

  final Future<Map<String, Uint8List>?> Function() _read;
  final SecurityContext _context;
  final _trusted = <String>{};

  /// Trusts the installed certificates not trusted yet; call it again when
  /// the user may have installed one, such as when the app resumes. Never
  /// throws: a certificate that cannot be read is left out.
  Future<void> load() async {
    final Map<String, Uint8List>? certificates;
    try {
      certificates = await _read();
    } on Object {
      return;
    }
    for (final der in certificates?.values ?? const <Uint8List>[]) {
      final base64 = base64Encode(der);
      if (!_trusted.add(base64)) continue;
      try {
        _context.setTrustedCertificatesBytes(utf8.encode(_pem(base64)));
      } on TlsException {
        // Malformed, or already in the store from an earlier engine.
      }
    }
  }
}

/// Loads the user's certificates into this isolate's default context on
/// Android, giving up after two seconds, and does nothing elsewhere.
Future<void> trustUserCertificates() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  await (_isolateCertificates ??= UserCertificates()).load().timeout(
    const Duration(seconds: 2),
    onTimeout: () {},
  );
}

UserCertificates? _isolateCertificates;

String _pem(String base64) {
  final lines = [
    for (var i = 0; i < base64.length; i += 64)
      base64.substring(i, (i + 64).clamp(0, base64.length)),
  ];
  return '-----BEGIN CERTIFICATE-----\n'
      '${lines.join('\n')}\n'
      '-----END CERTIFICATE-----\n';
}
