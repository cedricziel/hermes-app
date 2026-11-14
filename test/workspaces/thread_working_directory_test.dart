import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/hermes_chat_repository.dart';
import 'package:hermes_app/src/chat/thread_sections.dart';

import '../support/fake_hermes_server.dart';

Map<String, Object?> _row(String id, Map<String, Object?> extra) => {
  'id': id,
  'title': id,
  'last_active': 1780000000,
  ...extra,
};

void main() {
  late FakeHermesServer server;
  late HermesChatRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesChatRepository(server.client().raw);
  });

  test('a thread keeps the raw cwd and the branch beside the folder', () async {
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([
        _row('a', {
          'cwd': '/home/me/code/demo/packages/app',
          'git_branch': 'main',
          'git_repo_root': '/home/me/code/demo',
        }),
      ]),
    );

    final thread = (await repository.loadThreads()).single;

    expect(thread.workingDirectory, '/home/me/code/demo/packages/app');
    expect(thread.branch, 'main');
    expect(thread.folderPath, '/home/me/code/demo');
  });

  test('rows without them leave both null', () async {
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([
        _row('a', {'cwd': '  ', 'git_branch': null}),
        _row('b', {}),
      ]),
    );

    final threads = await repository.loadThreads();

    expect(threads.map((t) => t.workingDirectory), [null, null]);
    expect(threads.map((t) => t.branch), [null, null]);
  });

  test('grouping still follows the folder path', () async {
    server.on(
      'GET',
      '/api/sessions',
      sessionListBody([
        _row('a', {'cwd': '/srv/demo/lib', 'git_repo_root': '/srv/demo'}),
        _row('b', {'cwd': '/srv/demo'}),
        _row('c', {'cwd': '/srv/other'}),
      ]),
    );

    final sections = groupThreadsByFolder(await repository.loadThreads());

    expect(sections.map((s) => s.threads.map((t) => t.id).toList()), [
      ['a', 'b'],
      ['c'],
    ]);
  });
}
