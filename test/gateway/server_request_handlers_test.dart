import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import '../support/fake_gateway.dart';

/// `display.install.sudo` reaches only the connection that started the
/// install, and its session id is empty.
void main() {
  late FakeGateway gateway;
  late HermesGatewayTransport transport;

  setUp(() async {
    gateway = FakeGateway();
    transport = HermesGatewayTransport(connect: gateway.connect);
    gateway.handlers['display.status'] = (_) => {'running': true};
    // Opens the socket, which is what listens for server requests.
    await transport.request('display.status');
  });

  tearDown(() => transport.close());

  Map<String, Object?> answer(String id, String key, Object? body) => {
    'jsonrpc': '2.0',
    'id': id,
    key: body,
  };

  Map<String, Object?> error(String id, int code, String message) =>
      answer(id, 'error', {'code': code, 'message': message});

  Map<String, Object?> refusal(String id) =>
      error(id, kGatewayMethodNotFound, 'Method not found');

  test('a sudo request with no handler is refused at once, whatever its '
      'session', () async {
    gateway.serverRequest('srq-1', 'display.install.sudo', '', {
      'profile_key': '/home/u/.hermes',
    });
    await pumpEventQueue();

    expect(gateway.responses, [refusal('srq-1')]);
  });

  test('other unhandled requests are left alone while no reply of their '
      'session is running', () async {
    gateway.serverRequest('srq-2', 'terminal.read', '');
    await pumpEventQueue();

    expect(gateway.responses, isEmpty);
  });

  test('a call can say which connection carried it', () async {
    final (result, connection) = await transport
        .requestKeepingConnectionOnClient(
          'display.status',
          const {},
          timeout: const Duration(seconds: 5),
        );

    expect(result['running'], isTrue);
    expect(identical(connection, transport.gatewayConnection), isTrue);
  });

  group('a registered handler', () {
    const method = 'display.install.sudo';

    test('answers the request with its result', () async {
      GatewayServerRequest? seen;
      transport.registerServerRequestHandler(method, (
        request,
        connection,
      ) async {
        seen = request;
        return {'value': 'hunter2'};
      });

      gateway.serverRequest('srq-3', method, '', {'profile_key': 'k'});
      await pumpEventQueue();

      expect(gateway.responses, [
        answer('srq-3', 'result', {'value': 'hunter2'}),
      ]);
      expect(seen?.params['profile_key'], 'k');
      expect(seen?.sessionId, '');
    });

    test('is handed the connection the request arrived on', () async {
      Object? seen;
      transport.registerServerRequestHandler(method, (
        request,
        connection,
      ) async {
        seen = connection;
        return {'value': ''};
      });

      gateway.serverRequest('srq-3', method, '');
      await pumpEventQueue();

      expect(seen, isNotNull);
      expect(identical(seen, transport.gatewayConnection), isTrue);
    });

    test('that throws answers an internal error without its message', () async {
      transport.registerServerRequestHandler(method, (
        request,
        connection,
      ) async {
        throw StateError('secret detail');
      });

      gateway.serverRequest('srq-4', method, '');
      await pumpEventQueue();

      expect(gateway.responses, [error('srq-4', -32603, 'Internal error')]);
    });

    test('that refuses with a gateway error answers that error', () async {
      transport.registerServerRequestHandler(method, (
        request,
        connection,
      ) async {
        throw const GatewayRpcException(-32602, 'Not requested');
      });

      gateway.serverRequest('srq-5', method, '');
      await pumpEventQueue();

      expect(gateway.responses, [error('srq-5', -32602, 'Not requested')]);
    });

    test(
      'is replaced by a later one, and only its own unregister removes it',
      () async {
        final removeFirst = transport.registerServerRequestHandler(
          method,
          (request, connection) async => {'value': 'first'},
        );
        transport.registerServerRequestHandler(
          method,
          (request, connection) async => {'value': 'second'},
        );
        removeFirst();

        gateway.serverRequest('srq-6', method, '');
        await pumpEventQueue();

        expect(gateway.responses.single['result'], {'value': 'second'});
      },
    );

    test('unregistering restores the refusal', () async {
      final remove = transport.registerServerRequestHandler(
        method,
        (request, connection) async => {'value': 'x'},
      );
      remove();

      gateway.serverRequest('srq-7', method, '');
      await pumpEventQueue();

      expect(gateway.responses, [refusal('srq-7')]);
    });

    test('cannot take over a request the app already answers', () {
      expect(
        () => transport.registerServerRequestHandler(
          'approval',
          (request, connection) async => {},
        ),
        throwsArgumentError,
      );
    });
  });
}
