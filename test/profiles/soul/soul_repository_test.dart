import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/profiles/soul/soul_repository.dart';

import '../../support/fake_hermes_server.dart';
import 'soul_fixtures.dart';

void main() {
  late FakeHermesServer server;
  late SoulRepository repository;
  setUp(() {
    server = FakeHermesServer();
    repository = SoulRepository(server.client().raw);
  });

  Future<SoulFailureKind> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on SoulFailure catch (failure) {
      return failure.kind;
    }
    fail('expected a SoulFailure');
  }

  group('read', () {
    test('puts the name in the path and sends no query', () async {
      server.on('GET', soulPath, soulWithText);
      final soul = await repository.read(soulProfile);
      expect(soul.content, 'You are Quill.\nBe brief.\n');
      expect(soul.exists, isTrue);
      final request = server.requests.single;
      expect(request.path, soulPath);
      expect(request.queryParameters, isEmpty);
    });

    test('tells an absent file from an empty one', () async {
      server.on('GET', soulPath, soulAbsent);
      final absent = await repository.read(soulProfile);
      expect((absent.content, absent.exists), ('', false));
      server.on('GET', soulPath, soulEmptyFile);
      final empty = await repository.read(soulProfile);
      expect((empty.content, empty.exists), ('', true));
    });

    test('is lenient about extra and missing fields', () async {
      server.on('GET', soulPath, {'content': 'Hi', 'extra': 1});
      final soul = await repository.read(soulProfile);
      expect((soul.content, soul.exists), ('Hi', true));
    });

    test('an answer without text is malformed, never an empty file', () async {
      for (final body in <Object?>[
        {'exists': true},
        {'content': 5, 'exists': true},
        ['x'],
        'plain',
      ]) {
        server.on('GET', soulPath, body);
        expect(
          await failureOf(repository.read(soulProfile)),
          SoulFailureKind.malformed,
          reason: '$body',
        );
      }
    });

    test(
      'a missing profile is profileGone, any other 404 unsupported',
      () async {
        server.on('GET', soulPath, soulProfileMissing, status: 404);
        expect(
          await failureOf(repository.read(soulProfile)),
          SoulFailureKind.profileGone,
        );
        for (final body in <Object?>[
          soulRouteMissing,
          {'error': 'nope'},
          'Not Found',
        ]) {
          server.on('GET', soulPath, body, status: 404);
          expect(
            await failureOf(repository.read(soulProfile)),
            SoulFailureKind.unsupported,
            reason: '$body',
          );
        }
      },
    );

    test('405, 400 and 422 and 500 map to their kinds', () async {
      final cases = {
        405: SoulFailureKind.unsupported,
        400: SoulFailureKind.badRequest,
        422: SoulFailureKind.validation,
        500: SoulFailureKind.server,
        503: SoulFailureKind.server,
        418: SoulFailureKind.unexpected,
      };
      for (final MapEntry(key: status, value: kind) in cases.entries) {
        server.on('GET', soulPath, soulBadName, status: status);
        expect(
          await failureOf(repository.read(soulProfile)),
          kind,
          reason: '$status',
        );
      }
    });

    test('a plain 500 is the server kind and its body stays out', () async {
      server.on('GET', soulPath, 'secret /srv/path', status: 500);
      try {
        await repository.read(soulProfile);
        fail('expected a failure');
      } on SoulFailure catch (failure) {
        expect(failure.kind, SoulFailureKind.server);
        expect('$failure', isNot(contains('secret')));
        expect(failure.message, isNot(contains('/srv')));
      }
    });

    test('a 401 is not swallowed', () async {
      server.on('GET', soulPath, soulUnauthorized, status: 401);
      await expectLater(
        repository.read(soulProfile),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'code',
            401,
          ),
        ),
      );
    });

    test('no answer is unreachable', () async {
      server.onRequest(
        'GET',
        soulPath,
        (request) => throw DioException.connectionError(
          requestOptions: request,
          reason: 'down',
        ),
      );
      expect(
        await failureOf(repository.read(soulProfile)),
        SoulFailureKind.unreachable,
      );
    });
  });

  group('write', () {
    test('sends the whole text in the body, name in the path', () async {
      server.on('PUT', soulPath, soulSaved);
      final result = await repository.write(soulProfile, 'New text\n');
      expect(result, SoulWriteResult.saved);
      final request = server.requests.single;
      expect(request.path, soulPath);
      expect(request.queryParameters, isEmpty);
      expect(jsonBody(request), {'content': 'New text\n'});
    });

    test('saves empty text', () async {
      server.on('PUT', soulPath, soulSaved);
      expect(await repository.write(soulProfile, ''), SoulWriteResult.saved);
      expect(jsonBody(server.requests.single), {'content': ''});
    });

    test('a 200 without ok: true is unconfirmed', () async {
      for (final body in <Object?>[
        {'ok': false},
        {'ok': 'true'},
        <String, Object?>{},
        'fine',
        null,
      ]) {
        server.on('PUT', soulPath, body);
        expect(
          await repository.write(soulProfile, 'x'),
          SoulWriteResult.unconfirmed,
          reason: '$body',
        );
      }
    });

    test('refusals map to their kinds', () async {
      final cases = <(int, Object?, SoulFailureKind)>[
        (404, soulProfileMissing, SoulFailureKind.profileGone),
        (404, soulRouteMissing, SoulFailureKind.unsupported),
        (405, {'detail': 'Method Not Allowed'}, SoulFailureKind.unsupported),
        (400, soulBadName, SoulFailureKind.badRequest),
        (422, soulMissingContent, SoulFailureKind.validation),
        (500, soulPlainServerError, SoulFailureKind.server),
      ];
      for (final (status, body, kind) in cases) {
        server.on('PUT', soulPath, body, status: status);
        expect(
          await failureOf(repository.write(soulProfile, 'x')),
          kind,
          reason: '$status $body',
        );
      }
    });

    test('a 401 is not swallowed', () async {
      server.on('PUT', soulPath, soulUnauthorized, status: 401);
      await expectLater(
        repository.write(soulProfile, 'x'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'code',
            401,
          ),
        ),
      );
    });

    test(
      'a timeout or dropped connection is a lost answer, sent once',
      () async {
        for (final make in <DioException Function(RequestOptions)>[
          (r) => DioException.receiveTimeout(
            timeout: const Duration(seconds: 10),
            requestOptions: r,
          ),
          (r) => DioException.connectionTimeout(
            timeout: const Duration(seconds: 10),
            requestOptions: r,
          ),
          (r) =>
              DioException.connectionError(requestOptions: r, reason: 'reset'),
        ]) {
          server.requests.clear();
          server.onRequest('PUT', soulPath, (request) => throw make(request));
          expect(
            await failureOf(repository.write(soulProfile, 'x')),
            SoulFailureKind.lostAnswer,
          );
          expect(server.requestsTo('PUT', soulPath), hasLength(1));
        }
      },
    );

    test('failure messages never carry the server body or the text', () async {
      server.on('PUT', soulPath, {
        'detail': 'Could not write SOUL.md: /srv/secret-home',
      }, status: 500);
      try {
        await repository.write(soulProfile, 'private words');
        fail('expected a failure');
      } on SoulFailure catch (failure) {
        expect('$failure ${failure.message}', isNot(contains('secret')));
        expect('$failure ${failure.message}', isNot(contains('private')));
        expect('$failure', isNot(contains(soulProfile)));
      }
    });
  });
}
