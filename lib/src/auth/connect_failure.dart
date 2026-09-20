import 'dart:io';

import 'package:dio/dio.dart';

enum ConnectFailureKind { dns, refused, timeout, tls, http, other }

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
    DioExceptionType.badCertificate => ConnectFailureKind.tls,
    _ => _kindOfError(e.error),
  };
  final retryable = switch (kind) {
    ConnectFailureKind.dns ||
    ConnectFailureKind.refused ||
    ConnectFailureKind.timeout => true,
    ConnectFailureKind.other => e.type == DioExceptionType.connectionError,
    ConnectFailureKind.tls || ConnectFailureKind.http => false,
  };
  return ConnectFailure(kind: kind, hostKind: hostKind, retryable: retryable);
}

ConnectFailureKind _kindOfError(Object? error) {
  if (error is TlsException) return ConnectFailureKind.tls;
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

/// A line asking about the VPN, for a failure to an address that is normally
/// only reachable over one. [vpnActive] is null where the platform cannot say.
String? vpnHint(ConnectFailure failure, {required bool? vpnActive}) {
  if (failure.hostKind == HostKind.public) return null;
  switch (failure.kind) {
    case ConnectFailureKind.refused:
      return 'The server answered, but nothing is listening at that address. '
          'Check that the dashboard is running and bound to it.';
    case ConnectFailureKind.dns:
    case ConnectFailureKind.timeout:
      return switch (vpnActive) {
        false =>
          'No VPN is active on this device. If the server is behind one, '
              'connect to it and try again.',
        true =>
          'A VPN is active, but the server did not answer through it. '
              'Check the address and that the VPN reaches the server.',
        null => 'Is your VPN connected?',
      };
    case ConnectFailureKind.tls:
    case ConnectFailureKind.http:
    case ConnectFailureKind.other:
      return null;
  }
}
