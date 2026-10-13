import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

void main() {
  test(
    'pinned side completions map independently from foreground completion',
    () {
      final connection = Object();
      for (final kind in ['background.complete', 'btw.complete']) {
        final mapped = mapGatewayEvent(
          GatewayEvent(
            type: kind,
            sessionId: 'runtime',
            payload: {
              'task_id': 'same-task',
              'text': 'Reported answer',
              'question': kind == 'btw.complete' ? 'Reported question' : null,
            },
          ),
          connection: connection,
        );
        expect(mapped, isNotNull, reason: kind);
        final result = mapped! as SideResultReceived;
        expect(result.runtimeId, 'runtime');
        expect(result.connection, same(connection));
        expect(result.result.taskId, 'same-task');
        expect(result.result.text, 'Reported answer');
      }
    },
  );

  test('malformed or ownerless side completions remain optional', () {
    for (final payload in [
      <String, Object?>{},
      {'task_id': '', 'text': 'Empty identity'},
      {'task_id': 'task', 'text': 42},
    ]) {
      expect(
        mapGatewayEvent(
          GatewayEvent(
            type: 'btw.complete',
            sessionId: 'runtime',
            payload: payload,
          ),
        ),
        isNull,
      );
    }
    expect(
      mapGatewayEvent(
        GatewayEvent(
          type: 'background.complete',
          sessionId: '',
          payload: {'task_id': 'task', 'text': 'No owner'},
        ),
      ),
      isNull,
    );
    expect(
      mapGatewayEvent(
        GatewayEvent(
          type: 'preview.restart.complete',
          sessionId: 'runtime',
          payload: {'task_id': 'task', 'text': 'Other feature'},
        ),
      ),
      isNull,
    );
  });
}
