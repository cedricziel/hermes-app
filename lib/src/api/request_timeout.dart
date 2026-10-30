import 'dart:async';
import 'dart:typed_data';

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

/// The `extra` that gives one request [deadline] in total, instead of the
/// adapter's default, for a body that is large by nature (an upload or a
/// file download).
Map<String, Object> requestDeadlineExtra(Duration deadline) => {
  _deadlineKey: deadline,
};

/// Ends a request that takes longer than [deadline] from the moment it is
/// sent to its last byte, as a [DioExceptionType.receiveTimeout].
///
/// Dio's own timeouts do not do that: the connect timeout stops at the open
/// socket, the receive timeout covers the headers and then only the gap
/// between two chunks, and nothing bounds sending a body. A server that
/// trickles bytes, or a network that stalls mid-upload, would otherwise hold a
/// request for as long as the connection lives.
///
/// It wraps the adapter rather than sitting in the interceptor chain: only the
/// adapter sees every request end, so the clock never outlives one, and it
/// does not run while the session is being refreshed. A request that widens
/// its receive timeout ([receiveTimeoutExtra]) is given that and the connect
/// timeout, never less than [deadline].
class RequestDeadlineAdapter implements HttpClientAdapter {
  RequestDeadlineAdapter(
    this._inner, {
    this.deadline = const Duration(seconds: 60),
  });

  final HttpClientAdapter _inner;
  final Duration deadline;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final budget = _budget(options);
    final expired = Completer<void>();
    final answer = Completer<ResponseBody>();
    final timeout = DioException.receiveTimeout(
      timeout: budget,
      requestOptions: options,
    );
    // Closed by the timer or when the source ends.
    // ignore: close_sinks
    StreamController<Uint8List>? body;
    StreamSubscription<Uint8List>? source;
    late final Timer timer;

    timer = Timer(budget, () {
      expired.complete();
      if (!answer.isCompleted) {
        answer.completeError(timeout);
      } else if (body case final open? when !open.isClosed) {
        unawaited(source?.cancel());
        open
          ..addError(timeout)
          ..close();
      }
    });
    // Whichever of the two ends the request, the inner adapter aborts it.
    final abort = Future.any([?cancelFuture, expired.future]);
    unawaited(cancelFuture?.whenComplete(timer.cancel));

    _inner
        .fetch(options, requestStream, abort)
        .then(
          (response) {
            if (answer.isCompleted) {
              // Already failed with the timeout: drop the late answer.
              unawaited(response.stream.listen(null).cancel());
              return;
            }
            final out = body = StreamController<Uint8List>(
              onPause: () => source?.pause(),
              onResume: () => source?.resume(),
              onCancel: () {
                timer.cancel();
                return source?.cancel();
              },
            );
            source = response.stream.listen(
              out.add,
              onError: (Object e, StackTrace s) {
                timer.cancel();
                out.addError(e, s);
              },
              onDone: () {
                timer.cancel();
                unawaited(out.close());
              },
              cancelOnError: true,
            );
            answer.complete(
              ResponseBody(
                out.stream,
                response.statusCode,
                statusMessage: response.statusMessage,
                isRedirect: response.isRedirect,
                redirects: response.redirects,
                headers: response.headers,
              )..extra = response.extra,
            );
          },
          onError: (Object e, StackTrace s) {
            timer.cancel();
            if (!answer.isCompleted) answer.completeError(e, s);
          },
        );
    return answer.future;
  }

  Duration _budget(RequestOptions options) {
    if (options.extra[_deadlineKey] case final Duration own) return own;
    final widened =
        (options.connectTimeout ?? Duration.zero) +
        (options.receiveTimeout ?? Duration.zero);
    return widened > deadline ? widened : deadline;
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}
