import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/request_timeout.dart';
import 'package:hermes_app/src/server_care/action_status.dart';
import 'package:hermes_app/src/skills/curator/curator_result.dart';
import 'package:hermes_app/src/skills/curator/curator_status.dart';
import 'package:hermes_app/src/skills/curator/hermes_curator_repository.dart';

import '../support/fake_hermes_server.dart';
import 'curator_fixtures.dart';

T ok<T>(CuratorResult<T> result) {
  expect(result, isA<CuratorOk<T>>(), reason: '$result');
  return (result as CuratorOk<T>).value;
}

CuratorFailure? failure<T>(CuratorResult<T> result) =>
    result is CuratorFailed<T> ? result.kind : null;

void main() {
  late FakeHermesServer server;
  late HermesCuratorRepository repository;

  setUp(() {
    server = FakeHermesServer();
    serveRecordedCurator(server);
    repository = HermesCuratorRepository(server.client());
  });

  void answer(String method, String path, RecordedError error) =>
      server.on(method, path, error.body, status: error.status);

  void failWith(
    String method,
    String path,
    DioException Function(RequestOptions) make,
  ) => server.onRequest(method, path, (r) => throw make(r));

  group('explicit profile', () {
    test('every call names its profile', () async {
      await repository.status(profile: 'demo-a');
      await repository.setPaused(true, profile: 'demo-a');
      await repository.run(profile: 'demo-a');

      expect(server.requests, hasLength(3));
      for (final request in server.requests) {
        expect(
          request.queryParameters['profile'],
          'demo-a',
          reason: request.path,
        );
      }
    });

    test(
      'a blank profile sends nothing: Hermes would act on its own',
      () async {
        expect(
          failure(await repository.status(profile: '')),
          CuratorFailure.refused,
        );
        expect(
          failure(await repository.setPaused(true, profile: ' ')),
          CuratorFailure.refused,
        );
        expect(
          failure(await repository.run(profile: '')),
          CuratorFailure.refused,
        );

        expect(server.requests, isEmpty);
      },
    );
  });

  group('status', () {
    test('parses the recorded answer', () async {
      final status = ok(await repository.status(profile: 'demo-a'));

      expect(status.lastRun, CuratorLastRun.never);
      expect(status.intervalHours, 168);
    });

    test('an answer that is not an object is unreadable', () async {
      server.on('GET', '/api/curator', <Object?>[1, 2]);

      expect(
        failure(await repository.status(profile: 'demo-a')),
        CuratorFailure.unreadable,
      );
    });

    test('a page where JSON was expected means the route is missing', () async {
      server.on('GET', '/api/curator', '<!doctype html><title>Hermes</title>');

      expect(
        await repository.status(profile: 'demo-a'),
        isA<CuratorUnsupported>(),
      );
    });
  });

  group('a missing route hides, a missing profile does not', () {
    test('a 404 "No such API endpoint" is unsupported', () async {
      answer('GET', '/api/curator', recordedRouteMissing404);

      expect(
        await repository.status(profile: 'demo-a'),
        isA<CuratorUnsupported>(),
      );
    });

    test('a 404 with an error body (headless) is unsupported', () async {
      server.on('GET', '/api/curator', {'error': 'not found'}, status: 404);

      expect(
        await repository.status(profile: 'demo-a'),
        isA<CuratorUnsupported>(),
      );
    });

    test('a 405 on PUT and POST is unsupported', () async {
      answer('PUT', '/api/curator/paused', recordedRouteMissing405);
      answer('POST', '/api/curator/run', recordedRouteMissing405);

      expect(
        await repository.setPaused(true, profile: 'demo-a'),
        isA<CuratorUnsupported>(),
      );
      expect(
        await repository.run(profile: 'demo-a'),
        isA<CuratorUnsupported>(),
      );
    });

    test(
      'a 404 whose detail starts "Profile \'" is a profile that is gone',
      () async {
        answer('GET', '/api/curator', recordedProfileMissing);
        answer('PUT', '/api/curator/paused', recordedProfileMissing);
        answer('POST', '/api/curator/run', recordedProfileMissing);

        expect(
          await repository.status(profile: 'demo-gone'),
          isA<CuratorProfileGone>(),
        );
        expect(
          await repository.setPaused(true, profile: 'demo-gone'),
          isA<CuratorProfileGone>(),
        );
        expect(
          await repository.run(profile: 'demo-gone'),
          isA<CuratorProfileGone>(),
        );
      },
    );

    test('a run for a deleted profile answers 500 with the 404 inside: '
        'the profile is gone, not a failed spawn', () async {
      answer('POST', '/api/curator/run', recordedRunProfileGone);

      expect(
        await repository.run(profile: 'demo-gone'),
        isA<CuratorProfileGone>(),
      );
    });
  });

  group('400 and 500 are kinds, never the server\'s words', () {
    test('400 is refused on a read and on a pause', () async {
      answer('GET', '/api/curator', recordedProfileInvalid);
      answer('PUT', '/api/curator/paused', recordedProfileInvalid);

      expect(
        failure(await repository.status(profile: 'bad name')),
        CuratorFailure.refused,
      );
      expect(
        failure(await repository.setPaused(true, profile: 'bad name')),
        CuratorFailure.refused,
      );
    });

    test('a 422 is refused', () async {
      answer('PUT', '/api/curator/paused', recordedPauseBodyInvalid);

      expect(
        failure(await repository.setPaused(true, profile: 'demo-a')),
        CuratorFailure.refused,
      );
    });

    test('the unnamed-run refusal is refused: nothing started', () async {
      answer('POST', '/api/curator/run', recordedRunUnnamed);

      expect(
        failure(await repository.run(profile: 'demo-a')),
        CuratorFailure.refused,
      );
    });

    test(
      'a run for an invalid name (500 with the 400 inside) is refused',
      () async {
        answer('POST', '/api/curator/run', recordedRunProfileInvalid);

        expect(
          failure(await repository.run(profile: 'bad name')),
          CuratorFailure.refused,
        );
      },
    );

    test('a spawn failure is its own kind: nothing started', () async {
      answer('POST', '/api/curator/run', recordedRunSpawnFailed);

      expect(
        failure(await repository.run(profile: 'demo-a')),
        CuratorFailure.spawnFailed,
      );
    });

    test('"Curator unavailable" is its own kind, on a read', () async {
      answer('GET', '/api/curator', recordedCuratorUnavailable);

      expect(
        failure(await repository.status(profile: 'demo-a')),
        CuratorFailure.unavailable,
      );
    });

    test('the same 500 on a pause is a plain-text server error', () async {
      answer('PUT', '/api/curator/paused', recordedPauseUnavailable);

      expect(
        failure(await repository.setPaused(true, profile: 'demo-a')),
        CuratorFailure.server,
      );
    });

    test('401 and 403 are unauthorized', () async {
      for (final code in [401, 403]) {
        server.on('GET', '/api/curator', {'detail': 'x'}, status: code);
        expect(
          failure(await repository.status(profile: 'demo-a')),
          CuratorFailure.unauthorized,
        );
      }
    });

    test(
      'a failure carries only its kind: no profile, detail or address',
      () async {
        for (final error in [
          recordedProfileInvalid,
          recordedRunSpawnFailed,
          recordedCuratorUnavailable,
        ]) {
          server
            ..on('GET', '/api/curator', error.body, status: error.status)
            ..on('POST', '/api/curator/run', error.body, status: error.status);
          final results = [
            await repository.status(profile: 'bad name'),
            await repository.run(profile: 'bad name'),
          ];
          for (final result in results) {
            expect(result, isA<CuratorFailed>());
            final text = '$result ${result.runtimeType}';
            for (final word in [
              'bad name',
              'hermes.test',
              '/srv',
              'Errno',
              'blocked',
            ]) {
              expect(text, isNot(contains(word)), reason: word);
            }
          }
        }
      },
    );
  });

  group('pause', () {
    test('sends the flag and returns the value Hermes answers', () async {
      server.on('PUT', '/api/curator/paused', recordedPausedOff);

      final paused = ok(await repository.setPaused(true, profile: 'demo-a'));

      expect(jsonBody(server.requests.single), {'paused': true});
      expect(paused, isFalse, reason: 'Hermes\' answer wins over the request');
    });

    test(
      'an answer without the flag is a lost answer, not a success',
      () async {
        for (final body in <Object?>[
          {'ok': true},
          {'ok': false, 'paused': true},
          {'paused': 'yes'},
          <Object?>[],
          'ok',
        ]) {
          server.on('PUT', '/api/curator/paused', body);
          expect(
            failure(await repository.setPaused(true, profile: 'demo-a')),
            CuratorFailure.lostAnswer,
            reason: '$body',
          );
        }
      },
    );
  });

  group('run', () {
    test('starts once and says so', () async {
      expect(
        ok(await repository.run(profile: 'demo-a')),
        isA<CuratorRunStarted>(),
      );
      expect(server.requestsTo('POST', '/api/curator/run'), hasLength(1));
    });

    test('an answer that is not "ok" is a lost answer', () async {
      for (final body in <Object?>[
        {'ok': false},
        <String, Object?>{},
        <Object?>[],
        '<html></html>',
      ]) {
        server.on('POST', '/api/curator/run', body);
        expect(
          failure(await repository.run(profile: 'demo-a')),
          CuratorFailure.lostAnswer,
          reason: '$body',
        );
      }
    });

    test('a 500 that is not Hermes\' own, and a gateway error, are lost '
        'answers: the pass may have started', () async {
      server.on(
        'POST',
        '/api/curator/run',
        'Internal Server Error',
        status: 500,
      );
      expect(
        failure(await repository.run(profile: 'demo-a')),
        CuratorFailure.lostAnswer,
      );

      for (final code in [502, 503, 504]) {
        server.on(
          'POST',
          '/api/curator/run',
          '<html>gateway</html>',
          status: code,
        );
        expect(
          failure(await repository.run(profile: 'demo-a')),
          CuratorFailure.lostAnswer,
          reason: '$code',
        );
      }
    });
  });

  group('requests and answers that settle a write', () {
    test('a run and a pause carry the curator receive timeout', () async {
      await repository.run(profile: 'demo-a');
      await repository.setPaused(true, profile: 'demo-a');
      await repository.status(profile: 'demo-a');

      expect(server.requests, hasLength(3));
      for (final request in server.requests) {
        expect(
          request.extra,
          containsPair(
            receiveTimeoutExtra(kCuratorTimeout).keys.single,
            kCuratorTimeout,
          ),
          reason: request.path,
        );
      }
    });

    test(
      'a pause answered 502, 503 or 504 is a lost answer, sent once',
      () async {
        for (final code in [502, 503, 504]) {
          server.on(
            'PUT',
            '/api/curator/paused',
            '<html>gateway</html>',
            status: code,
          );
          expect(
            failure(await repository.setPaused(true, profile: 'demo-a')),
            CuratorFailure.lostAnswer,
            reason: '$code',
          );
        }
        expect(server.requestsTo('PUT', '/api/curator/paused'), hasLength(3));
      },
    );

    test('a run answered 500 with some other detail is a lost answer, '
        'not a failed spawn', () async {
      server.on('POST', '/api/curator/run', {'detail': 'boom'}, status: 500);

      expect(
        failure(await repository.run(profile: 'demo-a')),
        CuratorFailure.lostAnswer,
      );
    });

    test('a read that is cancelled or fails unknown is offline', () async {
      failWith(
        'GET',
        '/api/curator',
        (r) => DioException.requestCancelled(requestOptions: r, reason: 'x'),
      );
      expect(
        failure(await repository.status(profile: 'demo-a')),
        CuratorFailure.offline,
      );

      failWith(
        'GET',
        '/api/curator',
        (r) => DioException(
          requestOptions: r,
          type: DioExceptionType.unknown,
          error: const HttpException('closed'),
        ),
      );
      expect(
        failure(await repository.status(profile: 'demo-a')),
        CuratorFailure.offline,
      );
    });
  });

  group('a lost answer is never resent', () {
    final lost = <String, DioException Function(RequestOptions)>{
      'a receive timeout': (r) => DioException.receiveTimeout(
        timeout: const Duration(seconds: 10),
        requestOptions: r,
      ),
      'a send timeout': (r) => DioException.sendTimeout(
        timeout: const Duration(seconds: 10),
        requestOptions: r,
      ),
      'a connection that drops': (r) =>
          DioException.connectionError(requestOptions: r, reason: 'reset'),
      'an unknown error': (r) => DioException(
        requestOptions: r,
        type: DioExceptionType.unknown,
        error: const HttpException('Connection closed before full header'),
      ),
    };

    for (final entry in lost.entries) {
      test('run after ${entry.key}: one POST, lost answer', () async {
        failWith('POST', '/api/curator/run', entry.value);

        final result = await repository.run(profile: 'demo-a');

        expect(failure(result), CuratorFailure.lostAnswer);
        expect(server.requestsTo('POST', '/api/curator/run'), hasLength(1));
      });

      test('pause after ${entry.key}: one PUT, lost answer', () async {
        failWith('PUT', '/api/curator/paused', entry.value);

        final result = await repository.setPaused(true, profile: 'demo-a');

        expect(failure(result), CuratorFailure.lostAnswer);
        expect(server.requestsTo('PUT', '/api/curator/paused'), hasLength(1));
      });
    }

    test('only a failure to connect proves nothing was sent', () async {
      failWith(
        'POST',
        '/api/curator/run',
        (r) => DioException.connectionTimeout(
          timeout: const Duration(seconds: 5),
          requestOptions: r,
        ),
      );
      expect(
        failure(await repository.run(profile: 'demo-a')),
        CuratorFailure.offline,
      );

      failWith(
        'PUT',
        '/api/curator/paused',
        (r) => DioException.connectionError(
          requestOptions: r,
          reason: 'refused',
          error: const SocketException('refused'),
        ),
      );
      expect(
        failure(await repository.setPaused(true, profile: 'demo-a')),
        CuratorFailure.offline,
      );
    });

    test(
      'a read that gets no answer is a timeout, and may be repeated',
      () async {
        failWith(
          'GET',
          '/api/curator',
          (r) => DioException.receiveTimeout(
            timeout: const Duration(seconds: 10),
            requestOptions: r,
          ),
        );
        expect(
          failure(await repository.status(profile: 'demo-a')),
          CuratorFailure.timeout,
        );

        failWith(
          'GET',
          '/api/curator',
          (r) => DioException.connectionError(
            requestOptions: r,
            reason: 'down',
            error: const SocketException('down'),
          ),
        );
        expect(
          failure(await repository.status(profile: 'demo-a')),
          CuratorFailure.offline,
        );
      },
    );

    test('a timeout carries no profile or address', () async {
      failWith(
        'POST',
        '/api/curator/run',
        (r) => DioException.receiveTimeout(
          timeout: const Duration(seconds: 10),
          requestOptions: r,
        ),
      );

      final text = '${await repository.run(profile: 'demo-secret')}';

      expect(text, isNot(contains('demo-secret')));
      expect(text, isNot(contains('hermes.test')));
    });
  });

  group('the action status', () {
    test('is read with lines=2000 from the curator-run action', () async {
      final status = ok(await repository.runStatus());

      final request = server
          .requestsTo('GET', '/api/actions/curator-run/status')
          .single;
      expect(request.queryParameters['lines'], 2000);
      expect(status, isA<ActionStatus>());
      expect(status.exitCode, 0);
      expect(status.startHeader, recordedRunHeader);
    });

    test('an unknown action on an old server is unsupported', () async {
      answer('GET', '/api/actions/curator-run/status', recordedActionUnknown);

      expect(await repository.runStatus(), isA<CuratorUnsupported>());
    });

    test('a poll that gets no answer is a timeout, not offline', () async {
      failWith(
        'GET',
        '/api/actions/curator-run/status',
        (r) => DioException.receiveTimeout(
          timeout: const Duration(seconds: 10),
          requestOptions: r,
        ),
      );

      expect(failure(await repository.runStatus()), CuratorFailure.timeout);
    });

    test('a poll that cannot connect is offline', () async {
      failWith(
        'GET',
        '/api/actions/curator-run/status',
        (r) => DioException.connectionError(
          requestOptions: r,
          reason: 'down',
          error: const SocketException('down'),
        ),
      );

      expect(failure(await repository.runStatus()), CuratorFailure.offline);
    });

    test('a poll answered 401 is unauthorized', () async {
      server.on('GET', '/api/actions/curator-run/status', {
        'detail': 'x',
      }, status: 401);

      expect(
        failure(await repository.runStatus()),
        CuratorFailure.unauthorized,
      );
    });

    test('a cancelled or unknown poll failure is offline', () async {
      failWith(
        'GET',
        '/api/actions/curator-run/status',
        (r) => DioException.requestCancelled(requestOptions: r, reason: 'x'),
      );
      expect(failure(await repository.runStatus()), CuratorFailure.offline);

      failWith(
        'GET',
        '/api/actions/curator-run/status',
        (r) => DioException(
          requestOptions: r,
          type: DioExceptionType.unknown,
          error: const HttpException('closed'),
        ),
      );
      expect(failure(await repository.runStatus()), CuratorFailure.offline);
    });

    test('a poll waits the curator timeout, not the client default', () async {
      await repository.runStatus();

      final request = server
          .requestsTo('GET', '/api/actions/curator-run/status')
          .single;
      expect(
        request.extra,
        containsPair(
          receiveTimeoutExtra(kCuratorTimeout).keys.single,
          kCuratorTimeout,
        ),
      );
    });

    test('a failure is a kind only', () async {
      server.on('GET', '/api/actions/curator-run/status', {
        'detail': 'secret words',
      }, status: 500);

      final result = await repository.runStatus();

      expect(failure(result), CuratorFailure.server);
      expect('$result', isNot(contains('secret')));
    });
  });
}
