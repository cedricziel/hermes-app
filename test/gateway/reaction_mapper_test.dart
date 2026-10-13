import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/reactions/reaction_state.dart';

void main() {
  test('actual pinned reaction snapshot retains canonical identity and physical source', () {
    final connection = Object();
    final event = mapGatewayEvent(
      GatewayEvent(
        type: 'message.reaction',
        sessionId: 'runtime',
        payload: {
          'row_id': 21,
          'role': 'user',
          'reactions': [
            {'emoji': '👍', 'author': 'agent'},
          ],
        },
      ),
      connection: connection,
    );
    expect(event, isA<MessageReactionsUpdated>());
    final update = event! as MessageReactionsUpdated;
    expect(update.runtimeId, 'runtime');
    expect(update.connection, same(connection));
    expect(update.snapshot.rowId, 21);
    expect(update.snapshot.role, 'user');
    expect(update.snapshot.reactions.single.author, 'agent');
  });

  test('verified vibe remains identity-free session acknowledgement', () {
    final connection = Object();
    final event = mapGatewayEvent(
      GatewayEvent(
        type: 'reaction',
        sessionId: 'runtime',
        payload: {'kind': 'vibe'},
      ),
      connection: connection,
    );
    expect(event, isA<SessionAcknowledgementReported>());
    final ack = event! as SessionAcknowledgementReported;
    expect(ack.acknowledgement, SessionAcknowledgement.vibe);
    expect(ack.runtimeId, 'runtime');
    expect(ack.connection, same(connection));
    expect(
      mapGatewayEvent(
        GatewayEvent(
          type: 'reaction',
          sessionId: 'runtime',
          payload: {'kind': 'future'},
        ),
      ),
      isNull,
    );
  });

  test('malformed snapshots and unverified aliases stay optional', () {
    expect(
      mapGatewayEvent(
        GatewayEvent(
          type: 'message.reaction',
          sessionId: 'runtime',
          payload: {'id': 21, 'role': 'user', 'reactions': []},
        ),
      ),
      isNull,
    );
    expect(
      mapGatewayEvent(
        GatewayEvent(
          type: 'message.reaction',
          sessionId: '',
          payload: {'row_id': 21, 'role': 'user', 'reactions': []},
        ),
      ),
      isNull,
    );
    expect(
      mapGatewayEvent(
        GatewayEvent(
          type: 'message.reactions',
          sessionId: 'runtime',
          payload: {'row_id': 21, 'role': 'user', 'reactions': []},
        ),
      ),
      isNull,
    );
    expect(
      mapGatewayEvent(
        GatewayEvent(
          type: 'session.ack',
          sessionId: 'runtime',
          payload: {'kind': 'vibe'},
        ),
      ),
      isNull,
    );
  });
}
