import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/kanban/kanban_board_controller.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';

import 'support/fake_hermes_server.dart';
import 'support/kanban_fixtures.dart';

void main() {
  test('waits twice as long after each failed reconnect, up to 30 s', () {
    fakeAsync((async) {
      final server = FakeHermesServer()
        ..on('GET', '/api/plugins/kanban/boards', kanbanBoardsBody([]))
        ..on(
          'GET',
          '/api/plugins/kanban/board',
          kanbanBoardBody([kanbanTaskRow(id: 't1')]),
        );
      final attempts = <Duration>[];
      final controller = KanbanBoardController(
        repository: KanbanRepository(server.client()),
        connect: ({required since, board}) async {
          attempts.add(async.elapsed);
          throw const SocketException('refused');
        },
      );

      controller.start();
      async.elapse(const Duration(minutes: 3));
      controller.dispose();

      // Waits of 1, 2, 4, 8 and 16 s, then 30 s each.
      expect(attempts.map((t) => t.inSeconds).take(9), [
        0, 1, 3, 7, 15, 31, 61, 91, 121, //
      ]);
    });
  });
}
