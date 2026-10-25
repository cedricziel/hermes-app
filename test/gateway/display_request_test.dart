import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

void main() {
  late FakeGateway gateway;
  late int connects;
  late HermesGatewayTransport transport;

  setUp(() {
    gateway = FakeGateway();
    connects = 0;
    transport = HermesGatewayTransport(
      connect: () {
        connects++;
        return gateway.connect();
      },
      requestTimeout: const Duration(milliseconds: 50),
    );
    gateway.handlers['display.status'] = (_) => {'running': true};
  });

  tearDown(() => transport.close());

  group('error data', () {
    test('an error answer keeps its data and reads data.code', () async {
      gateway.handlers['display.lease.acquire'] = (_) =>
          throw const FakeRpcError(5300, 'not the holder', {
            'code': 'viewer_mismatch',
          });

      final error = await transport
          .request('display.lease.acquire')
          .then<GatewayRpcException?>((_) => null)
          .catchError((Object e) => e as GatewayRpcException);

      expect(error, isNotNull);
      expect(error!.code, 5300);
      expect(error.data, {'code': 'viewer_mismatch'});
      expect(error.dataCode, 'viewer_mismatch');
    });

    test(
      'an error without data, or with a code that is no string, has none',
      () {
        expect(const GatewayRpcException(5300, 'x').data, isNull);
        expect(const GatewayRpcException(5300, 'x').dataCode, isNull);
        expect(
          const GatewayRpcException(5300, 'x', {'code': 7}).dataCode,
          isNull,
        );
      },
    );
  });

  group('a request that does not drop the connection on timeout', () {
    test('throws GatewayRequestTimeout and keeps the connection', () async {
      gateway.silent.add('display.thumbnail');

      await expectLater(
        transport.requestKeepingConnection(
          'display.thumbnail',
          const {},
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<GatewayRequestTimeout>()),
      );
      final answer = await transport.request('display.status');

      expect(answer['running'], isTrue);
      expect(connects, 1);
    });

    test('a late answer to the timed-out call is ignored', () async {
      gateway.silent.add('display.thumbnail');
      await expectLater(
        transport.requestKeepingConnection(
          'display.thumbnail',
          const {},
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<GatewayRequestTimeout>()),
      );

      gateway.replyTo(gateway.requestOf('display.thumbnail'), {
        'data_url': null,
      });
      await pumpEventQueue();

      expect((await transport.request('display.status'))['running'], isTrue);
      expect(connects, 1);
    });

    test('the default request still drops the connection on timeout', () async {
      gateway.silent.add('display.thumbnail');

      await expectLater(
        transport.request('display.thumbnail'),
        throwsA(isA<GatewayConnectionClosed>()),
      );
      await gateway.closedByClient;
      await transport.request('display.status');

      expect(connects, 2);
    });
  });
}
