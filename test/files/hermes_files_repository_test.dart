import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/files_failure.dart';
import 'package:hermes_app/src/files/files_models.dart';
import 'package:hermes_app/src/files/hermes_files_repository.dart';
import 'package:hermes_app/src/files/server_path.dart';

import '../support/fake_hermes_server.dart';
import '../support/fs_download_adapter.dart';

ServerPath p(String text) => ServerPath.tryParse(text)!;

T ok<T>(FilesResult<T> result) {
  expect(result, isA<FilesOk<T>>(), reason: '$result');
  return (result as FilesOk<T>).value;
}

FilesFailure failure<T>(FilesResult<T> result) {
  expect(result, isA<FilesFailed<T>>(), reason: '$result');
  return (result as FilesFailed<T>).kind;
}

Map<String, Object?> row(String name, String path, {Object? dir = false}) => {
  'name': name,
  'path': path,
  'isDirectory': dir,
};

void main() {
  late FakeHermesServer server;
  late HermesFilesRepository repository;
  late Directory temp;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesFilesRepository(server.client(), profile: 'work');
    temp = Directory.systemTemp.createTempSync('files_repo_test');
  });
  tearDown(() => temp.deleteSync(recursive: true));

  group('list', () {
    test('reads entries in the server\'s order', () async {
      server.on('GET', '/api/fs/list', {
        'entries': [
          row('reports', '/srv/p/reports', dir: true),
          row('a.txt', '/srv/p/a.txt'),
        ],
      });

      final listing = ok(await repository.list(p('/srv/p')));

      expect(listing.entries.map((e) => e.name), ['reports', 'a.txt']);
      expect(listing.entries.first.isDirectory, isTrue);
      expect(listing.entries.last.isDirectory, isFalse);
      expect(listing.entries.first.path.value, '/srv/p/reports');
      expect(listing.skipped, 0);
    });

    test('skips rows that do not fit and counts them', () async {
      server.on('GET', '/api/fs/list', {
        'entries': [
          row('ok.txt', '/srv/p/ok.txt', dir: null),
          {'path': '/srv/p/noname'},
          {'name': 'nopath'},
          row('relative', 'relative/path'),
          row('', '/srv/p/empty'),
          'not an object',
          row('dotdot', '/srv/p/../etc'),
        ],
      });

      final listing = ok(await repository.list(p('/srv/p')));

      expect(listing.entries.map((e) => e.name), ['ok.txt']);
      expect(listing.entries.single.isDirectory, isFalse);
      expect(listing.skipped, 6);
    });

    test(
      'a body that is not an object, or has no entries, is unreadable',
      () async {
        server.on('GET', '/api/fs/list', ['entries']);
        expect(
          failure(await repository.list(p('/srv/p'))),
          FilesFailure.unreadable,
        );
        server.on('GET', '/api/fs/list', {'unrelated': 1});
        expect(
          failure(await repository.list(p('/srv/p'))),
          FilesFailure.unreadable,
        );
      },
    );

    test('a 200 with an error is a failure, not an empty folder', () async {
      const expected = {
        'ENOENT': FilesFailure.missing,
        'ENOTDIR': FilesFailure.notAFile,
        'EACCES': FilesFailure.notAllowed,
        'EPERM': FilesFailure.notAllowed,
        'ECONN': FilesFailure.workspaceDown,
        'read-error': FilesFailure.unreadable,
        'Something odd': FilesFailure.unreadable,
      };
      for (final MapEntry(:key, :value) in expected.entries) {
        server.on('GET', '/api/fs/list', {'entries': [], 'error': key});
        expect(failure(await repository.list(p('/srv/p'))), value, reason: key);
      }
      server.on('GET', '/api/fs/list', {'entries': [], 'error': true});
      expect(
        failure(await repository.list(p('/srv/p'))),
        FilesFailure.unreadable,
      );
    });

    test('an empty or null error is an empty folder', () async {
      for (final error in [null, '']) {
        server.on('GET', '/api/fs/list', {'entries': [], 'error': error});
        expect(ok(await repository.list(p('/srv/p'))).entries, isEmpty);
      }
    });

    test('every status maps to its kind', () async {
      const expected = {
        400: FilesFailure.badRequest,
        401: FilesFailure.unreadable,
        403: FilesFailure.notAllowed,
        404: FilesFailure.missing,
        405: FilesFailure.unreadable,
        409: FilesFailure.busy,
        413: FilesFailure.tooLarge,
        500: FilesFailure.unreadable,
        502: FilesFailure.unreachable,
        503: FilesFailure.workspaceDown,
        504: FilesFailure.unreachable,
      };
      for (final MapEntry(:key, :value) in expected.entries) {
        server.on('GET', '/api/fs/list', {'detail': 'x'}, status: key);
        expect(
          failure(await repository.list(p('/srv/p'))),
          value,
          reason: '$key',
        );
      }
    });

    test('a 404 about a profile, and an invalid one, are badRequest', () async {
      server.on('GET', '/api/fs/list', {
        'detail': "Profile 'work' does not exist.",
      }, status: 404);
      expect(
        failure(await repository.list(p('/srv/p'))),
        FilesFailure.badRequest,
      );
      server.on('GET', '/api/fs/list', {
        'detail': 'Invalid profile',
      }, status: 400);
      expect(
        failure(await repository.list(p('/srv/p'))),
        FilesFailure.badRequest,
      );
    });

    test('a missing folder on an SSH workspace is missing', () async {
      server.on('GET', '/api/fs/list', {
        'detail': 'Folder not found',
      }, status: 404);
      expect(failure(await repository.list(p('/srv/p'))), FilesFailure.missing);
    });

    test('network failures are unreachable, a cancel is cancelled', () async {
      server.onRequest(
        'GET',
        '/api/fs/list',
        (o) => throw DioException.connectionTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: o,
        ),
      );
      expect(
        failure(await repository.list(p('/srv/p'))),
        FilesFailure.unreachable,
      );

      final token = CancelToken()..cancel();
      server.on('GET', '/api/fs/list', {'entries': []});
      expect(
        failure(await repository.list(p('/srv/p'), cancelToken: token)),
        FilesFailure.cancelled,
      );
    });
  });

  group('readText', () {
    test('reads the fields', () async {
      server.on('GET', '/api/fs/read-text', {
        'binary': false,
        'byteSize': 1834,
        'language': 'python',
        'mimeType': 'text/x-python',
        'path': '/srv/p/app.py',
        'text': 'print(1)',
        'truncated': false,
      });

      final file = ok(await repository.readText(p('/srv/p/app.py')));

      expect(file.text, 'print(1)');
      expect(file.byteSize, 1834);
      expect(file.language, 'python');
      expect(file.mimeType, 'text/x-python');
      expect(file.truncated, isFalse);
      expect(file.binary, isFalse);
    });

    test('keeps truncated and binary, and tolerates missing fields', () async {
      server.on('GET', '/api/fs/read-text', {'text': 'abc', 'truncated': true});
      final file = ok(await repository.readText(p('/srv/p/a.log')));
      expect(file.truncated, isTrue);
      expect(file.byteSize, 3);
      expect(file.language, isNull);

      server.on('GET', '/api/fs/read-text', {'binary': true, 'byteSize': 9});
      final binary = ok(await repository.readText(p('/srv/p/a.bin')));
      expect(binary.binary, isTrue);
      expect(binary.text, isEmpty);
    });

    test(
      'a body without text, or that is not an object, is unreadable',
      () async {
        server.on('GET', '/api/fs/read-text', {'byteSize': 3});
        expect(
          failure(await repository.readText(p('/srv/p/a'))),
          FilesFailure.unreadable,
        );
        server.on('GET', '/api/fs/read-text', 'text');
        expect(
          failure(await repository.readText(p('/srv/p/a'))),
          FilesFailure.unreadable,
        );
      },
    );

    test('maps the statuses of a file', () async {
      const cases = [
        (400, 'Path points to a directory', FilesFailure.notAFile),
        (400, 'Only regular files can be read', FilesFailure.notAFile),
        (400, 'Invalid path', FilesFailure.badRequest),
        (403, 'File is not readable', FilesFailure.notAllowed),
        (
          403,
          'Access to sensitive files is not allowed',
          FilesFailure.notAllowed,
        ),
        (404, 'File not found', FilesFailure.missing),
        (404, "Profile 'x' does not exist.", FilesFailure.badRequest),
        (409, 'busy', FilesFailure.busy),
        (413, 'File too large', FilesFailure.tooLarge),
        (503, 'SSH workspace is unavailable', FilesFailure.workspaceDown),
        (500, 'boom', FilesFailure.unreadable),
      ];
      for (final (status, detail, kind) in cases) {
        server.on('GET', '/api/fs/read-text', {
          'detail': detail,
        }, status: status);
        expect(
          failure(await repository.readText(p('/srv/p/a'))),
          kind,
          reason: '$status $detail',
        );
      }
    });
  });

  group('the probe and the start folder', () {
    test('the probe is sent without a profile and keeps no folder', () async {
      server.on('GET', '/api/fs/default-cwd', {'cwd': '/home/other'});

      final result = await repository.probe();

      expect(result, isA<FilesOk<void>>());
      expect(server.requests.single.queryParameters, isEmpty);
    });

    test(
      '404 and 405 on the probe are unsupported, other failures are not',
      () async {
        for (final status in [404, 405]) {
          server.on('GET', '/api/fs/default-cwd', {
            'detail': 'Not Found',
          }, status: status);
          expect(await repository.probe(), isA<FilesUnsupported<void>>());
        }
        server.on('GET', '/api/fs/default-cwd', {'detail': 'x'}, status: 500);
        expect(failure(await repository.probe()), FilesFailure.unreadable);
        server.on('GET', '/api/fs/default-cwd', {'detail': 'x'}, status: 502);
        expect(failure(await repository.probe()), FilesFailure.unreachable);

        server.onRequest(
          'GET',
          '/api/fs/default-cwd',
          (o) => throw DioException.receiveTimeout(
            timeout: const Duration(seconds: 1),
            requestOptions: o,
          ),
        );
        expect(failure(await repository.probe()), FilesFailure.unreachable);
      },
    );

    test('the start folder is asked with the chat\'s profile', () async {
      server.on('GET', '/api/fs/default-cwd', {
        'cwd': '/srv/work',
        'branch': 'main',
      });

      expect(ok(await repository.defaultCwd()).value, '/srv/work');
      expect(server.requests.single.queryParameters, {'profile': 'work'});
    });

    test('the start folder: 404 about a profile is badRequest, 404 or 405 is unsupported', () async {
      server.on('GET', '/api/fs/default-cwd', {
        'detail': "Profile 'work' does not exist.",
      }, status: 404);
      expect(failure(await repository.defaultCwd()), FilesFailure.badRequest);
      server.on('GET', '/api/fs/default-cwd', {
        'detail': 'Not Found',
      }, status: 404);
      expect(
        await repository.defaultCwd(),
        isA<FilesUnsupported<ServerPath>>(),
      );
      server.on('GET', '/api/fs/default-cwd', {}, status: 405);
      expect(
        await repository.defaultCwd(),
        isA<FilesUnsupported<ServerPath>>(),
      );
    });

    test('a start folder that is not a path is unreadable', () async {
      for (final body in [
        {'cwd': 'relative'},
        {'cwd': 3},
        <String, Object?>{},
        'x',
      ]) {
        server.on('GET', '/api/fs/default-cwd', body);
        expect(failure(await repository.defaultCwd()), FilesFailure.unreadable);
      }
    });

    test('git root: a folder, null, or a failure', () async {
      server.on('GET', '/api/fs/git-root', {'root': '/srv/p'});
      expect(ok(await repository.gitRoot(p('/srv/p/sub')))?.value, '/srv/p');
      server.on('GET', '/api/fs/git-root', {'root': null});
      expect(ok(await repository.gitRoot(p('/srv/p/sub'))), isNull);
      server.on('GET', '/api/fs/git-root', {'root': 'nope'});
      expect(
        failure(await repository.gitRoot(p('/srv/p/sub'))),
        FilesFailure.unreadable,
      );
      server.on('GET', '/api/fs/git-root', {}, status: 503);
      expect(
        failure(await repository.gitRoot(p('/srv/p/sub'))),
        FilesFailure.workspaceDown,
      );
    });
  });

  group('requests', () {
    test('a browse, a preview and a download send the profile every time, only GETs on the routes in the spec, never a token', () async {
      server
        ..on('GET', '/api/fs/default-cwd', {'cwd': '/srv/p'})
        ..on('GET', '/api/fs/git-root', {'root': '/srv/p'})
        ..on('GET', '/api/fs/list', {
          'entries': [row('a.txt', '/srv/p/a.txt')],
        })
        ..on('GET', '/api/fs/read-text', {'text': 'hi', 'byteSize': 2})
        ..on('GET', '/api/fs/download', Uint8List.fromList([1, 2, 3]));

      ok(await repository.defaultCwd());
      ok(await repository.gitRoot(p('/srv/p')));
      ok(await repository.list(p('/srv/p')));
      ok(await repository.readText(p('/srv/p/a.txt')));
      final sink = File('${temp.path}/a.txt').openWrite();
      ok(await repository.download(p('/srv/p/a.txt'), sink: sink));
      await sink.close();

      expect(server.requests, hasLength(5));
      for (final request in server.requests) {
        expect(request.method, 'GET');
        expect(request.queryParameters['profile'], 'work');
        expect(request.uri.toString(), isNot(contains('token')));
        expect(request.queryParameters.keys, isNot(contains('token')));
      }
      expect(server.requests.map((r) => r.path).toSet(), {
        '/api/fs/default-cwd',
        '/api/fs/git-root',
        '/api/fs/list',
        '/api/fs/read-text',
        '/api/fs/download',
      });
      expect(server.requests.map((r) => r.queryParameters['path']), [
        null,
        '/srv/p',
        '/srv/p',
        '/srv/p/a.txt',
        '/srv/p/a.txt',
      ]);
    });

    test('without a profile it asks for default', () async {
      final plain = HermesFilesRepository(server.client());
      server.on('GET', '/api/fs/list', {'entries': []});
      ok(await plain.list(p('/srv/p')));
      expect(server.requests.single.queryParameters['profile'], 'default');
    });

    test('a path goes in the query, encoded, never in the URL path', () async {
      server.on('GET', '/api/fs/list', {'entries': []});
      ok(await repository.list(p('/srv/my docs/a&b?c#d')));
      final request = server.requests.single;
      expect(request.path, '/api/fs/list');
      expect(request.queryParameters['path'], '/srv/my docs/a&b?c#d');
      expect(request.uri.queryParameters['path'], '/srv/my docs/a&b?c#d');
    });
  });

  group('the highest folder', () {
    setUp(() => repository.highestFolder = p('/srv/app'));

    test('requests nothing outside it, by whole components', () async {
      for (final outside in ['/etc/passwd', '/srv/app-secrets/key', '/srv']) {
        expect(
          failure(await repository.list(p(outside))),
          FilesFailure.outside,
        );
        expect(
          failure(await repository.readText(p(outside))),
          FilesFailure.outside,
        );
        expect(
          failure(await repository.gitRoot(p(outside))),
          FilesFailure.outside,
        );
        final sink = File('${temp.path}/x').openWrite();
        expect(
          failure(await repository.download(p(outside), sink: sink)),
          FilesFailure.outside,
        );
        await sink.close();
      }
      expect(server.requests, isEmpty);
    });

    test('allows the folder itself and anything below', () async {
      server.on('GET', '/api/fs/list', {'entries': []});
      ok(await repository.list(p('/srv/app')));
      ok(await repository.list(p('/srv/app/src')));
      expect(server.requests, hasLength(2));
    });

    test('does not offer an entry outside it', () async {
      server.on('GET', '/api/fs/list', {
        'entries': [
          row('in', '/srv/app/in'),
          row('key', '/srv/app-secrets/key'),
          row('passwd', '/etc/passwd'),
        ],
      });
      final listing = ok(await repository.list(p('/srv/app')));
      expect(listing.entries.map((e) => e.name), ['in']);
      expect(listing.skipped, 2);
    });
  });

  group('downloads', () {
    Future<(FilesResult<FsDownload>, List<int>)> run(
      HermesFilesRepository repository, {
      CancelToken? cancel,
      void Function(int, int?)? onProgress,
      bool allowLarge = false,
    }) async {
      final file = File('${temp.path}/out.bin');
      final sink = file.openWrite();
      final result = await repository.download(
        p('/srv/p/out.bin'),
        sink: sink,
        cancelToken: cancel,
        onProgress: onProgress,
        allowLarge: allowLarge,
      );
      await sink.close();
      return (result, file.readAsBytesSync());
    }

    test(
      'streams the body to the sink; with no length the total is unknown',
      () async {
        server.on('GET', '/api/fs/download', Uint8List.fromList([1, 2, 3, 4]));
        final progress = <(int, int?)>[];

        final (result, written) = await run(
          repository,
          onProgress: (r, t) => progress.add((r, t)),
        );

        expect(written, [1, 2, 3, 4]);
        final done = ok(result);
        expect(done.bytes, 4);
        expect(done.contentLength, isNull);
        expect(progress.last, (4, null));
      },
    );

    test('reads the headers before the body and reports the length', () async {
      final adapter = FsDownloadAdapter(length: 6);
      final repository = HermesFilesRepository(
        adapter.client(),
        profile: 'work',
      );
      final progress = <(int, int?)>[];

      final future = run(
        repository,
        onProgress: (r, t) => progress.add((r, t)),
      );
      await pumpEventQueue();
      expect(adapter.answered, isTrue);
      expect(progress, [(0, 6)], reason: 'headers are known before any body');
      adapter.chunks
        ..add(Uint8List.fromList([1, 2, 3]))
        ..add(Uint8List.fromList([4, 5, 6]));
      await adapter.chunks.close();
      final (result, written) = await future;

      expect(written, [1, 2, 3, 4, 5, 6]);
      expect(ok(result).contentLength, 6);
      expect(progress.last, (6, 6));
    });

    test('a body shorter than its length is a failure', () async {
      final adapter = FsDownloadAdapter(length: 6);
      final repository = HermesFilesRepository(adapter.client());
      final future = run(repository);
      await pumpEventQueue();
      adapter.chunks.add(Uint8List.fromList([1, 2]));
      await adapter.chunks.close();

      expect(failure((await future).$1), FilesFailure.unreadable);
    });

    test('from 50 MB it stops after the headers and asks', () async {
      final adapter = FsDownloadAdapter(length: 212 * 1024 * 1024);
      final repository = HermesFilesRepository(adapter.client());

      final (result, written) = await run(repository);

      final head = ok(result);
      expect(head.declined, isTrue);
      expect(head.contentLength, 212 * 1024 * 1024);
      expect(written, isEmpty);
    });

    test('allowLarge goes ahead', () async {
      final adapter = FsDownloadAdapter(length: 60 * 1024 * 1024);
      final repository = HermesFilesRepository(adapter.client());
      final future = run(repository, allowLarge: true);
      await pumpEventQueue();
      adapter.chunks.add(Uint8List.fromList([9]));
      await pumpEventQueue();
      await adapter.chunks.close();

      final (result, written) = await future;
      expect(
        failure(result),
        FilesFailure.unreadable,
        reason: 'length mismatch',
      );
      expect(written, [9]);
    });

    test('no length means no question', () async {
      final adapter = FsDownloadAdapter();
      final repository = HermesFilesRepository(adapter.client());
      final future = run(repository);
      await pumpEventQueue();
      adapter.chunks.add(Uint8List.fromList([1]));
      await adapter.chunks.close();

      expect(ok((await future).$1).declined, isFalse);
    });

    test('a cancel ends it as cancelled', () async {
      final adapter = FsDownloadAdapter(length: 100);
      final repository = HermesFilesRepository(adapter.client());
      final token = CancelToken();
      final future = run(repository, cancel: token);
      await pumpEventQueue();
      adapter.chunks.add(Uint8List.fromList([1, 2]));
      await pumpEventQueue();
      token.cancel();

      expect(failure((await future).$1), FilesFailure.cancelled);
    });

    test('a stalled body fails on the idle timeout', () async {
      final adapter = FsDownloadAdapter();
      final repository = HermesFilesRepository(
        adapter.client(),
        idleTimeout: const Duration(milliseconds: 50),
      );
      final future = run(repository);
      await pumpEventQueue();
      adapter.chunks.add(Uint8List.fromList([1]));

      expect(failure((await future).$1), FilesFailure.unreachable);
    });

    test('a dropped connection fails', () async {
      final adapter = FsDownloadAdapter();
      final repository = HermesFilesRepository(adapter.client());
      final future = run(repository);
      await pumpEventQueue();
      adapter.chunks
        ..add(Uint8List.fromList([1]))
        ..addError(const SocketException('reset'));

      expect(failure((await future).$1), FilesFailure.unreachable);
    });

    test('statuses before the first byte map to their kinds', () async {
      const cases = [
        (400, 'Path points to a directory', FilesFailure.notAFile),
        (
          403,
          'Access to sensitive files is not allowed',
          FilesFailure.notAllowed,
        ),
        (404, 'File not found', FilesFailure.missing),
        (404, "Profile 'work' does not exist.", FilesFailure.badRequest),
        (409, 'database', FilesFailure.busy),
        (503, 'SSH workspace is unavailable', FilesFailure.workspaceDown),
        (500, 'boom', FilesFailure.unreadable),
      ];
      for (final (status, detail, kind) in cases) {
        server.on('GET', '/api/fs/download', {
          'detail': detail,
        }, status: status);
        final (result, written) = await run(repository);
        expect(failure(result), kind, reason: '$status $detail');
        expect(written, isEmpty);
      }
    });
  });
}
