import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/thread_sections.dart';
import 'package:hermes_app/src/chat/hermes_chat_repository.dart';

import 'support/fake_hermes_server.dart';

ChatThread thread(String id, {String? folder, bool pinned = false}) =>
    ChatThread(
      id: id,
      title: id,
      updatedAt: DateTime(2026, 10, 5),
      folderPath: folder,
      pinned: pinned,
    );

void main() {
  test(
    'uses repository root before cwd, tolerates absent or invalid paths',
    () async {
      final server = FakeHermesServer()
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([
            {
              ...sessionRow(id: 'repo'),
              'cwd': '/code/hermes/lib',
              'git_repo_root': '/code/hermes',
            },
            {...sessionRow(id: 'cwd'), 'cwd': '/ops/', 'git_repo_root': ' '},
            {...sessionRow(id: 'missing'), 'cwd': 42},
          ]),
        );
      final rows = await HermesChatRepository(server.client().raw)
          .loadThreads();
      expect(rows.map((t) => t.folderPath), ['/code/hermes', '/ops', null]);
    },
  );

  test('pinned chats appear once; missing folders remain accessible', () {
    final groups = groupThreadsByFolder([
      thread('pinned', folder: '/code/app', pinned: true),
      thread('first', folder: '/code/app'),
      thread('second', folder: '/code/app'),
      thread('draft'),
    ]);
    expect(groups.map((g) => g.label), ['Pinned', 'app', 'No folder']);
    expect(groups.expand((g) => g.threads).map((t) => t.id), [
      'pinned',
      'first',
      'second',
      'draft',
    ]);
    expect(groups[1].threads.length, 2);
  });

  test('same basename folders stay distinct with unambiguous labels', () {
    final groups = groupThreadsByFolder([
      thread('work', folder: '/work/app'),
      thread('personal', folder: '/personal/app'),
      thread('windows', folder: r'C:\code\app'),
    ]);
    expect(groups.map((g) => g.id).toSet(), hasLength(3));
    expect(groups.map((g) => g.label), [
      '/work/app',
      '/personal/app',
      r'C:\code\app',
    ]);
  });
}
