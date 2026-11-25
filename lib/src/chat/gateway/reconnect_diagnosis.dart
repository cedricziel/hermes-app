import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'gateway_connection.dart';
import 'gateway_rpc_client.dart';

/// What one reconnect attempt came to, as fixed names for telemetry.
///
/// [result] is one of [kReconnectResults], [errorType] one of
/// [kReconnectErrorTypes]. Neither ever carries an error's message, which can
/// quote the server's text, an address or the prompt.
typedef ReconnectDiagnosis = ({String result, String errorType});

/// Every `result` of a `gateway.reconnect_attempt` event.
const kReconnectResults = {
  'connected',
  'resume_gone',
  'no_network',
  'refused',
  'timeout',
  'closed',
  'busy',
  'rejected',
  'credential',
  'http_error',
  'bad_certificate',
  'cancelled',
  'window_expired',
  'other',
};

/// Every `error_type` of a `gateway.reconnect_attempt` event.
const kReconnectErrorTypes = {
  'none',
  'socket',
  'websocket',
  'tls',
  'http',
  'timeout',
  'closed',
  'rpc',
  'credential',
  'cancelled',
  'other',
};

// ECONNREFUSED on Linux, Apple platforms and Windows (WSAECONNREFUSED).
const _refusedCodes = {111, 61, 10061};

/// Sorts the failure of a reconnect attempt, without keeping its message.
ReconnectDiagnosis diagnoseReconnectError(Object? error) {
  switch (error) {
    case null:
      return (result: 'other', errorType: 'none');
    case GatewayRpcException(:final code):
      return (result: code == 4009 ? 'busy' : 'rejected', errorType: 'rpc');
    case GatewayCallTimedOut() || TimeoutException():
      return (result: 'timeout', errorType: 'timeout');
    case GatewayCredentialUnavailable():
      return (result: 'credential', errorType: 'credential');
    case GatewayConnectionClosed():
      return (result: 'closed', errorType: 'closed');
    case SocketException(:final osError):
      return (
        result: _refusedCodes.contains(osError?.errorCode)
            ? 'refused'
            : 'no_network',
        errorType: 'socket',
      );
    case WebSocketChannelException(:final inner):
      if (inner is SocketException ||
          inner is TlsException ||
          inner is TimeoutException) {
        final inside = diagnoseReconnectError(inner);
        return (result: inside.result, errorType: 'websocket');
      }
      return (result: 'refused', errorType: 'websocket');
    case TlsException():
      return (result: 'refused', errorType: 'tls');
    case HttpException() || WebSocketException():
      return (result: 'refused', errorType: 'http');
    case DioException(:final type, :final response):
      return switch (type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout => (
          result: 'timeout',
          errorType: 'timeout',
        ),
        DioExceptionType.connectionError => (
          result: 'no_network',
          errorType: 'http',
        ),
        // Only a refused credential is a credential problem.
        DioExceptionType.badResponse
            when response?.statusCode == 401 || response?.statusCode == 403 =>
          (result: 'credential', errorType: 'http'),
        DioExceptionType.badResponse => (
          result: 'http_error',
          errorType: 'http',
        ),
        DioExceptionType.badCertificate => (
          result: 'bad_certificate',
          errorType: 'tls',
        ),
        DioExceptionType.cancel => (
          result: 'cancelled',
          errorType: 'cancelled',
        ),
        _ => (result: 'other', errorType: 'other'),
      };
    default:
      return (result: 'other', errorType: 'other');
  }
}
