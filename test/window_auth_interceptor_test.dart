import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/chat/gateway/ticket_mint_gate.dart';
import 'package:hermes_app/src/windows/window_api_client.dart';
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

  group('a window client\'s ticket gate', () {
    late HermesApiClient window;
    late TicketMintGate gate;

    setUp(() {
      window = windowApiClient(
        'http://hermes.test',
        main.headers,
        adapter: server,
      );
      gate = TicketMintGate.of(window);
      server.onRequest(
        'POST',
        '/api/auth/ws-ticket',
        (_) => (status: 401, body: {'detail': 'no'}),
      );
    });

    Future<void> mint() => gate
        .run(() => window.raw.authWsTicketApiAuthWsTicketPost())
        .then<void>((_) {}, onError: (Object _) {});

    int ticketRequests() =>
        server.requests.where((r) => r.path == '/api/auth/ws-ticket').length;

    test('a 401 that outlasts the main window\'s refresh is sent once per '
        'wait, not on every call', () async {
      for (var i = 0; i < 5; i++) {
        await mint();
      }

      // The request and its one retry with the refreshed header.
      expect(ticketRequests(), 2);
      expect(main.rotations, 1);
    });

    test(
      'a credential the main window renews meanwhile ends the wait',
      () async {
        await mint();
        await mint();
        expect(ticketRequests(), 2, reason: 'waiting');

        // The main window refreshed on its own; the next request carries it.
        main.current = 'access-9';
        validToken = 'access-9';
        await window.raw.getSessionsApiSessionsGet();
        await mint();

        expect(ticketRequests(), greaterThan(2));
      },
    );
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

  test(
    'a main window that does not answer does not hold the request',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://hermes.test'))
        ..httpClientAdapter = server;
      dio.interceptors.add(
        WindowAuthInterceptor(
          dio,
          ({rejected}) => Completer<Map<String, String>>().future,
          timeout: const Duration(milliseconds: 20),
        ),
      );

      await expectLater(
        HermesApiClient(dio).raw.getSessionsApiSessionsGet(),
        throwsA(isA<DioException>()),
      );

      expect(sent, [null]);
    },
  );
}
