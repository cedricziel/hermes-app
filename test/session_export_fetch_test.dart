import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/api/request_timeout.dart';
import 'package:hermes_app/src/chat/session_export.dart';
import 'package:hermes_app/src/chat/widgets/session_export_failure.dart';

import 'support/fake_hermes_server.dart';

/// Serves a body in chunks the test releases one by one.
class _ChunkedServer implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  // Closed by each test that finishes the body.
  // ignore: close_sinks
  final chunks = StreamController<Uint8List>();
  bool cancelled = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    unawaited(cancelFuture?.then((_) => cancelled = true));
    return ResponseBody(
      chunks.stream,
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _fixture(String name) => jsonDecode(
  File('test/fixtures/session_export/$name.json').readAsStringSync(),
) as Map<String, dynamic>;

Uint8List _body(String fixture) =>
    Uint8List.fromList(utf8.encode(jsonEncode(_fixture(fixture)['body'])));

DioException _status(int code, [Object? body]) {
  final options = RequestOptions(path: '/api/sessions/x/export');
  return DioException.badResponse(
    statusCode: code,
    requestOptions: options,
    response: Response(
      requestOptions: options,
      statusCode: code,
      data: body is Map ? utf8.encode(jsonEncode(body)) : body,
    ),
  );
}

void main() {
  group('fetchSessionExport', () {
    test('returns the raw bytes and sends the profile', () async {
      final raw = _body('short');
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions/abc/export', raw);

      final bytes = await server.client().fetchSessionExport(
        'abc',
        profile: 'work',
      );

      expect(bytes, raw);
      final request = server.requests.single;
      expect(request.queryParameters['profile'], 'work');
      expect(request.responseType, ResponseType.bytes);
    });

    test('percent-encodes the id', () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions/a%2Fb%20%3F%23/export', Uint8List(0));

      await server.client().fetchSessionExport('a/b ?#', profile: 'p');

      expect(
        server.requests.single.path,
        '/api/sessions/a%2Fb%20%3F%23/export',
      );
    });

    test('reports increasing received bytes', () async {
      final server = _ChunkedServer();
      final seen = <int>[];
      final done = HermesApiClient(
        Dio(BaseOptions(baseUrl: 'http://hermes.test'))
          ..httpClientAdapter = server,
      ).fetchSessionExport('a', profile: 'p', onProgress: seen.add);

      server.chunks.add(Uint8List(10));
      await Future<void>.delayed(Duration.zero);
      server.chunks.add(Uint8List(25));
      await Future<void>.delayed(Duration.zero);
      await server.chunks.close();
      final bytes = await done;

      expect(bytes.length, 35);
      expect(seen, isNotEmpty);
      expect(seen.last, 35);
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThan(seen[i - 1]));
      }
    });

    test('cancel stops the request and is its own outcome', () async {
      final server = _ChunkedServer();
      final token = CancelToken();
      final done = HermesApiClient(
        Dio(BaseOptions(baseUrl: 'http://hermes.test'))
          ..httpClientAdapter = server,
      ).fetchSessionExport('a', profile: 'p', cancelToken: token);
      final failure = expectLater(done, throwsA(isA<SessionExportCancelled>()));

      while (server.requests.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      server.chunks.add(Uint8List(5));
      await Future<void>.delayed(Duration.zero);
      token.cancel();
      await failure;
      await Future<void>.delayed(Duration.zero);
      expect(server.cancelled, isTrue);
    });

    test(
      'a failed answer throws only its kind, free of chat details',
      () async {
        const idMark = 'ID-MARK-7c1';
        const profileMark = 'PROFILE-MARK-7c1';
        const bodyMark = 'BODY-MARK-7c1';
        final server = FakeHermesServer()
          ..on('GET', '/api/sessions/$idMark/export', {
            'detail': 'Session not found $bodyMark',
          }, status: 404);

        Object? thrown;
        try {
          await server.client().fetchSessionExport(
            idMark,
            profile: profileMark,
          );
        } on Object catch (e) {
          thrown = e;
        }

        expect(thrown, isA<SessionExportRequestFailed>());
        expect(
          (thrown! as SessionExportRequestFailed).kind,
          SessionExportFailure.unsupported,
        );
        expect('$thrown', 'SessionExportRequestFailed');
        for (final mark in [idMark, profileMark, bodyMark, 'hermes.test']) {
          expect('$thrown', isNot(contains(mark)));
        }
      },
    );

    test('a 404 with the recorded detail is gone', () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions/x/export', {
          'detail': 'Session not found',
        }, status: 404);

      await expectLater(
        server.client().fetchSessionExport('x', profile: 'p'),
        throwsA(
          isA<SessionExportRequestFailed>().having(
            (e) => e.kind,
            'kind',
            SessionExportFailure.gone,
          ),
        ),
      );
    });

    test('a store-busy 404 is unsupported', () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions/x/export', {
          'detail': 'Profile store busy',
        }, status: 404);

      await expectLater(
        server.client().fetchSessionExport('x', profile: 'p'),
        throwsA(
          isA<SessionExportRequestFailed>().having(
            (e) => e.kind,
            'kind',
            SessionExportFailure.unsupported,
          ),
        ),
      );
    });

    test('an error body never reports progress', () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions/x/export', {
          'detail': 'Session not found',
        }, status: 404);
      final seen = <int>[];

      await expectLater(
        server.client().fetchSessionExport(
          'x',
          profile: 'p',
          onProgress: seen.add,
        ),
        throwsA(isA<SessionExportRequestFailed>()),
      );
      expect(seen, isEmpty);
    });

    test('carries the 5-minute request deadline', () async {
      final server = FakeHermesServer()
        ..on('GET', '/api/sessions/x/export', Uint8List(0));

      await server.client().fetchSessionExport('x', profile: 'p');

      final extra = server.requests.single.extra;
      final expected = requestDeadlineExtra(const Duration(minutes: 5));
      for (final entry in expected.entries) {
        expect(extra[entry.key], entry.value);
      }
    });

    test('ids that cannot name one chat throw without the value', () async {
      final server = FakeHermesServer();
      for (final id in ['', '.', '..']) {
        Object? thrown;
        try {
          await server.client().fetchSessionExport(id, profile: 'p');
        } on Object catch (e) {
          thrown = e;
        }
        expect(thrown, isA<ArgumentError>(), reason: "'$id'");
        expect((thrown! as ArgumentError).invalidValue, isNull);
        expect(server.requests, isEmpty);
      }
    });

    test('a drop after bytes is incomplete, without bytes failed', () async {
      Future<(Object?, DioExceptionType?)> run({
        required bool withBytes,
      }) async {
        final server = _ChunkedServer();
        final done = HermesApiClient(
          Dio(BaseOptions(baseUrl: 'http://hermes.test'))
            ..httpClientAdapter = server,
        ).fetchSessionExport('a', profile: 'p');
        final result = done.then<Object?>(
          (_) => null,
          onError: (Object e) => e,
        );
        while (server.requests.isEmpty) {
          await Future<void>.delayed(Duration.zero);
        }
        if (withBytes) {
          server.chunks.add(Uint8List(5));
          await Future<void>.delayed(Duration.zero);
        }
        server.chunks.addError(
          const HttpException('Connection closed while receiving data'),
        );
        return (await result, null);
      }

      final withBytes = (await run(withBytes: true)).$1;
      expect(
        withBytes,
        isA<SessionExportRequestFailed>().having(
          (e) => e.kind,
          'kind',
          SessionExportFailure.incomplete,
        ),
      );
      final without = (await run(withBytes: false)).$1;
      expect(
        without,
        isA<SessionExportRequestFailed>().having(
          (e) => e.kind,
          'kind',
          SessionExportFailure.failed,
        ),
      );
    });
  });

  group('classifySessionExportError', () {
    SessionExportFailure kind(DioException e, {bool receivedAny = false}) =>
        classifySessionExportError(e, receivedAny: receivedAny);

    test('maps the recorded answers', () {
      for (final (name, expected) in [
        ('unknown_id', SessionExportFailure.gone),
        ('other_profile', SessionExportFailure.gone),
        ('unknown_profile', SessionExportFailure.profileMissing),
        ('invalid_profile', SessionExportFailure.profileInvalid),
        ('wrong_route', SessionExportFailure.unsupported),
        ('wrong_method', SessionExportFailure.unsupported),
      ]) {
        final recorded = _fixture(name);
        final error = _status(recorded['status'] as int, recorded['body']);
        expect(kind(error), expected, reason: name);
      }
    });

    test('maps the other statuses', () {
      expect(
        kind(_status(404, {'detail': 'nope'})),
        SessionExportFailure.unsupported,
      );
      expect(kind(_status(404)), SessionExportFailure.unsupported);
      expect(kind(_status(503)), SessionExportFailure.unreadable);
      for (final code in [500, 502, 504, 413, 422, 401]) {
        expect(
          kind(_status(code)),
          SessionExportFailure.failed,
          reason: '$code',
        );
      }
    });

    test('maps timeouts by whether a byte arrived', () {
      final options = RequestOptions(path: '/x');
      DioException of(DioExceptionType type) =>
          DioException(requestOptions: options, type: type);

      expect(
        kind(of(DioExceptionType.connectionTimeout)),
        SessionExportFailure.offline,
      );
      expect(
        kind(of(DioExceptionType.receiveTimeout)),
        SessionExportFailure.lost,
      );
      expect(
        kind(of(DioExceptionType.receiveTimeout), receivedAny: true),
        SessionExportFailure.incomplete,
      );
      expect(
        kind(of(DioExceptionType.connectionError)),
        SessionExportFailure.offline,
      );
      expect(
        kind(of(DioExceptionType.connectionError), receivedAny: true),
        SessionExportFailure.incomplete,
      );
      expect(kind(of(DioExceptionType.unknown)), SessionExportFailure.failed);
      expect(
        kind(of(DioExceptionType.unknown), receivedAny: true),
        SessionExportFailure.incomplete,
      );
      expect(kind(of(DioExceptionType.cancel)), SessionExportFailure.failed);
    });
  });

  group('decodeSessionExport', () {
    test('counts the messages of every recorded export', () async {
      for (final name in ['short', 'tools', 'undone', 'compacted']) {
        final messages = (_fixture(name)['body'] as Map)['messages'] as List;
        final file = await decodeSessionExport(_body(name));
        expect(file.messageCount, messages.length, reason: name);
      }
    });

    test('decodes above 1 MB in an isolate', () async {
      final big = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'id': 's',
            'messages': [
              {'content': 'x' * (1024 * 1024 + 1)},
            ],
          }),
        ),
      );

      expect((await decodeSessionExport(big)).messageCount, 1);
    });

    test('rejects what is not a whole session', () async {
      for (final text in [
        '[]',
        '{"id": 1, "messages": []}',
        '{"id": "s"}',
        '{"id": "s", "messages": {}}',
        '',
      ]) {
        await expectLater(
          decodeSessionExport(Uint8List.fromList(utf8.encode(text))),
          throwsA(isA<SessionExportIncomplete>()),
          reason: text,
        );
      }
    });

    test('a truncated body never leaks its text into an error', () async {
      const marker = 'SECRET-MARKER-9f3a';
      final whole = jsonEncode({
        'id': 's',
        'messages': [
          {'content': 'before $marker after'},
        ],
      });
      final cut = whole.substring(0, whole.indexOf('after'));
      for (final body in [cut, '$cut${'y' * (1024 * 1024 + 1)}']) {
        Object? thrown;
        try {
          await decodeSessionExport(Uint8List.fromList(utf8.encode(body)));
        } on Object catch (e) {
          thrown = e;
        }
        expect(thrown, isA<SessionExportIncomplete>());
        expect('$thrown', isNot(contains(marker)));
        expect('$thrown', isNot(contains('before')));
      }
    });
  });
}
