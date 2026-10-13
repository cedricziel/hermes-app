import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/gateway/todo_state.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('pinned todo updates are mapped separately from turn settlement', () {
    final connection = Object();
    final event = mapGatewayEvent(
      GatewayEvent(
        type: 'todo.updated',
        sessionId: 'runtime-a',
        payload: Map<String, Object?>.from(fixture['state'] as Map),
      ),
      connection: connection,
    );

    expect(event, isA<TodoUpdated>());
    final plan = event as TodoUpdated;
    expect(plan.runtimeId, 'runtime-a');
    expect(plan.connection, same(connection));
    expect(plan.snapshot.revision, 1);
    expect(plan.snapshot.entries[1]!.parent, 'plan');
    expect(event, isNot(isA<ReplyCompleted>()));
  });

  test(
    'malformed optional todo payloads leave subsequent chat frames usable',
    () {
      for (final payload in <Map<String, Object?>>[
        {},
        {'revision': '1', 'todos': []},
        {'revision': -1, 'todos': []},
        {'revision': 1, 'todos': 'invalid'},
      ]) {
        expect(
          mapGatewayEvent(
            GatewayEvent(
              type: 'todo.updated',
              sessionId: 'runtime-a',
              payload: payload,
            ),
          ),
          isNull,
        );
      }
      expect(
        mapGatewayEvent(
          const GatewayEvent(
            type: 'message.complete',
            sessionId: 'runtime-a',
            payload: {'text': 'Done', 'status': 'complete'},
          ),
        ),
        isA<ReplyCompleted>(),
      );
    },
  );
}
