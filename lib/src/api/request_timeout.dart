import 'package:dio/dio.dart';

const _receiveTimeoutKey = 'hermes.receiveTimeout';

/// The `extra` that lets one request wait [timeout] for its answer instead of
/// the client's default, for a route that is slow by nature (transcribing a
/// long recording). Generated methods take it as their `extra` argument.
Map<String, Object> receiveTimeoutExtra(Duration timeout) => {
  _receiveTimeoutKey: timeout,
};

/// Applies a request's [receiveTimeoutExtra].
class RequestTimeoutInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[_receiveTimeoutKey] case final Duration timeout) {
      options.receiveTimeout = timeout;
    }
    handler.next(options);
  }
}
