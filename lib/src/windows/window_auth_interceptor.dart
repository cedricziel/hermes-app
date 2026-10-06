import 'package:dio/dio.dart';

/// Asks the main window for the auth headers of a request; [rejected] are
/// the headers of one the server answered with 401.
typedef WindowAuthHeaders = Future<Map<String, String>> Function({
  Map<String, String>? rejected,
});

/// The only auth a conversation window's client has: it never holds a
/// refresh token, so the main window stays the one place the session is
/// refreshed and rotating refresh tokens cannot race.
class WindowAuthInterceptor extends Interceptor {
  WindowAuthInterceptor(this._dio, this._headers);

  final Dio _dio;
  final WindowAuthHeaders _headers;

  static const _sentKey = 'hermes_window_auth';
  static const _retriedKey = 'hermes_window_retried';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[_retriedKey] != true) {
      _apply(options, await _headers());
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 401 || options.extra[_retriedKey] == true) {
      return handler.next(err);
    }
    final sent = options.extra[_sentKey] as Map<String, String>? ?? const {};
    final fresh = await _headers(rejected: sent);
    if (fresh.isEmpty) return handler.next(err);
    for (final key in sent.keys) {
      options.headers.remove(key);
    }
    _apply(options, fresh);
    options.extra[_retriedKey] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  void _apply(RequestOptions options, Map<String, String> headers) {
    options.headers.addAll(headers);
    options.extra[_sentKey] = headers;
  }
}
