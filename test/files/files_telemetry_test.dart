import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart' show StatusCode;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/files/files_failure.dart';
import 'package:hermes_app/src/files/files_models.dart';
import 'package:hermes_app/src/files/files_telemetry.dart';
import 'package:hermes_app/src/files/hermes_files_repository.dart';
import 'package:hermes_app/src/files/server_path.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_hermes_server.dart';
import '../support/fs_download_adapter.dart';
import '../support/recorded_events.dart';
import '../support/recording_tracer.dart';

ServerPath p(String text) => ServerPath.tryParse(text)!;

const _server = {'hermes.version': '0.14.2'};

/// Everything the path, name or content could hide in.
const _secrets = ['hunter2', 'my-secret-project', 'quarterly.xlsx', 'work'];

void main() {
  late FakeHermesServer server;
  late RecordingTracer tracer;
  late RecordedEvents events;
  late HermesFilesRepository repository;
  late Directory temp;

  HermesFilesRepository build(
    HermesApiClient client, {
    Duration idle = const Duration(seconds: 30),
    RecordingTracer? withTracer,
  }) => HermesFilesRepository(
    client,
    profile: 'work',
    idleTimeout: idle,
    telemetry: FilesTelemetry(
      ConnectionTelemetry(
        events: events.call,
        tracer: withTracer ?? tracer,
        serverAttributes: _server,
      ),
    ),
  );

  setUp(() {
    server = FakeHermesServer();
    tracer = RecordingTracer();
    events = RecordedEvents();
    repository = build(server.client());
    temp = Directory.systemTemp.createTempSync('files_telemetry_test');
  });
  tearDown(() => temp.deleteSync(recursive: true));

  /// Every string any span or event of the test carries.
  String recorded() => [
    for (final span in tracer.spans) ...[
      span.name,
      ...span.attributes.keys,
      ...span.attributes.values.map((v) => '$v'),
      ...span.events,
      '${span.statusDescription}',
    ],
    events.namesStartingWith('').join(' '),
    for (final name in events.namesStartingWith(''))
      ...events
          .named(name)
          .expand((a) => [...a.keys, ...a.values.map((v) => '$v')]),
  ].join('\n');

  void expectNothingSecret(String text) {
    for (final secret in _secrets) {
      expect(text, isNot(contains(secret)));
    }
    expect(text, isNot(contains('/srv')));
    expect(text, isNot(contains('hermes.test')));
  }

  test('buckets', () {
    expect([0, 1, 50, 51, 500, 501].map(filesEntriesBucket), [
      '0',
      '1-50',
      '1-50',
      '51-500',
      '51-500',
      '>500',
    ]);
    expect(
      [
        0,
        102399,
        102400,
        5242879,
        5242880,
        52428799,
        52428800,
      ].map(filesSizeBucket),
      ['<100KB', '<100KB', '<5MB', '<5MB', '<50MB', '<50MB', '>=50MB'],
    );
  });

  group('files.list', () {
    test(
      'carries the outcome and an entries bucket, with the server attributes',
      () async {
        server.on('GET', '/api/fs/list', {
          'entries': [
            for (var i = 0; i < 60; i++)
              {
                'name': 'quarterly.xlsx$i',
                'path': '/srv/my-secret-project/quarterly.xlsx$i',
                'isDirectory': false,
              },
          ],
        });

        await repository.list(p('/srv/my-secret-project'));

        final span = tracer.spans.single;
        expect(span.name, 'files.list');
        expect(span.attributes, {
          ..._server,
          'outcome': 'ok',
          'entries': '51-500',
        });
        expect(span.ended, isTrue);
        expect(events.namesStartingWith('files.'), isEmpty);
        expectNothingSecret(recorded());
      },
    );

    test('a failure ends the span as failed and logs files.list_failed with the kind only', () async {
      server.on('GET', '/api/fs/list', {'detail': 'x'}, status: 403);

      await repository.list(p('/srv/my-secret-project'));

      final span = tracer.spans.single;
      expect(span.attributes['outcome'], 'failed');
      expect(span.attributes, isNot(contains('entries')));
      expect(span.status, StatusCode.error);
      expect(events.named('files.list_failed'), [
        {'kind': 'notAllowed'},
      ]);
      expectNothingSecret(recorded());
    });

    test('a 200 with an error is logged by its kind', () async {
      server.on('GET', '/api/fs/list', {'entries': [], 'error': 'ENOENT'});
      await repository.list(p('/srv/p'));
      expect(events.named('files.list_failed'), [
        {'kind': 'missing'},
      ]);
    });

    test('a cancel is not a failure', () async {
      server.on('GET', '/api/fs/list', {'entries': []});
      await repository.list(p('/srv/p'), cancelToken: CancelToken()..cancel());
      expect(tracer.spans.single.attributes['outcome'], 'cancelled');
      expect(events.named('files.list_failed'), isEmpty);
    });
  });

  group('files.download', () {
    Future<FilesResult<FsDownload>> download(
      HermesFilesRepository r, {
      CancelToken? cancel,
      bool allowLarge = false,
    }) async {
      final sink = File('${temp.path}/f').openWrite();
      final result = await r.download(
        p('/srv/my-secret-project/quarterly.xlsx'),
        sink: sink,
        cancelToken: cancel,
        allowLarge: allowLarge,
      );
      await sink.close();
      return result;
    }

    test('carries only outcome, a size bucket and length_known', () async {
      server.on('GET', '/api/fs/download', Uint8List(2048));

      await download(repository);

      final span = tracer.spans.single;
      expect(span.name, 'files.download');
      expect(span.attributes, {
        ..._server,
        'outcome': 'done',
        'size': '<100KB',
        'length_known': false,
      });
      expect(events.namesStartingWith('files.'), isEmpty);
      expectNothingSecret(recorded());
    });

    test(
      'a known length decides the bucket, and a question is too_large',
      () async {
        final adapter = FsDownloadAdapter(length: 212 * 1024 * 1024);

        await download(build(adapter.client()));

        expect(tracer.spans.single.attributes, {
          ..._server,
          'outcome': 'too_large',
          'size': '>=50MB',
          'length_known': true,
        });
      },
    );

    test(
      'a failure is failed, with files.download_failed and its kind',
      () async {
        server.on('GET', '/api/fs/download', {'detail': 'x'}, status: 409);

        await download(repository);

        expect(tracer.spans.single.attributes['outcome'], 'failed');
        expect(tracer.spans.single.status, StatusCode.error);
        expect(events.named('files.download_failed'), [
          {'kind': 'busy'},
        ]);
        expectNothingSecret(recorded());
      },
    );

    test('a cancel is cancelled and not logged as a failure', () async {
      final adapter = FsDownloadAdapter(length: 100);
      final token = CancelToken();
      final future = download(build(adapter.client()), cancel: token);
      await pumpEventQueue();
      token.cancel();
      await future;

      expect(tracer.spans.single.attributes['outcome'], 'cancelled');
      expect(events.named('files.download_failed'), isEmpty);
    });
  });

  group('files.unsupported', () {
    test('is logged once per connection', () async {
      server.on('GET', '/api/fs/default-cwd', {
        'detail': 'Not Found',
      }, status: 404);

      await repository.probe();
      await repository.probe();

      expect(events.named('files.unsupported'), hasLength(1));
      expect(events.named('files.unsupported').single, isEmpty);
    });

    test('is not logged for another failure', () async {
      server.on('GET', '/api/fs/default-cwd', {}, status: 500);
      await repository.probe();
      expect(events.namesStartingWith('files.'), isEmpty);
    });
  });

  test('a tracer that throws never breaks a call', () async {
    final broken = build(server.client(), withTracer: ThrowingTracer());
    server.on('GET', '/api/fs/list', {'entries': []});
    expect(await broken.list(p('/srv/p')), isA<FilesOk<FsListing>>());
    final sink = File('${temp.path}/g').openWrite();
    server.on('GET', '/api/fs/download', Uint8List(1));
    expect(
      await broken.download(p('/srv/p/a'), sink: sink),
      isA<FilesOk<FsDownload>>(),
    );
    await sink.close();
  });

  group('a failed request never carries its URL or path', () {
    const path = '/srv/my-secret-project/.env';

    /// What a Dio failure would print: its URI holds `?path=`.
    DioException failing(RequestOptions o, DioExceptionType type) =>
        DioException(
          requestOptions: o,
          type: type,
          error: SocketException('connect to ${o.uri}'),
          message: 'failed ${o.uri}',
        );

    test('list, read-text and a download reach the caller as a kind', () async {
      for (final type in [
        DioExceptionType.connectionError,
        DioExceptionType.receiveTimeout,
        DioExceptionType.unknown,
      ]) {
        for (final route in [
          '/api/fs/list',
          '/api/fs/read-text',
          '/api/fs/download',
        ]) {
          server.onRequest('GET', route, (o) => throw failing(o, type));
        }
        final results = <Object>[
          await repository.list(p(path)),
          await repository.readText(p(path)),
        ];
        final sink = File('${temp.path}/h').openWrite();
        results.add(await repository.download(p(path), sink: sink));
        await sink.close();

        for (final result in results) {
          expect(result, isA<FilesFailed<Object?>>());
          final text = '$result';
          expect(text, isNot(contains('secret')));
          expect(text, isNot(contains('.env')));
          expect(text, isNot(contains('hermes.test')));
        }
      }
      expectNothingSecret(recorded());
      expect(recorded(), isNot(contains('.env')));
    });

    test('downloadFsFile throws only a kind', () async {
      server.onRequest(
        'GET',
        '/api/fs/download',
        (o) => throw failing(o, DioExceptionType.connectionError),
      );
      final sink = File('${temp.path}/i').openWrite();

      Object? thrown;
      try {
        await server.client().downloadFsFile(path, sink: sink, profile: 'work');
      } on Object catch (error) {
        thrown = error;
      }
      await sink.close();

      expect(thrown, isA<FsDownloadException>());
      expect('$thrown', 'FsDownloadException(unreachable)');
      expect('$thrown', isNot(contains('secret')));
    });

    test(
      'an unreadable body is a kind, with no text of the exception',
      () async {
        server.on('GET', '/api/fs/list', {'entries': 'x hunter2'});
        final result = await repository.list(p(path));
        expect(result, isA<FilesFailed<FsListing>>());
        expectNothingSecret(recorded());
      },
    );
  });
}
