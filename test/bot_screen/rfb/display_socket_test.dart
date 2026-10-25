import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:hermes_app/src/bot_screen/rfb/display_socket.dart';

const _ticket = 'tick-3f9a-secret';

void main() {
  late HttpServer server;
  late Uri seen;
  late Future<WebSocket> Function(HttpRequest) onRequest;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    onRequest = WebSocketTransformer.upgrade;
    server.listen((request) async {
      seen = request.uri;
      try {
        await onRequest(request);
      } on Object catch (_) {}
    });
  });
  tearDown(() => server.close(force: true));

  String base([String prefix = '']) => 'http://127.0.0.1:${server.port}$prefix';

  group('displaySocketUri', () {
    test('uses wss for an https dashboard and keeps the path prefix', () {
      final uri = displaySocketUri(
        'https://example.net/hermes',
        '/api/display/ws',
        _ticket,
      );
      expect(uri.scheme, 'wss');
      expect(uri.host, 'example.net');
      expect(uri.path, '/hermes/api/display/ws');
      expect(uri.queryParameters, {'display_ticket': _ticket});
    });

    test('uses ws for an http dashboard', () {
      final uri = displaySocketUri('http://10.0.0.2:9119', '/p', _ticket);
      expect(uri.scheme, 'ws');
      expect(uri.queryParameters.keys, ['display_ticket']);
    });
  });

  group('openDisplaySocket', () {
    test(
      'connects with only the display ticket under the path prefix',
      () async {
        final channel = await openDisplaySocket(
          base('/hermes'),
          '/api/display/ws',
          _ticket,
        );
        await channel.sink.close();

        expect(seen.path, '/hermes/api/display/ws');
        expect(seen.queryParameters, {'display_ticket': _ticket});
      },
    );

    test('exposes the close code the server sends', () async {
      onRequest = (request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        await socket.close(4401, 'bad ticket');
        return socket;
      };
      final channel = await openDisplaySocket(base(), '/ws', _ticket);
      await channel.stream.drain<void>();

      expect(channel.closeCode, 4401);
    });

    test('closes with the status code of its choosing', () async {
      final closed = Completer<int?>();
      onRequest = (request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((_) {}, onDone: () => closed.complete(socket.closeCode));
        return socket;
      };
      final channel = await openDisplaySocket(base(), '/ws', _ticket);
      await channel.sink.close(4100);

      expect(await closed.future, 4100);
    });

    test(
      'maps a refused upgrade to notAllowed without URL or ticket',
      () async {
        onRequest = (request) async {
          request.response.statusCode = HttpStatus.forbidden;
          await request.response.close();
          throw StateError('refused');
        };
        final error = await _failure(
          openDisplaySocket(base('/hermes'), '/api/display/ws', _ticket),
        );

        expect(error.kind, DisplaySocketErrorKind.notAllowed);
        _expectNoSecrets(error, server.port);
      },
    );

    test(
      'maps a refused connection to unreachable without URL or ticket',
      () async {
        final port = server.port;
        await server.close(force: true);
        final error = await _failure(
          openDisplaySocket('http://127.0.0.1:$port/hermes', '/ws', _ticket),
        );

        expect(error.kind, DisplaySocketErrorKind.unreachable);
        _expectNoSecrets(error, port);
      },
    );
  });

  group('displaySocketErrorFor', () {
    test('maps only an HTTP 403 upgrade refusal to notAllowed', () {
      DisplaySocketErrorKind kindOf(int? status) => displaySocketErrorFor(
        WebSocketChannelException.from(
          WebSocketException('not upgraded', status),
        ),
      ).kind;

      expect(kindOf(403), DisplaySocketErrorKind.notAllowed);
      expect(kindOf(404), DisplaySocketErrorKind.unreachable);
      expect(kindOf(null), DisplaySocketErrorKind.unreachable);
    });

    test('maps a failed certificate check to untrustedCertificate', () {
      final error = displaySocketErrorFor(
        const HandshakeException(
          'Handshake error in client',
          OSError('CERTIFICATE_VERIFY_FAILED: unable to get local issuer', 0),
        ),
      );
      expect(error.kind, DisplaySocketErrorKind.untrustedCertificate);
    });

    test('maps any other handshake failure to unreachable', () {
      final error = displaySocketErrorFor(
        const HandshakeException('Connection terminated during handshake'),
      );
      expect(error.kind, DisplaySocketErrorKind.unreachable);
    });
  });
}

Future<DisplaySocketError> _failure(Future<Object?> open) async {
  try {
    await open;
  } on DisplaySocketError catch (error) {
    return error;
  }
  fail('Expected a DisplaySocketError');
}

void _expectNoSecrets(DisplaySocketError error, int port) {
  final text = '$error ${error.kind.name}';
  expect(text, isNot(contains(_ticket)));
  expect(text, isNot(contains('127.0.0.1')));
  expect(text, isNot(contains('$port')));
  expect(text, isNot(contains('display_ticket')));
}
