import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/workspace_models.dart';

import '../support/fake_hermes_server.dart';

/// The answers a real Hermes gave (see the fixture's note), served by the
/// fake and read by the repository.
final _cases =
    ((jsonDecode(
              File('test/fixtures/workspaces/workspaces_routes.json')
                  .readAsStringSync(),
            ) as Map<String, Object?>)['cases']!
            as Map)
        .cast<String, Map<String, Object?>>();

void main() {
  late FakeHermesServer server;
  late HermesWorkspacesRepository repository;
  var rpcCase = '';

  setUp(() {
    server = FakeHermesServer();
    repository = HermesWorkspacesRepository(server.client().raw, (
      method,
      params, {
      required timeout,
    }) async {
      final response = ((_cases[rpcCase]!['response']) as Map)
          .cast<String, Object?>();
      if (response['error'] case final Map error) {
        throw GatewayRpcException(
          error['code']! as int,
          error['message']! as String,
        );
      }
      return (response['result']! as Map).cast<String, Object?>();
    });
  });

  T ok<T>(WorkspacesResult<T> result) => switch (result) {
    WorkspacesOk(:final value) => value,
    _ => fail('expected a value, got $result'),
  };

  void failed<T>(WorkspacesResult<T> result, WorkspacesFailure kind) => expect(
    result,
    isA<WorkspacesFailed<T>>().having((f) => f.kind, 'kind', kind),
  );

  test(
    'the catalog parses a project of two folders and a scanned repo',
    () async {
      final c = _cases['catalog_with_project_and_scanned_repo']!;
      server.on('GET', '/api/chat/workspaces', c['body']);
      final catalog = ok(await repository.catalog(scan: true));
      final project = catalog.projects.single;
      expect(project.name, 'Demo project');
      expect(project.slug, 'demo-project');
      expect(project.folders.map((f) => f.path), [
        '/srv/demo/proj',
        '/srv/demo/plain',
      ]);
      expect(project.folders.first.isPrimary, isTrue);
      expect(catalog.repos.single.root, '/srv/demo/proj');
      expect(catalog.repos.single.label, 'proj');
      expect(catalog.defaultCwd, '/srv/demo/launch');
      expect(catalog.home, '/home/demo');
      expect(catalog.scanEnabled, isTrue);
    },
  );

  test('an unknown profile on the catalog is unknownProfile', () async {
    final c = _cases['catalog_unknown_profile']!;
    server.on(
      'GET',
      '/api/chat/workspaces',
      c['body'],
      status: c['status']! as int,
    );
    failed(
      await repository.catalog(profile: 'ghost-profile'),
      WorkspacesFailure.unknownProfile,
    );
  });

  test('fs/list keeps directories only: dot folders yes, a symlinked folder '
      'no', () async {
    server.on(
      'GET',
      '/api/fs/list',
      _cases['fs_list_with_dot_entries']!['body'],
    );
    final names = ok(await repository.listFolders('/srv/demo/proj')).folders
        .map((f) => f.name);
    expect(names, ['.hiddendir', 'empty', 'real', 'src']);
    expect(names, isNot(contains('link')));
  });

  test('complete.path builds the next text from the typed folder, never from '
      'the relative text', () async {
    rpcCase = 'complete_abs';
    final got = ok(await repository.complete('/srv/demo/proj/s'));
    expect(got.folders.map((s) => s.text), ['/srv/demo/proj/src/']);
    rpcCase = 'complete_abs_dir';
    final all = ok(await repository.complete('/srv/demo/proj/'));
    expect(all.folders.map((s) => s.text), contains('/srv/demo/proj/src/'));
    expect(
      all.folders.map((s) => s.text),
      everyElement(startsWith('/srv/demo/proj/')),
    );
    rpcCase = 'complete_missing';
    expect(ok(await repository.complete('/srv/demo/nope/x')).folders, isEmpty);
  });

  test('a move answer with empty branch and repository root reads as none, '
      'and each refusal maps to its kind', () async {
    rpcCase = 'move_ok';
    final moved = ok(
      await repository.moveWorkspace(
        '20260101_090000_a1b2c3',
        '/srv/demo/plain',
      ),
    );
    expect(moved.cwd, '/srv/demo/plain');
    expect(moved.branch, isNull);
    expect(moved.gitRepoRoot, isNull);

    for (final (name, kind) in [
      ('move_missing', WorkspacesFailure.notFound),
      ('move_unknown_session', WorkspacesFailure.sessionGone),
      ('move_bad_profile', WorkspacesFailure.unknownProfile),
    ]) {
      rpcCase = name;
      failed(
        await repository.moveWorkspace('20260101_090000_a1b2c3', '/srv/demo/x'),
        kind,
      );
    }
  });

  test('the draft chat answers carry the folder fields the app reads', () {
    final bound =
        (((_cases['create_cwd']!['response'] as Map)['result'] as Map)['info']
                as Map)
            .cast<String, Object?>();
    expect(bound['cwd'], '/srv/demo/proj');
    expect(bound['branch'], isA<String>());
    expect((bound['project']! as Map)['name'], 'Demo project');
    final fell =
        ((_cases['create_bad']!['response'] as Map)['result'] as Map)['info']
            as Map;
    expect(fell['cwd'], '/srv/demo/launch');
    expect(fell['project'], isNull);
    expect(_cases['session_read_draft']!['status'], 404);
  });
}
