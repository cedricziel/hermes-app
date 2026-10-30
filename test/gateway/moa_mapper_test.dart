import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_event_mapper.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';

import 'gateway_contract_test.dart' as contract;

const moaPayloads = <String, Map<String, Object?>>{
  'moa.reference': {
    'label': 'Synthetic advisor',
    'text': 'Synthetic reference',
    'index': 1,
    'count': 2,
  },
  'moa.progress': {
    'label': 'Synthetic advisor',
    'refs_done': 1,
    'refs_total': 2,
  },
  'moa.phase': {
    'phase': 'aggregator',
    'refs_done': 2,
    'refs_total': 2,
    'aggregator': 'Synthetic aggregator',
  },
  'moa.aggregating': {'aggregator': 'Synthetic aggregator'},
};
void main() {
  final client = Object();
  for (final entry in moaPayloads.entries) {
    test(
      '${entry.key} preserves validated frame ownership and replay identity',
      () {
        GatewayEvent frame() => GatewayEvent(
          type: entry.key,
          sessionId: 'runtime',
          payload: entry.value,
          seq: 7,
        );
        final first = mapGatewayEvent(frame(), connection: client);
        expect(first, isA<MoaUpdated>());
        final mapped = first as MoaUpdated;
        expect(mapped.runtimeId, 'runtime');
        expect(mapped.connection, same(client));
        expect(
          mapped.identity,
          (mapGatewayEvent(frame(), connection: client) as MoaUpdated).identity,
        );
        expect(contract.notifications[entry.key]!.$1, contract.Use.shown);
      },
    );
  }
  test('unsequenced equal-label reference frames remain distinct', () {
    GatewayEvent frame() => GatewayEvent(
      type: 'moa.reference',
      sessionId: 'runtime',
      payload: {'label': 'Same', 'text': 'Reference'},
    );
    final first = mapGatewayEvent(frame(), connection: client);
    final second = mapGatewayEvent(frame(), connection: client);
    expect(first, isA<MoaUpdated>());
    expect(
      (first as MoaUpdated).identity,
      isNot((second as MoaUpdated).identity),
    );
  });
  test(
    'malformed references and missing runtime do not break ordinary messages',
    () {
      expect(
        mapGatewayEvent(
          const GatewayEvent(
            type: 'moa.reference',
            sessionId: 'runtime',
            payload: {'label': 'Advisor', 'text': []},
          ),
          connection: client,
        ),
        isNull,
      );
      expect(
        mapGatewayEvent(
          const GatewayEvent(
            type: 'moa.progress',
            sessionId: '',
            payload: {'label': 'Advisor', 'refs_done': 1, 'refs_total': 2},
          ),
          connection: client,
        ),
        isNull,
      );
      expect(
        mapGatewayEvent(
          const GatewayEvent(
            type: 'message.delta',
            sessionId: 'runtime',
            payload: {'text': 'Main answer'},
          ),
          connection: client,
        ),
        isA<ReplyDelta>(),
      );
    },
  );
  test('current pinned contract covers exactly these four payloads', () {
    final json = jsonDecode(
      File('openrpc/hermes-gateway.openrpc.json').readAsStringSync(),
    ) as Map;
    final schemas = (json['components'] as Map)['schemas'] as Map;
    expect(
      File('openrpc/HERMES_REF').readAsStringSync().trim(),
      'd923a5eb487a17c0a68801bba9ef0f56c81040a8',
    );
    expect((schemas['MoaReferencePayload'] as Map)['required'], [
      'label',
      'text',
    ]);
    expect((schemas['MoaProgressPayload'] as Map)['required'], [
      'label',
      'refs_done',
      'refs_total',
    ]);
    expect((schemas['MoaPhasePayload'] as Map)['required'], ['phase']);
    expect((schemas['MoaAggregatingPayload'] as Map)['required'], [
      'aggregator',
    ]);
  });
}
