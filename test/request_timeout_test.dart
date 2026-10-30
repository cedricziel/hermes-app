import 'dart:async';
import 'dart:io';

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

  group('request deadline', () {
    const deadline = Duration(milliseconds: 80);

    Dio clientFor(FakeHermesServer server) =>
        server.dio()
          ..interceptors.add(RequestDeadlineInterceptor(deadline: deadline));

    FakeHermesServer stuckServer() {
      final never = Completer<FakeResponse>();
      return FakeHermesServer()
        ..onRequest('GET', '/stuck', (_) => never.future);
    }

    FakeHermesServer slowServer(String path, Duration delay) =>
        FakeHermesServer()..onRequest('GET', path, (_) async {
          await Future<void>.delayed(delay);
          return (status: 200, body: {'ok': true});
        });

    Matcher dioError(DioExceptionType type) =>
        throwsA(isA<DioException>().having((e) => e.type, 'type', type));

    test('ends a request whose answer never finishes as a timeout', () async {
      final dio = clientFor(stuckServer());

      await expectLater(
        dio.get<Object>('/stuck'),
        dioError(DioExceptionType.receiveTimeout),
      );
    });

    test('leaves a request that answers in time alone', () async {
      final server = FakeHermesServer()..on('GET', '/ok', {'ok': true});

      final response = await clientFor(server).get<Object>('/ok');

      expect(response.data, {'ok': true});
    });

    test('gives a request with a longer receive timeout that long', () async {
      final dio = clientFor(slowServer('/slow', deadline * 3))
        ..interceptors.insert(0, RequestTimeoutInterceptor());

      final response = await dio.get<Object>(
        '/slow',
        options: Options(
          extra: receiveTimeoutExtra(const Duration(minutes: 3)),
        ),
      );

      expect(response.data, {'ok': true});
    });

    test('takes a longer deadline for one request', () async {
      final dio = clientFor(slowServer('/upload', deadline * 3));

      final response = await dio.get<Object>(
        '/upload',
        options: Options(extra: requestDeadlineExtra(deadline * 20)),
      );

      expect(response.data, {'ok': true});
    });

    test('a caller cancelling still reads as a cancel', () async {
      final token = CancelToken();
      final outcome = expectLater(
        clientFor(stuckServer()).get<Object>('/stuck', cancelToken: token),
        dioError(DioExceptionType.cancel),
      );

      token.cancel();

      await outcome;
    });

    test('ends an answer that trickles in, which Dio\'s receive timeout '
        'does not', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.headers.contentType = ContentType.text;
        try {
          // A byte well inside the receive timeout, for ever.
          while (true) {
            request.response.write('.');
            await request.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }
        } on Object {
          // The client went away.
        }
      });
      final dio =
          Dio(
              BaseOptions(
                baseUrl: 'http://127.0.0.1:${server.port}',
                receiveTimeout: const Duration(milliseconds: 200),
              ),
            )
            ..interceptors.add(
              RequestDeadlineInterceptor(
                deadline: const Duration(milliseconds: 300),
              ),
            );

      await expectLater(
        dio.get<String>('/'),
        dioError(DioExceptionType.receiveTimeout),
      );
    });

    test('running out does not cancel the caller\'s token', () async {
      final token = CancelToken();

      await expectLater(
        clientFor(stuckServer()).get<Object>('/stuck', cancelToken: token),
        dioError(DioExceptionType.receiveTimeout),
      );

      expect(token.isCancelled, isFalse);
    });
  });
}
