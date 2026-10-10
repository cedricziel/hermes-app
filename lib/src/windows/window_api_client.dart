import 'package:dio/dio.dart';

import '../api/hermes_api_client.dart';
import '../api/request_timeout.dart';
import 'window_auth_interceptor.dart';

/// The API client of an engine besides the main one (a conversation window,
/// the quick panel): it holds no session, so every request asks the main
/// window for its auth [headers].
HermesApiClient windowApiClient(String baseUrl, WindowAuthHeaders headers) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  dio.interceptors.addAll([
    RequestTimeoutInterceptor(),
    WindowAuthInterceptor(dio, headers),
  ]);
  return HermesApiClient(dio);
}
