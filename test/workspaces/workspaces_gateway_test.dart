import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/workspaces/hermes_workspaces_repository.dart';
import 'package:hermes_app/src/workspaces/workspace_models.dart';

import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';

/// The repository over the real transport's keep-the-connection request and
/// the scripted gateway, as the app wires it.
void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;
  late HermesWorkspacesRepository repository;

  setUp(() {
    gateway = FakeGateway();
    transport = HermesGatewayTransport(connect: () async => gateway.channel);
    repository = HermesWorkspacesRepository(
      FakeHermesServer().client().raw,
      transport.requestKeepingConnection,
      timeout: const Duration(milliseconds: 200),
    );
  });

  tearDown(() => transport.close());

  Iterable<Map<String, Object?>> sent(String method) =>
      gateway.requests.where((r) => r['method'] == method);

  test('complete.path answers folders and carries the profile', () async {
    gateway.handlers['complete.path'] = (_) => {
      'items': [
        {'text': 'x', 'display': 'src/', 'meta': 'dir'},
        {'text': 'y', 'display': 'a.txt', 'meta': ''},
      ],
    };

    final result = await repository.complete('/srv/', profile: 'work');

    final got = (result as WorkspacesOk<PathSuggestions>).value;
    expect(got.folders.single.text, '/srv/src/');
    final params = sent('complete.path').single['params']! as Map;
    expect(params, {'word': '/srv/', 'profile': 'work'});
  });

  test('a move answers, and each error code reaches its kind', () async {
    gateway.handlers['session.workspace.move'] = (_) => {
      'cwd': '/srv/demo',
      'branch': 'main',
      'git_repo_root': '/srv/demo',
    };
    final moved = await repository.moveWorkspace('s1', '/srv/demo');
    expect((moved as WorkspacesOk<MovedWorkspace>).value.branch, 'main');

    for (final (code, kind) in <(int, WorkspacesFailure)>[
      (4007, WorkspacesFailure.sessionGone),
      (4017, WorkspacesFailure.notFound),
      (4064, WorkspacesFailure.unknownProfile),
      (5007, WorkspacesFailure.busy),
    ]) {
      gateway.handlers['session.workspace.move'] = (_) =>
          throw FakeRpcError(code, 'working directory does not exist: /raw');
      final result = await repository.moveWorkspace('s1', '/srv/demo');
      expect(
        result,
        isA<WorkspacesFailed<MovedWorkspace>>().having(
          (f) => f.kind,
          'kind',
          kind,
        ),
      );
    }
  });

  test('an older gateway answering -32601 is unsupported', () async {
    gateway.handlers['session.workspace.move'] = (_) =>
        throw const FakeRpcError(-32601, 'unknown method');

    expect(
      await repository.moveWorkspace('s1', '/srv/demo'),
      isA<WorkspacesUnsupported<MovedWorkspace>>(),
    );
  });

  test('a move that gets no answer is unreachable, sent once, and leaves the '
      'connection open', () async {
    gateway.silent.add('session.workspace.move');

    final result = await repository.moveWorkspace('s1', '/srv/demo');

    expect(
      result,
      isA<WorkspacesFailed<MovedWorkspace>>().having(
        (f) => f.kind,
        'kind',
        WorkspacesFailure.unreachable,
      ),
    );
    expect(sent('session.workspace.move'), hasLength(1));
    gateway.handlers['complete.path'] = (_) => {'items': []};
    expect(
      await repository.complete('/'),
      isA<WorkspacesOk<PathSuggestions>>(),
    );
  });
}
