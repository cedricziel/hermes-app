import 'package:dio/dio.dart';

import '../api/hermes_api_client.dart';

/// The header a dashboard without the auth gate takes its page token in.
const kSessionTokenHeader = 'X-Hermes-Session-Token';

/// The session token a dashboard without the auth gate embeds in its page,
/// read once and kept until a request is rejected with it.
class PageToken {
  PageToken(this._page);

  final HermesApiClient _page;
  Future<String?>? _cached;

  Future<String?> get() async {
    final pending = _cached ??= _page.fetchSessionToken();
    try {
      return await pending;
    } on Object {
      _cached = null;
      return null;
    }
  }

  void forget() => _cached = null;
}

/// A dashboard without the auth gate still guards every route but
/// `/api/status` with the session token its page embeds. The token dies with
/// the server process, so a 401 re-reads it once and retries.
Interceptor pageTokenInterceptor(Dio dio, PageToken page) =>
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final value = await page.get();
        if (value != null) options.headers[kSessionTokenHeader] = value;
        handler.next(options);
      },
      onError: (error, handler) async {
        final options = error.requestOptions;
        if (error.response?.statusCode != 401 ||
            options.extra['hermes_token_retried'] == true) {
          return handler.next(error);
        }
        page.forget();
        options.extra['hermes_token_retried'] = true;
        try {
          handler.resolve(await dio.fetch<dynamic>(options));
        } on DioException catch (e) {
          handler.next(e);
        }
      },
    );
