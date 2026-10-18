import 'dart:io';

import 'package:dio/dio.dart';

/// A lookup failure independent of the test machine's DNS and HTTP proxy.
Interceptor dnsFailureInterceptor({String? host}) => InterceptorsWrapper(
  onRequest: (options, handler) {
    if (host != null && options.uri.host != host) {
      handler.next(options);
      return;
    }
    handler.reject(
      DioException.connectionError(
        requestOptions: options,
        reason: 'Host could not be resolved',
        error: const SocketException('Failed host lookup'),
      ),
    );
  },
);
