import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/bot_screen_repository.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/memory/memory_repository.dart';
import 'package:hermes_app/src/tools/hermes_tools_repository.dart';

import '../support/fake_hermes_server.dart';

/// The chat's profile reaches the network on every tools, memory and display
/// call, and no Kanban call carries one. The profile arguments are required
/// and non-null, so dropping one does not compile; these tests pin what then
/// goes out.
void main() {
  test('a tools request carries the profile it was bound to', () async {
    final server = FakeHermesServer()..on('GET', '/api/tools/toolsets', {});
    await HermesToolsRoot(server.client().raw).forProfile('work').list();

    expect(server.requests.single.queryParameters['profile'], 'work');
  });

  test('a memory request carries the profile it was given', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/learning/graph', {'nodes': <Object?>[]});
    await MemoryRepository(server.client().raw).count('work');

    expect(server.requests.single.queryParameters['profile'], 'work');
  });

  test('a display call carries the profile it was given', () async {
    final sent = <Map<String, Object?>>[];
    final repository = BotScreenRepository((
      method,
      params, {
      required timeout,
    }) async {
      sent.add(params);
      return {};
    });
    await repository.status('work');

    expect(sent.single['profile'], 'work');
  });

  test('a Kanban request carries no profile', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/plugins/kanban/boards', {'boards': <Object?>[]});
    await KanbanRepository(server.client()).listBoards();

    expect(server.requests.single.queryParameters, isNot(contains('profile')));
  });

  test('Kanban code names no profile in a request', () {
    // A heuristic, not a proof. It looks for `profile:` as an argument,
    // `'profile'` as a key and `profile=` inside a string. It skips the
    // models (they parse an assignee row), `*_screen.dart` and `widgets/`
    // (they filter by assignee), so a request built there is not seen. A
    // query written into a URL string under another spelling is missed too,
    // and only `listBoards` is checked on the wire above.
    final pattern = RegExp(r'''\bprofile\s*:|['"]profile['"]|profile=''');
    final offenders = <String>[];
    for (final file in Directory('lib/src/kanban').listSync(recursive: true)) {
      if (file is! File ||
          !file.path.endsWith('.dart') ||
          file.path.endsWith('kanban_models.dart') ||
          file.path.endsWith('_screen.dart') ||
          file.path.contains('/widgets/')) {
        continue;
      }
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (pattern.hasMatch(lines[i])) offenders.add('${file.path}:${i + 1}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Kanban is shared by every profile; send no profile',
    );
  });
}
