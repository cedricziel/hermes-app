import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';

import 'package:hermes_app/src/chat/gateway/gateway_connection.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';

import 'support/fake_hermes_server.dart';

const _page = '<script>window.__HERMES_SESSION_TOKEN__="tok-123";</script>';

void main() {
  group('gatewayUri', () {
    test('uses ws for http and wss for https', () {
      expect(
        gatewayUri('http://127.0.0.1:9119', {'token': 't'}).toString(),
        'ws://127.0.0.1:9119/api/ws?token=t',
      );
      expect(
        gatewayUri('https://hermes.example.com', {'ticket': 'k'}).toString(),
        'wss://hermes.example.com/api/ws?ticket=k',
      );
    });

    test('keeps a path prefix the dashboard is served under', () {
      expect(
        gatewayUri('https://example.com/hermes', {'token': 't'}).toString(),
        'wss://example.com/hermes/api/ws?token=t',
      );
    });

    test('escapes the credential', () {
      expect(
        gatewayUri('http://h', {'ticket': 'a&b=c'}).toString(),
        'ws://h/api/ws?ticket=a%26b%3Dc',
      );
    });
  });

  group('hermesGatewayConnect', () {
    late FakeHermesServer server;
    late List<Uri> opened;
    late StreamChannel<String> channel;

    setUp(() {
      server = FakeHermesServer();
      opened = [];
      channel = StreamChannelController<String>().local;
    });

    GatewayConnect connect({required bool authRequired}) =>
        hermesGatewayConnect(
          baseUrl: 'http://hermes.test',
          authRequired: authRequired,
          api: server.client(),
          open: (uri) async {
            opened.add(uri);
            return channel;
          },
        );

    test(
      'an ungated dashboard is joined with the page\'s session token',
      () async {
        server.on('GET', '/', _page);

        final result = await connect(authRequired: false)();

        expect(
          opened.single.toString(),
          'ws://hermes.test/api/ws?token=tok-123',
        );
        expect(result, same(channel));
      },
    );

    test('a gated dashboard is joined with a fresh ticket', () async {
      server.on('POST', '/api/auth/ws-ticket', {
        'ticket': 'tkt-1',
        'ttl_seconds': 30,
      });

      await connect(authRequired: true)();

      expect(opened.single.toString(), 'ws://hermes.test/api/ws?ticket=tkt-1');
      expect(server.requestsTo('GET', '/'), isEmpty);
    });

    test('every connection mints its own ticket', () async {
      server.on('POST', '/api/auth/ws-ticket', {'ticket': 'tkt-1'});
      final connectGateway = connect(authRequired: true);

      await connectGateway();
      await connectGateway();

      expect(server.requestsTo('POST', '/api/auth/ws-ticket'), hasLength(2));
    });

    test('a page without a session token is an error', () async {
      server.on('GET', '/', '<html>no token</html>');

      await expectLater(
        connect(authRequired: false)(),
        throwsA(isA<StateError>()),
      );
      expect(opened, isEmpty);
    });
  });
}
