import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/workspace_models.dart';

import 'package:flutter_otel/flutter_otel.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';

import '../support/fake_hermes_server.dart';
import '../support/recording_tracer.dart';

class _RecordingLogger extends Logger {
  final records = <LogRecord>[];

  @override
  void emit(LogRecord record) => records.add(record);
}

const _catalogBody = {
  'projects': [
    {
      'id': 'p_1a2b3c4d',
      'slug': 'demo',
      'name': 'Demo',
      'primary_path': '/home/me/code/demo',
      'archived': false,
      'folders': [
        {'path': '/home/me/code/demo/docs', 'is_primary': false},
        {'path': '/home/me/code/demo', 'label': null, 'is_primary': true},
        {'label': 'no path'},
      ],
    },
    {'id': 'p_noname'},
    {'name': 'No id'},
    'junk',
  ],
  'repos': [
    {
      'root': '/home/u/code/bar',
      'label': 'bar',
      'sessions': 12,
      'last_active': 1731500000.5,
    },
    {'label': 'no root'},
  ],
  'default_cwd': '/home/u',
  'home': '/home/u',
  'scan_enabled': true,
};

/// A path-looking marker that must never come back out of a failure.
const _secret = '/srv/secret-client-project';

void main() {
  late FakeHermesServer server;
  late List<(String, Map<String, Object?>)> calls;
  late Future<Map<String, Object?>> Function(
    String method,
    Map<String, Object?> params,
  )
  answer;
  late HermesWorkspacesRepository repository;

  HermesWorkspacesRepository build(HermesApiClient client) =>
      HermesWorkspacesRepository(client.raw, (
        method,
        params, {
        required timeout,
      }) {
        calls.add((method, params));
        return answer(method, params);
      });

  setUp(() {
    server = FakeHermesServer();
    calls = [];
    answer = (_, _) async => {};
    repository = build(server.client());
  });

  T ok<T>(WorkspacesResult<T> result) => switch (result) {
    WorkspacesOk(:final value) => value,
    _ => fail('expected a value, got $result'),
  };

  void expectFailed<T>(WorkspacesResult<T> result, WorkspacesFailure kind) =>
      expect(
        result,
        isA<WorkspacesFailed<T>>().having((f) => f.kind, 'kind', kind),
      );

  group('catalog', () {
    test('parses the projects, repos and defaults, skipping rows that do not '
        'fit', () async {
      server.on('GET', '/api/chat/workspaces', _catalogBody);

      final catalog = ok(await repository.catalog(profile: 'work'));

      expect(catalog.projects.map((p) => p.id), ['p_1a2b3c4d']);
      final project = catalog.projects.single;
      expect(project.name, 'Demo');
      expect(project.slug, 'demo');
      expect(project.folders.map((f) => f.path), [
        '/home/me/code/demo',
        '/home/me/code/demo/docs',
      ]);
      expect(project.folders.first.isPrimary, isTrue);
      expect(catalog.repos.map((r) => r.root), ['/home/u/code/bar']);
      expect(catalog.repos.single.sessions, 12);
      expect(catalog.repos.single.lastActive, 1731500000.5);
      expect(catalog.defaultCwd, '/home/u');
      expect(catalog.home, '/home/u');
      expect(catalog.scanEnabled, isTrue);
    });

    test('asks for the profile explicitly, "default" when none is given and '
        'scan only when asked', () async {
      server.on('GET', '/api/chat/workspaces', _catalogBody);

      await repository.catalog();
      await repository.catalog(profile: 'work', scan: true);

      final sent = server.requestsTo('GET', '/api/chat/workspaces').toList();
      expect(sent[0].queryParameters['profile'], 'default');
      expect(sent[0].queryParameters['scan'], isNot(true));
      expect(sent[1].queryParameters['profile'], 'work');
      expect(sent[1].queryParameters['scan'], true);
    });

    test('a 404 is an old server, unless it names a missing profile', () async {
      server.on('GET', '/api/chat/workspaces', {
        'detail': 'Not Found',
      }, status: 404);
      expect(await repository.catalog(), isA<WorkspacesUnsupported>());

      server.on('GET', '/api/chat/workspaces', {
        'detail': "Profile 'x' does not exist.",
      }, status: 404);
      expectFailed(
        await repository.catalog(),
        WorkspacesFailure.unknownProfile,
      );
    });

    test('an unreachable server and a bad body are failure kinds', () async {
      server.on('GET', '/api/chat/workspaces', {}, status: 503);
      expectFailed(await repository.catalog(), WorkspacesFailure.unreachable);
      server.on('GET', '/api/chat/workspaces', {}, status: 500);
      expectFailed(await repository.catalog(), WorkspacesFailure.unknown);
      server.on('GET', '/api/chat/workspaces', ['not', 'a map']);
      expectFailed(await repository.catalog(), WorkspacesFailure.unknown);
    });
  });

  group('listFolders', () {
    test('keeps directories only and sends the profile', () async {
      server.on('GET', '/api/fs/list', {
        'entries': [
          {'name': 'a_dir', 'path': '/tmp/project/a_dir', 'isDirectory': true},
          {'name': 'a.txt', 'path': '/tmp/project/a.txt', 'isDirectory': false},
          {'name': 'no_path', 'isDirectory': true},
          {'path': '/tmp/project/b_dir', 'isDirectory': true},
        ],
      });

      final listing = ok(await repository.listFolders('/tmp/project'));

      expect(listing.folders.map((f) => (f.name, f.path)), [
        ('a_dir', '/tmp/project/a_dir'),
        ('b_dir', '/tmp/project/b_dir'),
      ]);
      final request = server.requestsTo('GET', '/api/fs/list').single;
      expect(request.queryParameters['profile'], 'default');
      expect(request.queryParameters['path'], '/tmp/project');
    });

    test('a 200 with error fails by its reason', () async {
      for (final (error, kind) in [
        ('ENOENT', WorkspacesFailure.notFound),
        ('ENOTDIR', WorkspacesFailure.notADirectory),
        ('EACCES', WorkspacesFailure.notAllowed),
        ('read-error', WorkspacesFailure.unknown),
      ]) {
        server.on('GET', '/api/fs/list', {'entries': [], 'error': error});
        expectFailed(await repository.listFolders('/x'), kind);
      }
    });

    test(
      'a 403 is read by its detail, the least capable way when unknown',
      () async {
        for (final (detail, kind) in <(Object?, WorkspacesFailure)>[
          (
            'Path is outside the managed read boundary',
            WorkspacesFailure.outsideBoundary,
          ),
          (
            'PATH IS OUTSIDE THE MANAGED READ BOUNDARY: /x',
            WorkspacesFailure.outsideBoundary,
          ),
          ('File is not readable', WorkspacesFailure.notAllowed),
          ('Something else', WorkspacesFailure.outsideBoundary),
          ({'msg': 'not a string'}, WorkspacesFailure.outsideBoundary),
          (null, WorkspacesFailure.outsideBoundary),
        ]) {
          server.on('GET', '/api/fs/list', {'detail': detail}, status: 403);
          expectFailed(await repository.listFolders('/x'), kind);
        }
      },
    );

    test('a 404 is an old server until the route has answered, then a missing '
        'folder', () async {
      server.on('GET', '/api/fs/list', {
        'detail': 'File not found',
      }, status: 404);

      expect(await repository.listFolders('/x'), isA<WorkspacesUnsupported>());
      expectFailed(
        await repository.listFolders('/x', routeKnown: true),
        WorkspacesFailure.notFound,
      );
    });

    test('a 400 (ENOTDIR from an SSH profile) is not a directory and a 503 '
        'is unreachable', () async {
      server.on('GET', '/api/fs/list', {'detail': 'x'}, status: 400);
      expectFailed(
        await repository.listFolders('/x'),
        WorkspacesFailure.notADirectory,
      );
      server.on('GET', '/api/fs/list', {'detail': 'x'}, status: 503);
      expectFailed(
        await repository.listFolders('/x'),
        WorkspacesFailure.unreachable,
      );

      server.on('GET', '/api/fs/list', {
        'detail': "Profile 'x' does not exist.",
      }, status: 404);
      expectFailed(
        await repository.listFolders('/x', routeKnown: true),
        WorkspacesFailure.unknownProfile,
      );
    });
  });

  group('complete', () {
    Map<String, Object?> items(List<Map<String, Object?>> rows) => {
      'items': rows,
    };

    test('keeps folders and builds each text from the typed directory and the '
        'display, never from text', () async {
      answer = (_, _) async => items([
        {'text': '../me/code/', 'display': 'code/', 'meta': 'dir'},
        {'text': '../me/colors.txt', 'display': 'colors.txt', 'meta': ''},
        {'text': '../me/cool', 'display': 'cool', 'meta': 'dir'},
      ]);

      final got = ok(await repository.complete('/home/me/co', profile: 'work'));

      expect(got.folders.map((s) => s.text), [
        '/home/me/code/',
        '/home/me/cool/',
      ]);
      expect(got.folders.map((s) => s.display), ['code/', 'cool/']);
      expect(got.capped, isFalse);
      expect(calls.single.$1, 'complete.path');
      expect(calls.single.$2, {'word': '/home/me/co', 'profile': 'work'});
    });

    test('a lone / or ~/ lists the roots, and ~ alone means ~/', () async {
      answer = (_, _) async => items([
        {'text': 'x', 'display': 'etc/', 'meta': 'dir'},
      ]);

      expect(ok(await repository.complete('/')).folders.single.text, '/etc/');
      expect(ok(await repository.complete('~/')).folders.single.text, '~/etc/');
      expect(ok(await repository.complete('~')).folders.single.text, '~/etc/');
    });

    test('says when 30 items came back, folders or not', () async {
      answer = (_, _) async => items([
        for (var i = 0; i < 30; i++)
          {'text': 'f$i', 'display': 'f$i', 'meta': ''},
      ]);

      final got = ok(await repository.complete('/srv/'));

      expect(got.folders, isEmpty);
      expect(got.capped, isTrue);
    });

    test('a relative word is never sent', () async {
      expect(ok(await repository.complete('code/')).folders, isEmpty);
      expect(calls, isEmpty);
    });

    test('a Windows drive and a UNC word are sent', () async {
      answer = (_, _) async => {
        'items': [
          {'text': 'x', 'display': 'src/', 'meta': 'dir'},
        ],
      };
      expect(
        ok(await repository.complete(r'C:\code\s')).folders.single.text,
        r'C:\code\src/',
      );
      expect(
        ok(await repository.complete(r'\\nas\share\s')).folders.single.text,
        r'\\nas\share\src/',
      );
      expect(calls, hasLength(2));
    });

    test('~foo never becomes a relative suggestion', () async {
      answer = (_, _) async => {
        'items': [
          {'text': 'x', 'display': 'foo/', 'meta': 'dir'},
          {'text': 'x', 'display': '~foobar/', 'meta': 'dir'},
        ],
      };
      final got = ok(await repository.complete('~foo'));
      expect(got.folders.map((s) => s.text), ['~foobar/']);
      expect(calls, hasLength(1));
    });

    test('maps the gateway errors', () async {
      Future<WorkspacesResult<PathSuggestions>> failWith(Object error) {
        answer = (_, _) => Future.error(error);
        return repository.complete('/x');
      }

      expect(
        await failWith(const GatewayRpcException(kGatewayMethodNotFound, 'u')),
        isA<WorkspacesUnsupported>(),
      );
      expectFailed(
        await failWith(
          const GatewayRpcException(kGatewayProfileUnavailable, 'no'),
        ),
        WorkspacesFailure.unknownProfile,
      );
      expectFailed(
        await failWith(const GatewayRpcException(5021, 'boom')),
        WorkspacesFailure.unknown,
      );
      expectFailed(
        await failWith(const GatewayRequestTimeout()),
        WorkspacesFailure.unreachable,
      );
    });
  });

  group('moveWorkspace', () {
    test('sends once with the stored id, folder and profile', () async {
      answer = (_, _) async => {
        'cwd': '/home/me/code/other/lib',
        'branch': 'main',
        'git_repo_root': '/home/me/code/other',
      };

      final moved = ok(
        await repository.moveWorkspace(
          'stored-1',
          '/home/me/code/other/lib',
          profile: 'work',
        ),
      );

      expect(calls.single.$1, 'session.workspace.move');
      expect(calls.single.$2, {
        'session_key': 'stored-1',
        'cwd': '/home/me/code/other/lib',
        'profile': 'work',
      });
      expect(moved.cwd, '/home/me/code/other/lib');
      expect(moved.branch, 'main');
      expect(moved.gitRepoRoot, '/home/me/code/other');
      expect(moved.folderPath, '/home/me/code/other');
    });

    test('the folder falls back to cwd when there is no git root', () async {
      answer = (_, _) async => {
        'cwd': '/srv/plain',
        'branch': null,
        'git_repo_root': '',
      };

      final moved = ok(await repository.moveWorkspace('s', '/srv/plain'));

      expect(moved.branch, isNull);
      expect(moved.gitRepoRoot, isNull);
      expect(moved.folderPath, '/srv/plain');
      expect(calls.single.$2['profile'], 'default');
    });

    test('a relative path is refused without asking, and is not a missing '
        'folder', () async {
      for (final path in ['relative/dir', './x', '', ' /srv', '/srv/../x']) {
        expectFailed(
          await repository.moveWorkspace('s', path),
          WorkspacesFailure.notAServerPath,
        );
      }
      expect(calls, isEmpty);
    });

    test('a Windows drive, a UNC and a ~ folder are sent', () async {
      for (final path in [r'C:\Users\me\code', r'\\nas\share\code', '~/code']) {
        answer = (_, params) async => {'cwd': params['cwd']};
        final moved = ok(await repository.moveWorkspace('s', path));
        expect(moved.cwd, path);
      }
      expect(calls, hasLength(3));
    });

    test('every 5xxx may have happened, 4016 is a plain unknown', () async {
      for (final (code, kind) in <(int, WorkspacesFailure)>[
        (5000, WorkspacesFailure.busy),
        (5007, WorkspacesFailure.busy),
        (5021, WorkspacesFailure.busy),
        (5999, WorkspacesFailure.busy),
        (4016, WorkspacesFailure.unknown),
        (4009, WorkspacesFailure.unknown),
      ]) {
        answer = (_, _) => Future.error(GatewayRpcException(code, 'x'));
        expectFailed(await repository.moveWorkspace('s', '/x'), kind);
      }
    });

    test('the answer keeps paths raw and groups with or without a trailing '
        'slash', () async {
      answer = (_, _) async => {
        'cwd': ' /srv/demo/sub ',
        'git_repo_root': '/srv/demo/',
      };
      final moved = ok(await repository.moveWorkspace('s', '/srv/demo/sub'));
      expect(moved.cwd, ' /srv/demo/sub ');
      expect(moved.gitRepoRoot, '/srv/demo/');
      expect(moved.folderPath, '/srv/demo');

      answer = (_, _) async => {'cwd': '/srv/demo', 'git_repo_root': null};
      expect(
        ok(await repository.moveWorkspace('s', '/srv/demo')).folderPath,
        ok(
          await (() async {
            answer = (_, _) async => {
              'cwd': '/srv/demo/',
              'git_repo_root': null,
            };
            return repository.moveWorkspace('s', '/srv/demo/');
          })(),
        ).folderPath,
      );
    });

    test('maps each error to a kind', () async {
      for (final (code, kind) in <(int, WorkspacesFailure)>[
        (4007, WorkspacesFailure.sessionGone),
        (4016, WorkspacesFailure.unknown),
        (4017, WorkspacesFailure.notFound),
        (4064, WorkspacesFailure.unknownProfile),
        (5007, WorkspacesFailure.busy),
      ]) {
        answer = (_, _) => Future.error(GatewayRpcException(code, 'x'));
        expectFailed(await repository.moveWorkspace('s', '/x'), kind);
      }
      answer = (_, _) =>
          Future.error(const GatewayRpcException(kGatewayMethodNotFound, 'u'));
      expect(
        await repository.moveWorkspace('s', '/x'),
        isA<WorkspacesUnsupported>(),
      );
    });

    test('a lost answer is unreachable and is never sent again', () async {
      for (final lost in <Object>[
        const GatewayRequestTimeout(),
        const GatewayConnectionClosed(),
        StateError('socket'),
      ]) {
        calls.clear();
        answer = (_, _) => Future.error(lost);
        expectFailed(
          await repository.moveWorkspace('s', '/x'),
          WorkspacesFailure.unreachable,
        );
        expect(calls, hasLength(1));
      }
    });

    test('an answer without a folder may still have moved the chat', () async {
      answer = (_, _) async => {'branch': 'main'};
      expectFailed(
        await repository.moveWorkspace('s', '/x'),
        WorkspacesFailure.unreachable,
      );
    });
  });

  group('sessionFolder', () {
    test('reads cwd, branch and git root with the profile', () async {
      server.on('GET', '/api/sessions/abc', {
        'id': 'abc',
        'cwd': '/srv/demo/lib',
        'git_branch': 'dev',
        'git_repo_root': '/srv/demo',
      });

      final folder = ok(await repository.sessionFolder('abc', profile: 'work'));

      expect(folder.cwd, '/srv/demo/lib');
      expect(folder.branch, 'dev');
      expect(folder.gitRepoRoot, '/srv/demo');
      expect(
        server.requestsTo('GET', '/api/sessions/abc').single.queryParameters,
        containsPair('profile', 'work'),
      );
    });

    test('keeps the paths exactly as the server wrote them', () async {
      server.on('GET', '/api/sessions/raw', {
        'cwd': '/srv/demo/ ',
        'git_repo_root': '/srv/demo/',
      });
      final folder = ok(await repository.sessionFolder('raw'));
      expect(folder.cwd, '/srv/demo/ ');
      expect(folder.gitRepoRoot, '/srv/demo/');
    });

    test('a 404 naming a missing profile is not a missing chat', () async {
      server.on('GET', '/api/sessions/abc', {
        'detail': "Profile 'x' does not exist.",
      }, status: 404);
      expectFailed(
        await repository.sessionFolder('abc', profile: 'x'),
        WorkspacesFailure.unknownProfile,
      );
    });

    test('a missing chat and a row without folders', () async {
      server.on('GET', '/api/sessions/gone', {'detail': 'x'}, status: 404);
      expectFailed(
        await repository.sessionFolder('gone'),
        WorkspacesFailure.sessionGone,
      );

      server.on('GET', '/api/sessions/old', {'id': 'old'});
      final folder = ok(await repository.sessionFolder('old'));
      expect(folder.cwd, isNull);
      expect(
        server.requestsTo('GET', '/api/sessions/old').single.queryParameters,
        containsPair('profile', 'default'),
      );
    });
  });

  group('scanRoots', () {
    test(
      'reads desktop.repo_scan_roots, empty or set, and sends the profile',
      () async {
        server.on('GET', '/api/config', {
          'desktop': {'repo_scan_roots': <String>[]},
        });
        expect(ok(await repository.scanRoots()), isEmpty);

        server.on('GET', '/api/config', {
          'desktop': {
            'repo_scan_roots': ['/home/me/code', 7, ' '],
          },
        });
        expect(ok(await repository.scanRoots(profile: 'work')), [
          '/home/me/code',
        ]);
        expect(
          server.requestsTo('GET', '/api/config').last.queryParameters,
          containsPair('profile', 'work'),
        );
      },
    );

    test('also reads a roots list inside it, and none as empty', () async {
      server.on('GET', '/api/config', {
        'desktop': {
          'repo_scan_roots': {
            'roots': ['/a'],
          },
        },
      });
      expect(ok(await repository.scanRoots()), ['/a']);

      server.on('GET', '/api/config', {'model': 'x'});
      expect(ok(await repository.scanRoots()), isEmpty);
    });
  });

  group('a failure carries no path, URL or server text', () {
    HermesWorkspacesRepository throwing(
      DioException Function(RequestOptions) make,
    ) {
      final dio = server.dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) =>
                handler.reject(make(options), true),
          ),
        );
      return build(HermesApiClient(dio));
    }

    String show(Object? result) => '$result ${result.runtimeType}';

    test('a failed request on every REST read is only a kind', () async {
      final failing = throwing(
        (options) => DioException.connectionError(
          requestOptions: options,
          reason: 'cannot reach ${options.uri} for $_secret',
        ),
      );

      final results = <Object>[
        await failing.catalog(),
        await failing.listFolders(_secret),
        await failing.sessionFolder('$_secret-id'),
        await failing.scanRoots(),
      ];

      for (final result in results) {
        expect(result, isA<WorkspacesFailed<Object?>>());
        expect(show(result), isNot(contains(_secret)));
        expect(show(result), isNot(contains('hermes.test')));
        expect(show(result), isNot(contains('http')));
      }
    });

    test('a failing fs/list through the real telemetry interceptor leaves '
        'the path in no span or log record', () async {
      final tracer = RecordingTracer();
      final logger = _RecordingLogger();
      final dio = server.dio()
        ..interceptors.add(httpInterceptor(logger, tracer));
      final traced = build(HermesApiClient(dio));
      for (final status in [403, 404, 500]) {
        server.on('GET', '/api/fs/list', {
          'detail': 'Path is outside the managed read boundary: $_secret',
        }, status: status);
        await traced.listFolders(_secret, routeKnown: true);
      }

      expect(tracer.spans, isNotEmpty);
      expect(logger.records, isNotEmpty);
      final exported = [
        for (final s in tracer.spans) ...[
          ...s.attributes.keys,
          ...s.attributes.values,
          ...s.events,
          s.statusDescription,
        ],
        for (final r in logger.records) ...[
          r.body,
          ...r.attributes.keys,
          ...r.attributes.values,
        ],
      ].join(' ');
      expect(exported, isNot(contains(_secret)));
      expect(exported, isNot(contains('secret-client')));
      expect(exported, isNot(contains('/api/fs/list?')));
    });

    test(
      'an error body that echoes the path stays out of the failure',
      () async {
        server.on('GET', '/api/fs/list', {
          'detail': 'Path is outside the managed read boundary: $_secret',
        }, status: 403);

        final result = await repository.listFolders(_secret);

        expect(show(result), isNot(contains(_secret)));
        expectFailed(result, WorkspacesFailure.outsideBoundary);
      },
    );

    test('a 4017 that echoes the raw path stays out of the failure', () async {
      answer = (_, _) => Future.error(
        const GatewayRpcException(
          4017,
          'working directory does not exist: $_secret',
        ),
      );

      final result = await repository.moveWorkspace('s', _secret);

      expect(show(result), isNot(contains(_secret)));
      expectFailed(result, WorkspacesFailure.notFound);
    });

    test('a thrown error of any kind is dropped, not rethrown', () async {
      answer = (_, _) => throw StateError('boom $_secret');

      final result = await repository.complete('/x');

      expect(show(result), isNot(contains(_secret)));
    });
  });

  test('nothing about folders is written to the device', () {
    // The repository holds no storage or telemetry: it cannot persist or log
    // a path because it imports nothing that could.
    const banned = [
      'shared_preferences',
      'flutter_secure_storage',
      'dart:io',
      'telemetry',
      'flutter_otel',
      'path_provider',
      'sqflite',
      'drift',
    ];
    final files = Directory('lib/src/workspaces')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    expect(files, isNotEmpty);
    for (final file in files) {
      final imports = file
          .readAsLinesSync()
          .where((line) => line.startsWith('import '))
          .join('\n');
      for (final name in banned) {
        expect(imports, isNot(contains(name)), reason: '${file.path} $name');
      }
    }
  });
}
