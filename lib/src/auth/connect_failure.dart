import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show TargetPlatform;

enum ConnectFailureKind {
  dns,
  refused,
  timeout,

  /// The handshake failed for a reason other than the certificate, such as
  /// `https://` sent to a port that speaks plain HTTP.
  tls,

  /// The device does not trust the server's certificate.
  certificate,
  http,
  other,
}

enum HostKind { tailnet, private, local, public }

/// Why a request to the server failed, and what kind of address it went to.
class ConnectFailure {
  const ConnectFailure({
    required this.kind,
    required this.hostKind,
    this.retryable = false,
  });

  final ConnectFailureKind kind;
  final HostKind hostKind;

  /// The network, not the server, is the likely cause, so asking again once
  /// the network changes can succeed.
  final bool retryable;
}

const _refusedCodes = {61, 111, 10061};
const _unreachableCodes = {51, 65, 101, 113, 10051, 10065};

ConnectFailure classifyConnectFailure(DioException e, Uri uri) {
  final hostKind = classifyHost(uri.host);
  final kind = switch (e.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => ConnectFailureKind.timeout,
    DioExceptionType.badResponse => ConnectFailureKind.http,
    DioExceptionType.badCertificate => ConnectFailureKind.certificate,
    _ => _kindOfError(e.error),
  };
  final retryable = switch (kind) {
    ConnectFailureKind.dns ||
    ConnectFailureKind.refused ||
    ConnectFailureKind.timeout => true,
    ConnectFailureKind.other => e.type == DioExceptionType.connectionError,
    ConnectFailureKind.tls ||
    ConnectFailureKind.certificate ||
    ConnectFailureKind.http => false,
  };
  return ConnectFailure(kind: kind, hostKind: hostKind, retryable: retryable);
}

/// Whether a TLS failure is the device not trusting the server's certificate.
bool isCertificateFailure(TlsException error) =>
    '${error.message} ${error.osError?.message ?? ''}'.contains(
      'CERTIFICATE_VERIFY_FAILED',
    );

ConnectFailureKind _kindOfError(Object? error) {
  if (error is TlsException) {
    return isCertificateFailure(error)
        ? ConnectFailureKind.certificate
        : ConnectFailureKind.tls;
  }
  if (error is SocketException) {
    if (error.message.contains('host lookup')) return ConnectFailureKind.dns;
    final code = error.osError?.errorCode;
    if (_refusedCodes.contains(code)) return ConnectFailureKind.refused;
    if (_unreachableCodes.contains(code)) return ConnectFailureKind.timeout;
  }
  return ConnectFailureKind.other;
}

HostKind classifyHost(String host) {
  final name = host.toLowerCase();
  if (name.endsWith('.ts.net')) return HostKind.tailnet;
  if (name.endsWith('.local')) return HostKind.local;
  final parts = name.split('.');
  if (parts.length != 4) return HostKind.public;
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((o) => o == null || o < 0 || o > 255)) {
    return HostKind.public;
  }
  final [a, b, _, _] = octets.cast<int>();
  if (a == 100 && b >= 64 && b <= 127) return HostKind.tailnet;
  if (a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168)) {
    return HostKind.private;
  }
  return HostKind.public;
}

/// The error message for [failure] when its kind needs words of its own,
/// or null to keep the request's own message.
String? connectFailureMessage(ConnectFailure failure) => switch (failure.kind) {
  ConnectFailureKind.certificate =>
    "This device doesn't trust the server's certificate.",
  ConnectFailureKind.tls => 'The secure connection to the server failed.',
  _ => null,
};

/// A line below the error message on what to check next, or null when there
/// is nothing to add. [vpnActive] is null where the platform cannot say.
String? connectHint(
  ConnectFailure failure, {
  required TargetPlatform platform,
  required bool? vpnActive,
}) => switch (failure.kind) {
  ConnectFailureKind.certificate => _certificateHint(platform),
  ConnectFailureKind.tls =>
    'The server did not answer with HTTPS. Check whether the address should '
        'start with http:// or https://, and that the port is the one that '
        'serves it.',
  ConnectFailureKind.refused when failure.hostKind != HostKind.public =>
    'The server answered, but nothing is listening at that address. '
        'Check that the dashboard is running and bound to it.',
  ConnectFailureKind.dns || ConnectFailureKind.timeout
      when failure.hostKind != HostKind.public =>
    switch (vpnActive) {
      false =>
        'No VPN is active on this device. If the server is behind one, '
            'connect to it and try again.',
      true =>
        'A VPN is active, but the server did not answer through it. '
            'Check the address and that the VPN reaches the server.',
      null => 'Is your VPN connected?',
    },
  _ => null,
};

/// A certificate from the user's own authority (Caddy's `tls internal`, a
/// home CA) works once [platform] trusts its root, which the browser that
/// signs in needs as well.
String _certificateHint(TargetPlatform platform) {
  final trust = switch (platform) {
    TargetPlatform.iOS =>
      'install its root certificate as a profile, then turn on full trust '
          'for it in Settings > General > About > Certificate Trust Settings',
    TargetPlatform.macOS =>
      'add its root certificate to the System keychain in Keychain Access and '
          'set it to Always Trust',
    TargetPlatform.android =>
      'install its root certificate as a CA certificate in Settings (search '
          'Settings for "CA certificate")',
    _ => "add its root certificate to this computer's trusted certificates",
  };
  return 'If the certificate comes from your own authority, such as '
      "Caddy's tls internal, $trust and try again. A certificate from a "
      "public authority, such as Tailscale HTTPS or Let's Encrypt, works "
      'without this.';
}
