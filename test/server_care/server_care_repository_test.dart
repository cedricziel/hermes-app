import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/server_care/care_result.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/server_care/update_receipt.dart';

import '../support/fake_hermes_server.dart';
import 'server_care_fixtures.dart';

T ok<T>(CareResult<T> r) => (r as CareOk<T>).value;

CareFailed<T> failed<T>(CareResult<T> r) => r as CareFailed<T>;

void main() {
  late FakeHermesServer server;
  late ServerCareRepository repo;

  setUp(() {
    server = FakeHermesServer();
    repo = ServerCareRepository(server.client());
  });

  Map<String, dynamic> query(String method, String path) =>
      server.requestsTo(method, path).single.queryParameters;

  group('queries', () {
    test('status sends the explicit profile', () async {
      server.on('GET', '/api/status', statusHealthy());
      final s = ok(await repo.status(profile: 'work'));
      expect(s.version, '0.22.2');
      expect(query('GET', '/api/status'), {'profile': 'work'});
    });

    test('the update check sends force and never a profile', () async {
      server.on('GET', '/api/hermes/update/check', updateCheckBehind());
      await repo.checkUpdate();
      await repo.checkUpdate(force: true);
      final calls = server
          .requestsTo('GET', '/api/hermes/update/check')
          .toList();
      expect(calls.first.queryParameters['force'], isNot(true));
      expect(calls.last.queryParameters['force'], true);
      expect(
        calls.every((c) => !c.queryParameters.containsKey('profile')),
        isTrue,
      );
    });

    test('logs send file, lines, level, search and profile', () async {
      server.on('GET', '/api/logs', {'file': 'errors', 'lines': logsErrors});
      final lines = ok(
        await repo.logs(
          profile: 'work',
          file: CareLogFile.gateway,
          lines: 500,
          level: 'WARNING',
          search: 'telegram',
        ),
      );
      expect(lines, hasLength(2));
      expect(query('GET', '/api/logs'), {
        'file': 'gateway',
        'lines': 500,
        'level': 'WARNING',
        'search': 'telegram',
        'profile': 'work',
      });
    });

    test('an empty search is not sent', () async {
      server.on('GET', '/api/logs', {'lines': []});
      await repo.logs(profile: 'p', search: '');
      expect(query('GET', '/api/logs').containsKey('search'), isFalse);
    });

    test('usage sends days and profile and fills the window', () async {
      server.on('GET', '/api/analytics/usage', usage30());
      final r = ok(
        await repo.usage(
          profile: 'work',
          days: 7,
          today: DateTime(2026, 11, 14),
        ),
      );
      expect(r.days, hasLength(7));
      expect(query('GET', '/api/analytics/usage'), {
        'days': 7,
        'profile': 'work',
      });
    });

    test('action status asks by name and lines', () async {
      server.on(
        'GET',
        '/api/actions/doctor/status',
        actionStatusAfterTwoRuns(),
      );
      final s = ok(await repo.actionStatus(CareAction.doctor, lines: 60));
      expect(s.exitCode, 1);
      expect(query('GET', '/api/actions/doctor/status'), {'lines': 60});
    });

    test('doctor, gateway start and restart send the profile', () async {
      server
        ..on('POST', '/api/ops/doctor', {
          'ok': true,
          'pid': 1,
          'name': 'doctor',
        })
        ..on('POST', '/api/gateway/start', {
          'ok': true,
          'pid': 2,
          'name': 'gateway-start',
        })
        ..on('POST', '/api/gateway/restart', {
          'ok': true,
          'pid': 3,
          'name': 'gateway-restart',
        });
      expect(ok(await repo.startDoctor(profile: 'a')).name, 'doctor');
      expect(ok(await repo.startGateway(profile: 'b')).pid, 2);
      expect(
        ok(await repo.restartGateway(profile: 'c')).name,
        'gateway-restart',
      );
      expect(query('POST', '/api/ops/doctor'), {'profile': 'a'});
      expect(query('POST', '/api/gateway/start'), {'profile': 'b'});
      expect(query('POST', '/api/gateway/restart'), {'profile': 'c'});
    });

    test('health reads the commit; the update start reads a refusal', () async {
      server
        ..on('GET', '/api/health', {
          'ok': true,
          'version': '0.22.2',
          'commit': 'd923a5e',
        })
        ..on('POST', '/api/hermes/update', updateRefused());
      expect(ok(await repo.health()).commit, 'd923a5e');
      expect(ok(await repo.startUpdate()), isA<UpdateRefused>());
    });
  });

  group('failures', () {
    test('404, 405 and a non-JSON body are unsupported', () async {
      server.on('GET', '/api/status', {'detail': 'Not Found'}, status: 404);
      expect(await repo.status(profile: 'p'), isA<CareUnsupported<Object?>>());
      server.on('GET', '/api/status', {}, status: 405);
      expect(await repo.status(profile: 'p'), isA<CareUnsupported<Object?>>());
      server.on('GET', '/api/status', '<html>spa</html>');
      expect(await repo.status(profile: 'p'), isA<CareUnsupported<Object?>>());
    });

    test(
      'the receipt 404 "No update receipt" is a value, not unsupported',
      () async {
        server.on('GET', '/api/hermes/update/receipt', {
          'detail': 'No update receipt found.',
        }, status: 404);
        final r = await repo.updateReceipt();
        expect(r, isA<CareOk<UpdateReceiptSummary?>>());
        expect(ok(r), isNull);
      },
    );

    test('any other receipt 404 is unsupported', () async {
      server.on('GET', '/api/hermes/update/receipt', {
        'detail': 'Not Found',
      }, status: 404);
      expect(await repo.updateReceipt(), isA<CareUnsupported<Object?>>());
    });

    test('the receipt is read', () async {
      server.on('GET', '/api/hermes/update/receipt', receiptSuccess());
      expect(ok(await repo.updateReceipt())?.outcome, UpdateOutcome.success);
    });

    test('409 and 500 are refused with Hermes\' detail', () async {
      server.on('POST', '/api/gateway/start', {
        'detail': 'Shared gateway.',
      }, status: 409);
      final a = failed(await repo.startGateway(profile: 'p'));
      expect(a.kind, CareFailureKind.refused);
      expect(a.message, 'Shared gateway.');

      server.on('POST', '/api/gateway/restart', {
        'detail': 'needs root',
      }, status: 500);
      final b = failed(await repo.restartGateway(profile: 'p'));
      expect(b.kind, CareFailureKind.refused);
      expect(b.message, 'needs root');
    });

    test(
      'a 500 without detail is a server failure; 401 is unauthorized',
      () async {
        server.on('GET', '/api/status', {}, status: 500);
        expect(
          failed(await repo.status(profile: 'p')).kind,
          CareFailureKind.server,
        );
        server.on('GET', '/api/status', {'detail': 'x'}, status: 401);
        expect(
          failed(await repo.status(profile: 'p')).kind,
          CareFailureKind.unauthorized,
        );
      },
    );

    test('a connection error is offline', () async {
      server.onRequest('GET', '/api/status', (o) {
        throw DioException.connectionError(requestOptions: o, reason: 'down');
      });
      expect(
        failed(await repo.status(profile: 'p')).kind,
        CareFailureKind.offline,
      );
    });

    test('a proxy 502 on health is a failure, never an answer', () async {
      server.on('GET', '/api/health', '<html>Bad gateway</html>', status: 502);
      expect(await repo.health(), isA<CareFailed<ServerHealth>>());
      server.on('GET', '/api/health', {'ok': false});
      expect(failed(await repo.health()).kind, CareFailureKind.unreadable);
    });

    test('usage 503 is the unreadable store', () async {
      server.on('GET', '/api/analytics/usage', {
        'detail': {'path': '/secret/state.db'},
      }, status: 503);
      final f = failed(
        await repo.usage(profile: 'p', days: 30, today: DateTime(2026, 11, 14)),
      );
      expect(f.kind, CareFailureKind.storeUnreadable);
      expect(f.message, isNull);
    });

    test('a 200 that is not an object is unreadable', () async {
      server.on('GET', '/api/hermes/update/check', ['x']);
      expect(failed(await repo.checkUpdate()).kind, CareFailureKind.unreadable);
    });
  });
}
