import 'dart:async';

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

const _deadlineKey = 'hermes.requestDeadline';
const _callerTokenKey = 'hermes.requestDeadline.callerToken';
const _runningKey = 'hermes.requestDeadline.running';

/// The `extra` that gives one request [deadline] in total, instead of the
/// interceptor's default, for a body that is large by nature (an upload or a
/// file download).
Map<String, Object> requestDeadlineExtra(Duration deadline) => {
  _deadlineKey: deadline,
};

/// Ends a request that takes longer than [deadline] from its start to its
/// last byte, as a [DioExceptionType.receiveTimeout].
///
/// Dio's own timeouts do not do that: the connect timeout stops at the open
/// socket, the receive timeout covers the headers and then only the gap
/// between two chunks, and nothing bounds sending a body at all. A server that
/// trickles bytes, or a network that stalls mid-upload, would otherwise hold a
/// request for as long as the connection lives.
///
/// A request that widens its receive timeout ([receiveTimeoutExtra]) is
/// given that and the connect timeout, never less than [deadline]. Place it
/// after [RequestTimeoutInterceptor] and ahead of the interceptors whose
/// `onError` should see the timeout.
class RequestDeadlineInterceptor extends Interceptor {
  RequestDeadlineInterceptor({this.deadline = const Duration(seconds: 60)});

  final Duration deadline;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // A retry (the session refresh sends the same options again) starts over
    // with the caller's own token.
    _stop(options);
    final caller = options.extra.putIfAbsent(
      _callerTokenKey,
      () => options.cancelToken,
    ) as CancelToken?;
    final budget = _budget(options);
    // A token of our own, so running out never cancels one the caller shares
    // with other requests.
    final token = CancelToken();
    final timer = Timer(budget, () => token.cancel(_Expired(budget)));
    unawaited(
      caller?.whenCancel.then((e) {
        timer.cancel();
        token.cancel(e.error);
      }),
    );
    options
      ..cancelToken = token
      ..extra[_runningKey] = timer;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _stop(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _stop(err.requestOptions);
    final reason = err.error;
    handler.next(
      err.type == DioExceptionType.cancel && reason is _Expired
          ? DioException.receiveTimeout(
              timeout: reason.budget,
              requestOptions: err.requestOptions,
            )
          : err,
    );
  }

  static void _stop(RequestOptions options) {
    if (options.extra.remove(_runningKey) case final Timer timer) {
      timer.cancel();
    }
  }

  Duration _budget(RequestOptions options) {
    if (options.extra[_deadlineKey] case final Duration own) return own;
    final widened =
        (options.connectTimeout ?? Duration.zero) +
        (options.receiveTimeout ?? Duration.zero);
    return widened > deadline ? widened : deadline;
  }
}

/// What a request's token is cancelled with when its deadline passes.
class _Expired {
  const _Expired(this.budget);

  final Duration budget;
}
