import 'dart:math';

import 'package:dio/dio.dart';

import '../chat/gateway/gateway_replay.dart' show reconnectDelay;

const _retriesKey = 'hermes.getRetries';

/// Sends a GET again when it got no answer because the connection could not
/// be opened, timed out opening, or dropped before the headers came.
///
/// Only GET, only `connectionError` and `connectionTimeout`, at most
/// [maxRetries] more times. Each wait is drawn at random below a bound that
/// doubles ([reconnectDelay]), so requests that failed together do not come
/// back together. A POST, PATCH or DELETE is never sent again here, nor a GET
/// that got an answer or timed out waiting for one (the server may be busy
/// with it).
///
/// Place it after the telemetry interceptor: each try then keeps its own
/// span and log record. A resent request runs the whole chain again, so the
/// session checks of [AuthController] apply to it as to any other.
class GetRetryInterceptor extends Interceptor {
  GetRetryInterceptor(
    this._dio, {
    this.maxRetries = 2,
    Random? random,
    Future<void> Function(Duration delay)? sleep,
  }) : _random = random ?? Random(),
       _sleep = sleep ?? Future<void>.delayed;

  final Dio _dio;
  final int maxRetries;
  final Random _random;
  final Future<void> Function(Duration delay) _sleep;

  static const _base = Duration(milliseconds: 500);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final retries = options.extra[_retriesKey] as int? ?? 0;
    if (options.method != 'GET' ||
        retries >= maxRetries ||
        err.type != DioExceptionType.connectionError &&
            err.type != DioExceptionType.connectionTimeout) {
      return handler.next(err);
    }
    await _sleep(reconnectDelay(retries, _random, base: _base));
    options.extra[_retriesKey] = retries + 1;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
