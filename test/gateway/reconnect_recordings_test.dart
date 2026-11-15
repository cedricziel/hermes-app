import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_replay.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

/// What the pinned Hermes answered when a socket dropped mid-turn and when
/// the backend restarted (`test/fixtures/gateway/reconnect_recordings.json`),
/// fed through the replay ledger the transport reconnects with.
Map<String, Object?> _recordings() => jsonDecode(
  File('test/fixtures/gateway/reconnect_recordings.json').readAsStringSync(),
) as Map<String, Object?>;

Map<String, Object?> _answer(String key) =>
    ((_recordings()[key]! as Map<String, Object?>)['answer']!)
        as Map<String, Object?>;

void main() {
  test('a turn that finished while the socket was away is delivered in '
      'order from the watermark', () {
    final ledger = ReplayLedger()..observe('rt000001', 9, epoch: 'epoch-a');
    final decision = ledger.merge(
      sid: 'rt000001',
      result: _answer('events_since_turn_finished_while_away'),
      parked: const <GatewayEvent>[],
    );
    final delivered = (decision as Deliver).events;
    expect(delivered.map((e) => e.type), [
      'tool.complete',
      'message.delta',
      'message.complete',
      'session.info',
    ]);
    expect(delivered.map((e) => e.seq), [10, 11, 12, 13]);
    expect(ledger.lastSeen('rt000001'), 13);
  });

  test('a live frame that overlaps the replay is not delivered twice', () {
    final ledger = ReplayLedger()..observe('rt000001', 9, epoch: 'epoch-a');
    final decision = ledger.merge(
      sid: 'rt000001',
      result: _answer('events_since_turn_finished_while_away'),
      parked: const [
        GatewayEvent(
          type: 'message.complete',
          sessionId: 'rt000001',
          payload: {},
          seq: 12,
        ),
      ],
    );
    expect((decision as Deliver).events.map((e) => e.seq), [10, 11, 12, 13]);
  });

  test('the empty replay a restarted backend answers, with a new epoch, '
      'makes the transport refetch and forgets the old watermark', () {
    final ledger = ReplayLedger()..observe('rt000001', 9, epoch: 'epoch-a');
    final decision = ledger.merge(
      sid: 'rt000001',
      result: _answer('events_since_after_restart'),
      parked: const <GatewayEvent>[],
    );
    expect(decision, isA<Refetch>());
    expect(ledger.hasWatermark('rt000001'), isFalse);
  });
}
