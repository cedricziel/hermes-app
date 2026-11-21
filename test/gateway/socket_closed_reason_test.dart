import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:stream_channel/stream_channel.dart';

class _Coded<T> with StreamChannelMixin<T> implements SocketCloseCode {
  _Coded(this._inner, this.closeCode);

  final StreamChannel<T> _inner;

  @override
  final int? closeCode;

  @override
  Stream<T> get stream => _inner.stream;

  @override
  StreamSink<T> get sink => _inner.sink;
}

void main() {
  test('a peer that ends the socket is remote_close, with its code', () {
    fakeAsync((async) {
      final wire = StreamChannelController<String>();
      final seen = <(String, int?, Duration)>[];
      GatewayRpcClient(
        _Coded(wire.local, 1006),
        onSocketClosed: (r, c, d) => seen.add((r, c, d)),
      );
      async.elapse(const Duration(seconds: 3));
      unawaited(wire.foreign.sink.close());
      async.flushMicrotasks();

      expect(seen.single.$1, 'remote_close');
      expect(seen.single.$2, 1006);
      expect(seen.single.$3, const Duration(seconds: 3));
    });
  });

  test('closing it ourselves is local_close, once', () {
    fakeAsync((async) {
      final wire = StreamChannelController<String>();
      final seen = <String>[];
      final client = GatewayRpcClient(
        wire.local,
        onSocketClosed: (r, c, d) => seen.add(r),
      );
      unawaited(client.close());
      unawaited(client.close());
      async.flushMicrotasks();

      expect(seen, ['local_close']);
    });
  });

  test('a socket that went silent is heartbeat_silence', () {
    fakeAsync((async) {
      final wire = StreamChannelController<String>();
      final seen = <String>[];
      GatewayRpcClient(
        wire.local,
        heartbeat: true,
        onSocketClosed: (r, c, d) => seen.add(r),
      ).hold();
      async.elapse(const Duration(seconds: 60));

      expect(seen, ['heartbeat_silence']);
    });
  });

  test('a stream error before the end is error', () {
    fakeAsync((async) {
      final wire = StreamChannelController<String>();
      final seen = <String>[];
      GatewayRpcClient(wire.local, onSocketClosed: (r, c, d) => seen.add(r));
      wire.foreign.sink.addError(StateError('x'));
      unawaited(wire.foreign.sink.close());
      async.flushMicrotasks();

      expect(seen, ['error']);
    });
  });

  test('a throwing callback does not break the close', () {
    fakeAsync((async) {
      final wire = StreamChannelController<String>();
      final client = GatewayRpcClient(
        wire.local,
        onSocketClosed: (r, c, d) => throw StateError('exporter'),
      );
      unawaited(client.close());
      async.flushMicrotasks();

      expect(client.isClosed, isTrue);
    });
  });
}
