import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/windows/window_auth_interceptor.dart';

import 'support/fake_hermes_server.dart';

/// The main window's side of the hand-off: it hands out [current] and, when
/// told the current one was rejected, rotates it.
class _MainWindow {
  int rotations = 0;
  String current = 'access-1';
  final List<Map<String, String>?> asked = [];

  Future<Map<String, String>> headers({Map<String, String>? rejected}) async {
    asked.add(rejected);
    if (rejected?['Authorization'] == 'Bearer $current') {
      rotations++;
      current = 'access-${rotations + 1}';
    }
    return {'Authorization': 'Bearer $current'};
  }
}

void main() {
  late FakeHermesServer server;
  late _MainWindow main;
  late HermesApiClient api;
  late String validToken;
  late List<Object?> sent;

  setUp(() {
    server = FakeHermesServer();
    main = _MainWindow();
    validToken = 'access-1';
    sent = [];
    server.onRequest('GET', '/api/sessions', (request) {
      sent.add(request.headers['Authorization']);
      final ok = request.headers['Authorization'] == 'Bearer $validToken';
      return ok
          ? (status: 200, body: {'sessions': <Object>[], 'total': 0})
          : (status: 401, body: {'detail': 'Unauthorized'});
    });
    final dio = Dio(BaseOptions(baseUrl: 'http://hermes.test'))
      ..httpClientAdapter = server;
    dio.interceptors.add(WindowAuthInterceptor(dio, main.headers));
    api = HermesApiClient(dio);
  });

  test('requests carry the headers the main window hands out', () async {
    await api.raw.getSessionsApiSessionsGet();

    expect(sent, ['Bearer access-1']);
    expect(main.asked, [null]);
  });

  test('a 401 asks the main window again, naming the rejected headers, and '
      'retries once', () async {
    validToken = 'access-2';

    final response = await api.raw.getSessionsApiSessionsGet();

    expect(response.statusCode, 200);
    expect(main.asked, [
      null,
      {'Authorization': 'Bearer access-1'},
    ]);
    expect(main.rotations, 1);
    expect(sent, ['Bearer access-1', 'Bearer access-2']);
  });

  test(
    'a retry that is rejected again fails without asking a third time',
    () async {
      validToken = 'revoked';

      await expectLater(
        api.raw.getSessionsApiSessionsGet(),
        throwsA(isA<DioException>()),
      );

      expect(main.asked, hasLength(2));
      expect(server.requests, hasLength(2));
    },
  );

  test('never calls a token route itself', () async {
    validToken = 'access-2';

    await api.raw.getSessionsApiSessionsGet();

    expect(
      server.requests.map((r) => r.path),
      everyElement(isNot(startsWith('/auth/'))),
    );
  });

  test('without headers from the main window a 401 is not retried', () async {
    final dio = Dio(BaseOptions(baseUrl: 'http://hermes.test'))
      ..httpClientAdapter = server;
    var asked = 0;
    dio.interceptors.add(
      WindowAuthInterceptor(dio, ({rejected}) async {
        asked++;
        return const {};
      }),
    );

    await expectLater(
      HermesApiClient(dio).raw.getSessionsApiSessionsGet(),
      throwsA(isA<DioException>()),
    );

    expect(asked, 2);
    expect(server.requests, hasLength(1));
  });
}
