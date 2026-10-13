import 'dart:async';
import 'dart:convert';

import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:stream_channel/stream_channel.dart';

// Wire subsets verified from the pinned connector operation contract.
const connectorFixtureRevision = '167e9fdb84248cd0fff80762dc57b6a914b6e930';
final connectionRequestFixture = <String, Object?>{
  'op_id': 'synthetic-operation',
  'seq': 1,
  'deadline_at': 1893456060.0,
  'timeout_seconds': 60.0,
  'tool_call_id': 'synthetic-tool',
  'targets': [
    {
      'name': 'synthetic-connector',
      'kind': 'connector',
      'action': 'authorize',
      'state': 'initiated',
      'resolved': false,
      'connect_url': 'https://connect.invalid/verify?private=secret',
      'instructions': 'Approve in the browser',
    },
  ],
};
final connectionUpdateFixture = <String, Object?>{
  'op_id': connectionRequestFixture['op_id'],
  'deadline_at': connectionRequestFixture['deadline_at'],
  'targets': connectionRequestFixture['targets'],
  'seq': 4,
  'settled': false,
  'owner': {'type': 'session', 'session_id': 'runtime-a'},
};

class ActivityRpcServer {
  ActivityRpcServer() {
    client = GatewayRpcClient(_wire.local);
    _subscription = _wire.foreign.stream.listen(
      (frame) => requests.add(jsonDecode(frame) as Map<String, Object?>),
    );
  }
  final _wire = StreamChannelController<String>();
  late final GatewayRpcClient client;
  late final StreamSubscription<String> _subscription;
  final requests = <Map<String, Object?>>[];
  void answer(int index, Map<String, Object?> result) => _wire.foreign.sink.add(
    jsonEncode({'id': requests[index]['id'], 'result': result}),
  );
  void refuse(int index, int code) => _wire.foreign.sink.add(
    jsonEncode({
      'id': requests[index]['id'],
      'error': {'code': code, 'message': 'Synthetic refusal'},
    }),
  );
  Future<void> close() async {
    await client.close();
    await _subscription.cancel();
    await _wire.foreign.sink.close();
  }
}
