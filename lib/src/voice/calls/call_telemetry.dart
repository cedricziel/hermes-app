import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// The kind of a voice call failure in fixed words, for telemetry: an HTTP
/// or upgrade status, a platform error code or an error class. Never a
/// message, URL, transcript or reply, which can carry addresses or speech.
String callErrorKind(Object error) {
  final cause = error is WebSocketChannelException
      ? (error.inner ?? error)
      : error;
  return switch (cause) {
    TimeoutException() => 'timeout',
    DioException(response: Response(:final statusCode?)) => 'http_$statusCode',
    DioException(:final type) => 'dio_${type.name}',
    WebSocketException(:final httpStatusCode?) => 'upgrade_$httpStatusCode',
    WebSocketException() => 'websocket',
    WebSocketChannelException() => 'websocket',
    TlsException() => 'tls',
    SocketException() => 'socket',
    MissingPluginException() => 'missing_plugin',
    PlatformException(:final code) => 'platform_${_slug(code)}',
    FormatException() => 'format',
    StateError() => 'state',
    _ => 'other',
  };
}

/// Native codes are our own plugin's fixed words, but keep them bounded.
String _slug(String code) {
  final slug = code.toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '_');
  return slug.length > 24 ? slug.substring(0, 24) : slug;
}

/// Counts as coarse buckets, so a log never says exactly how long or how
/// much someone talked.
String callTurnsBucket(int turns) => switch (turns) {
  0 => '0',
  1 => '1',
  <= 5 => '2-5',
  _ => '>5',
};

String callDurationBucket(Duration? duration) => switch (duration) {
  null => 'none',
  final d when d < const Duration(seconds: 10) => '<10s',
  final d when d < const Duration(minutes: 1) => '10-60s',
  final d when d < const Duration(minutes: 5) => '1-5m',
  _ => '>5m',
};
