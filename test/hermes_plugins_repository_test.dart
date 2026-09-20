import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/kanban/hermes_plugins_repository.dart';

import 'support/fake_hermes_server.dart';

void main() {
  late FakeHermesServer server;
  late HermesPluginsRepository repository;

  setUp(() {
    server = FakeHermesServer();
    repository = HermesPluginsRepository(server.client().raw);
  });

  Map<String, Object?> plugin(String name) => {
    'name': name,
    'label': name,
    'tab': {'path': '/$name'},
  };

  test('reports Kanban on when the server lists the plugin', () async {
    server.on('GET', '/api/dashboard/plugins', [
      plugin('achievements'),
      plugin('kanban'),
    ]);

    expect(await repository.isKanbanEnabled(), isTrue);
  });

  test('reports Kanban off when the plugin is not listed', () async {
    server.on('GET', '/api/dashboard/plugins', [plugin('achievements')]);

    expect(await repository.isKanbanEnabled(), isFalse);
  });

  test('reads an unexpected body as off', () async {
    server.on('GET', '/api/dashboard/plugins', {'plugins': []});

    expect(await repository.isKanbanEnabled(), isFalse);
  });

  test('reads a failing or missing route as off', () async {
    expect(await repository.isKanbanEnabled(), isFalse);

    server.on('GET', '/api/dashboard/plugins', {'detail': 'boom'}, status: 500);

    expect(await repository.isKanbanEnabled(), isFalse);
  });
}
