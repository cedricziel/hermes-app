import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/auth/connect_failure.dart';

DioException _dio(DioExceptionType type, {Object? error, int? status}) {
  final options = RequestOptions(path: '/api/status');
  return DioException(
    requestOptions: options,
    type: type,
    error: error,
    response: status == null
        ? null
        : Response(requestOptions: options, statusCode: status),
  );
}

ConnectFailureKind _kind(DioException e) =>
    classifyConnectFailure(e, Uri.parse('http://box.example:9119')).kind;

void main() {
  group('failure kind', () {
    test('a host that does not resolve is a lookup failure', () {
      final e = _dio(
        DioExceptionType.connectionError,
        error: const SocketException(
          "Failed host lookup: 'box.tail1234.ts.net'",
          osError: OSError('nodename nor servname provided', 8),
        ),
      );
      expect(_kind(e), ConnectFailureKind.dns);
    });

    for (final code in [61, 111, 10061]) {
      test('OS error $code is a refused connection', () {
        final e = _dio(
          DioExceptionType.connectionError,
          error: SocketException(
            'Connection failed',
            osError: OSError('Connection refused', code),
          ),
        );
        expect(_kind(e), ConnectFailureKind.refused);
      });
    }

    for (final code in [51, 65, 101, 113, 10051, 10065]) {
      test('OS error $code (host or network unreachable) is a timeout', () {
        final e = _dio(
          DioExceptionType.connectionError,
          error: SocketException(
            'Connection failed',
            osError: OSError('No route to host', code),
          ),
        );
        expect(_kind(e), ConnectFailureKind.timeout);
      });
    }

    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    ]) {
      test('$type is a timeout', () {
        expect(_kind(_dio(type)), ConnectFailureKind.timeout);
      });
    }

    test('a failed TLS handshake is a TLS failure', () {
      final e = _dio(
        DioExceptionType.connectionError,
        error: const HandshakeException('bad certificate'),
      );
      expect(_kind(e), ConnectFailureKind.tls);
    });

    test('a rejected certificate is a TLS failure', () {
      expect(
        _kind(_dio(DioExceptionType.badCertificate)),
        ConnectFailureKind.tls,
      );
    });

    test('an error answer is an HTTP failure', () {
      final e = _dio(DioExceptionType.badResponse, status: 503);
      expect(_kind(e), ConnectFailureKind.http);
    });

    test('anything else is other', () {
      expect(_kind(_dio(DioExceptionType.unknown)), ConnectFailureKind.other);
      expect(
        _kind(
          _dio(
            DioExceptionType.connectionError,
            error: const SocketException('Connection reset by peer'),
          ),
        ),
        ConnectFailureKind.other,
      );
    });
  });

  group('retryable', () {
    bool retryable(DioException e) =>
        classifyConnectFailure(e, Uri.parse('http://box:9119')).retryable;

    test('network failures are retryable', () {
      expect(retryable(_dio(DioExceptionType.connectionTimeout)), isTrue);
      expect(
        retryable(
          _dio(
            DioExceptionType.connectionError,
            error: const SocketException('Failed host lookup: x'),
          ),
        ),
        isTrue,
      );
      expect(
        retryable(
          _dio(
            DioExceptionType.connectionError,
            error: const SocketException('Connection reset by peer'),
          ),
        ),
        isTrue,
      );
    });

    test('HTTP answers, TLS failures and unknown errors are not', () {
      expect(
        retryable(_dio(DioExceptionType.badResponse, status: 502)),
        isFalse,
      );
      expect(
        retryable(
          _dio(
            DioExceptionType.connectionError,
            error: const HandshakeException('x'),
          ),
        ),
        isFalse,
      );
      expect(retryable(_dio(DioExceptionType.unknown)), isFalse);
    });
  });

  group('host kind', () {
    HostKind kind(String host) => classifyHost(host);

    test('MagicDNS names are tailnet', () {
      expect(kind('box.tail1234.ts.net'), HostKind.tailnet);
      expect(kind('BOX.Tail1234.TS.NET'), HostKind.tailnet);
    });

    test('100.64.0.0/10 is tailnet, its neighbours are not', () {
      expect(kind('100.63.255.255'), HostKind.public);
      expect(kind('100.64.0.0'), HostKind.tailnet);
      expect(kind('100.101.102.103'), HostKind.tailnet);
      expect(kind('100.127.255.255'), HostKind.tailnet);
      expect(kind('100.128.0.0'), HostKind.public);
    });

    test('RFC 1918 ranges are private', () {
      expect(kind('10.0.0.5'), HostKind.private);
      expect(kind('172.15.0.1'), HostKind.public);
      expect(kind('172.16.0.1'), HostKind.private);
      expect(kind('172.31.255.255'), HostKind.private);
      expect(kind('172.32.0.1'), HostKind.public);
      expect(kind('192.168.1.20'), HostKind.private);
      expect(kind('192.169.1.20'), HostKind.public);
    });

    test('.local names are local', () {
      expect(kind('hermes.local'), HostKind.local);
    });

    test('everything else is public', () {
      expect(kind('hermes.example.com'), HostKind.public);
      expect(kind('8.8.8.8'), HostKind.public);
      expect(kind('localhost'), HostKind.public);
      expect(kind('notts.net'), HostKind.public);
    });
  });

  group('vpn hint', () {
    ConnectFailure failure(ConnectFailureKind kind, String host) =>
        ConnectFailure(kind: kind, hostKind: classifyHost(host));

    test('a lookup failure or timeout on a VPN-looking host asks', () {
      for (final kind in [ConnectFailureKind.dns, ConnectFailureKind.timeout]) {
        for (final host in ['a.tail1.ts.net', '100.101.1.1', '192.168.1.2']) {
          expect(
            vpnHint(failure(kind, host), vpnActive: null),
            'Is your VPN connected?',
          );
        }
      }
    });

    test('says so when the platform reports no VPN', () {
      expect(
        vpnHint(
          failure(ConnectFailureKind.timeout, '100.101.1.1'),
          vpnActive: false,
        ),
        contains('No VPN is active on this device'),
      );
    });

    test('says so when a VPN is active but the server does not answer', () {
      expect(
        vpnHint(
          failure(ConnectFailureKind.timeout, '10.0.0.5'),
          vpnActive: true,
        ),
        contains('A VPN is active, but the server did not answer'),
      );
    });

    test('a refused connection says nothing listens there', () {
      expect(
        vpnHint(
          failure(ConnectFailureKind.refused, '100.101.1.1'),
          vpnActive: false,
        ),
        'The server answered, but nothing is listening at that address. '
        'Check that the dashboard is running and bound to it.',
      );
    });

    test('a public host, or another failure, gets no hint', () {
      expect(
        vpnHint(
          failure(ConnectFailureKind.timeout, 'hermes.example.com'),
          vpnActive: false,
        ),
        isNull,
      );
      expect(
        vpnHint(
          failure(ConnectFailureKind.refused, 'hermes.example.com'),
          vpnActive: null,
        ),
        isNull,
      );
      for (final kind in [
        ConnectFailureKind.tls,
        ConnectFailureKind.http,
        ConnectFailureKind.other,
      ]) {
        expect(vpnHint(failure(kind, '100.101.1.1'), vpnActive: null), isNull);
      }
    });
  });
}
