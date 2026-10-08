import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/request_timeout.dart';

import 'support/fake_hermes_server.dart';

void main() {
  test(
    'a request can wait longer than the client\'s receive timeout',
    () async {
      final server = FakeHermesServer()..on('GET', '/slow', {'ok': true});
      final dio = server.dio()
        ..options.receiveTimeout = const Duration(seconds: 30)
        ..interceptors.add(RequestTimeoutInterceptor());

      await dio.get<Object>(
        '/slow',
        options: Options(
          extra: receiveTimeoutExtra(const Duration(minutes: 3)),
        ),
      );
      await dio.get<Object>('/slow');

      final [long, plain] = server.requests;
      expect(long.receiveTimeout, const Duration(minutes: 3));
      expect(plain.receiveTimeout, const Duration(seconds: 30));
    },
  );
}
