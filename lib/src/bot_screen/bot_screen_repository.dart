import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show DioException;
import 'package:flutter_otel/flutter_otel.dart' show Span;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../chat/gateway/gateway_rpc_client.dart';
import '../chat/session_chat_transport.dart' show SessionTransportUnavailable;
import '../surfaces/surface_snapshot.dart' show kDefaultProfile;
import '../telemetry/telemetry.dart';
import 'bot_screen_models.dart';

/// How long a display call may take before it fails on its own. A screenshot
/// on a loaded server can be slow, and the connection also carries replies.
const kDisplayTimeout = Duration(seconds: 10);

/// The shared gateway's request that fails one call on a timeout without
/// closing the connection (`HermesGatewayTransport.requestKeepingConnection`).
typedef DisplayRpc = Future<Map<String, Object?>> Function(
  String method,
  Map<String, Object?> params, {
  required Duration timeout,
});

/// [DisplayRpc] that also gives the connection that carried the call
/// (`HermesGatewayTransport.requestKeepingConnectionOnClient`).
typedef InstallRpc = Future<(Map<String, Object?>, Object)> Function(
  String method,
  Map<String, Object?> params, {
  required Duration timeout,
});

/// Reads and starts a profile's Bot Screen over the gateway's `display.*`
/// methods. Every call names its profile (`default` for the server's default
/// profile) because Hermes answers for its launch home otherwise, and every
/// call yields a [BotScreenResult] instead of throwing.
class BotScreenRepository {
  BotScreenRepository(
    this._rpc, {
    this.telemetry = const ConnectionTelemetry(),
    this.timeout = kDisplayTimeout,
    this.installRpc,
  });

  final DisplayRpc _rpc;

  /// What `display.install` goes through, to learn the connection it used;
  /// without it the install's connection is unknown.
  final InstallRpc? installRpc;
  final ConnectionTelemetry telemetry;
  final Duration timeout;
  var _reportedUnsupported = false;
  var _failureLogged = false;

  Future<BotScreenResult<BotScreenStatus>> status(String? profile) =>
      _call('display.status', profile, BotScreenStatus.fromJson);

  /// Starts the profile's screen (idempotent) and returns its new status.
  Future<BotScreenResult<BotScreenStatus>> start(String? profile) =>
      _call('display.start', profile, BotScreenStatus.fromJson);

  /// Starts installing the desktop packages on the gateway host. A refusal
  /// (another install running, an unsupported host, a sandbox, no package
  /// manager) is a [BotScreenFailed] carrying Hermes' message; it is not a
  /// read failure, so it is not logged here.
  Future<BotScreenResult<BotScreenInstallStart>> install(String? profile) {
    Object? carrier;
    final withClient = installRpc;
    return _call(
      'display.install',
      profile,
      (result) {
        final key = result['profile_key'];
        final command = result['command'];
        if (key is! String || key.isEmpty) {
          throw const FormatException('profile_key');
        }
        return BotScreenInstallStart(
          command: command is String ? command : null,
          profileKey: key,
          connection: carrier,
        );
      },
      logFailures: false,
      rpc: withClient == null
          ? null
          : (method, params, {required timeout}) async {
              final (result, connection) = await withClient(
                method,
                params,
                timeout: timeout,
              );
              carrier = connection;
              return result;
            },
    );
  }

  /// One JPEG grab of the screen; read-only, it never changes the lease.
  Future<BotScreenResult<BotScreenFrame>> thumbnail(String? profile) async {
    Span? span;
    _quiet(
      () => span = telemetry.tracer?.startSpan(
        'bot_screen.thumbnail',
        attributes: telemetry.serverAttributes,
      ),
    );
    final result = await _call('display.thumbnail', profile, _frame);
    _quiet(() {
      span?.setAttribute('outcome', _outcome(result));
      if (result case BotScreenOk(value: BotScreenJpeg(:final bytes))) {
        span?.setAttribute('bytes_kib', _bucket(bytes.length ~/ 1024));
      }
      span?.end();
    });
    return result;
  }

  Future<BotScreenResult<T>> _call<T>(
    String method,
    String? profile,
    T Function(Map<String, Object?> result) parse, {
    bool logFailures = true,
    DisplayRpc? rpc,
  }) async {
    BotScreenFailed<T> failed(BotScreenFailure kind, [String? message]) =>
        logFailures
        ? _failed(method, kind, message)
        : BotScreenFailed(kind, message: message);
    try {
      final answer = await (rpc ?? _rpc)(method, {
        'profile': profile ?? kDefaultProfile,
      }, timeout: timeout);
      final value = parse(answer);
      _failureLogged = false;
      return BotScreenOk(value);
    } on GatewayRpcException catch (error) {
      if (error.code == kGatewayMethodNotFound) {
        if (method == 'display.status') _reportUnsupported();
        return BotScreenUnsupported();
      }
      return failed(BotScreenFailure.display, error.message);
    } on FormatException {
      return failed(BotScreenFailure.display);
    } on GatewayRequestTimeout {
      return failed(BotScreenFailure.timeout);
    } on TimeoutException {
      return failed(BotScreenFailure.timeout);
    } on GatewayConnectionClosed {
      return failed(BotScreenFailure.closed);
    } on SessionTransportUnavailable {
      return failed(BotScreenFailure.closed);
    } on SocketException {
      return failed(BotScreenFailure.closed);
    } on WebSocketChannelException {
      return failed(BotScreenFailure.closed);
    } on DioException {
      return failed(BotScreenFailure.closed);
    }
  }

  /// Logs the first failure of a streak only; any success ends the streak.
  BotScreenFailed<T> _failed<T>(
    String method,
    BotScreenFailure kind, [
    String? message,
  ]) {
    final failure = BotScreenFailed<T>(kind, message: message);
    if (_failureLogged) return failure;
    _failureLogged = true;
    _quiet(
      () => telemetry.events('bot_screen.read_failed', {
        'method': method,
        'error_type': kind.slug,
      }),
    );
    return failure;
  }

  void _reportUnsupported() {
    if (_reportedUnsupported) return;
    _reportedUnsupported = true;
    _quiet(() => telemetry.events('bot_screen.unsupported'));
  }

  static BotScreenFrame _frame(Map<String, Object?> result) {
    final url = result['data_url'];
    if (url == null) {
      final reason = result['suppressed'];
      return reason is String && reason.isNotEmpty
          ? BotScreenSuppressed(reason)
          : const BotScreenStopped();
    }
    if (url is! String) throw const FormatException('data_url');
    final comma = url.indexOf(',');
    if (comma < 0) throw const FormatException('data_url');
    return BotScreenJpeg(base64Decode(url.substring(comma + 1)));
  }

  static String _outcome(BotScreenResult<BotScreenFrame> result) =>
      switch (result) {
        BotScreenOk(value: BotScreenJpeg()) => 'frame',
        BotScreenOk(value: BotScreenSuppressed()) => 'suppressed',
        BotScreenOk(value: BotScreenStopped()) => 'stopped',
        BotScreenFailed(kind: BotScreenFailure.timeout) => 'timeout',
        _ => 'error',
      };

  static String _bucket(int kib) => switch (kib) {
    < 16 => '<16',
    < 64 => '16-64',
    < 256 => '64-256',
    _ => '>=256',
  };

  /// Telemetry must never break the app.
  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}
