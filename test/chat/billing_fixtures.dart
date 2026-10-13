import 'dart:async';
import 'dart:convert';

import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:stream_channel/stream_channel.dart';

// Retained billing shapes audited at the revision below; current schema is in openrpc/HERMES_REF.
const billingFixtureRevision = '167e9fdb84248cd0fff80762dc57b6a914b6e930';
const billingVerificationFixture = <String, Object?>{
  'verification_url': 'https://billing.invalid/verify?private=secret',
  'user_code': 'PRIVATE-CODE',
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
