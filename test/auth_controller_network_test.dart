import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/auth/connect_failure.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/fake_network_signals.dart';
import 'support/memory_token_store.dart';
import 'support/recorded_events.dart';

const _savedKey = 'hermes.server_base_url';

/// A dashboard on [port] (0 for any) that counts the status requests it gets
/// and answers them with [statusCode].
class _Dashboard {
  _Dashboard._(this._server);

  static Future<_Dashboard> start({int port = 0, int statusCode = 200}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final dashboard = _Dashboard._(server)..statusCode = statusCode;
    server.listen(dashboard._handle);
    return dashboard;
  }

  final HttpServer _server;
  int statusCode = 200;
  int statusRequests = 0;

  int get port => _server.port;

  Future<void> close() => _server.close(force: true);

  void _handle(HttpRequest request) {
    final response = request.response;
    if (request.uri.path == '/api/status') {
      statusRequests++;
      response
        ..statusCode = statusCode
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'auth_required': false}));
    } else {
      response.statusCode = 404;
    }
    response.close();
  }
}

/// A loopback port nothing listens on.
Future<int> _closedPort() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close(force: true);
  return port;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 300));

void main() {
  late FakeNetworkSignals signals;
  late RecordedEvents events;
  late InMemorySharedPreferencesAsync prefs;

  setUp(() {
    signals = FakeNetworkSignals();
    events = RecordedEvents();
    prefs = InMemorySharedPreferencesAsync.empty();
    SharedPreferencesAsyncPlatform.instance = prefs;
  });

  tearDown(() => signals.close());

  AuthController controller() => AuthController(
    tokenStore: MemoryTokenStore(),
    events: events.call,
    networkSignals: signals,
  );

  Future<void> save(int port) =>
      SharedPreferencesAsync().setString(_savedKey, 'http://127.0.0.1:$port');

  group('failure classification', () {
    test('records a lookup failure and keeps the message', () async {
      final auth = controller();

      await auth.connect('http://hermes-nowhere.invalid');

      expect(auth.state, HermesConnectionState.connectionError);
      expect(
        auth.errorMessage,
        'Could not reach http://hermes-nowhere.invalid',
      );
      expect(auth.lastFailure?.kind, ConnectFailureKind.dns);
      expect(auth.lastFailure?.retryable, isTrue);
    });

    test('records a refused connection', () async {
      final auth = controller();
      final port = await _closedPort();

      await auth.connect('http://127.0.0.1:$port');

      expect(auth.errorMessage, 'Could not reach http://127.0.0.1:$port');
      expect(auth.lastFailure?.kind, ConnectFailureKind.refused);
      expect(auth.lastFailure?.hostKind, HostKind.public);
    });

    test('records an error answer as not retryable', () async {
      final dashboard = await _Dashboard.start(statusCode: 503);
      addTearDown(dashboard.close);
      final auth = controller();

      await auth.connect('http://127.0.0.1:${dashboard.port}');

      expect(auth.lastFailure?.kind, ConnectFailureKind.http);
      expect(auth.lastFailure?.retryable, isFalse);
    });

    test('a new connect clears the last failure', () async {
      final dashboard = await _Dashboard.start();
      addTearDown(dashboard.close);
      final auth = controller();
      await auth.connect('http://127.0.0.1:${await _closedPort()}');
      expect(auth.lastFailure, isNotNull);

      await auth.connect('http://127.0.0.1:${dashboard.port}');

      expect(auth.lastFailure, isNull);
      expect(auth.state, HermesConnectionState.ready);
    });

    test('reports whether a VPN is active from the signals', () {
      signals.vpnActive = true;
      expect(controller().vpnActive, isTrue);
    });
  });

  group('checking again after a network change', () {
    test('connects to the saved address when the VPN comes up', () async {
      final port = await _closedPort();
      await save(port);
      final auth = controller();
      await auth.bootstrap();
      expect(auth.state, HermesConnectionState.connectionError);
      expect(auth.errorMessage, 'Could not reach http://127.0.0.1:$port');

      final dashboard = await _Dashboard.start(port: port);
      addTearDown(dashboard.close);
      signals.change();
      await _settle();

      expect(auth.state, HermesConnectionState.ready);
      expect(dashboard.statusRequests, 1);
    });

    test('a burst of changes makes one attempt', () async {
      final port = await _closedPort();
      await save(port);
      final auth = controller();
      await auth.bootstrap();
      final dashboard = await _Dashboard.start(port: port);
      addTearDown(dashboard.close);

      signals
        ..change()
        ..change()
        ..change();
      await _settle();

      expect(dashboard.statusRequests, 1);
    });

    test('a failing retry stays a connection error', () async {
      final port = await _closedPort();
      await save(port);
      final auth = controller();
      await auth.bootstrap();
      final before = events.named('auth.connect.failed').length;

      signals.change();
      await _settle();

      expect(auth.state, HermesConnectionState.connectionError);
      expect(auth.errorMessage, 'Could not reach http://127.0.0.1:$port');
      expect(events.named('auth.connect.failed').length, before + 1);
      expect(events.named('auth.connect.failed').last['retry'], isTrue);
    });

    test('does not retry after an error answer', () async {
      final dashboard = await _Dashboard.start(statusCode: 503);
      addTearDown(dashboard.close);
      await save(dashboard.port);
      final auth = controller();
      await auth.bootstrap();
      expect(dashboard.statusRequests, 1);

      dashboard.statusCode = 200;
      signals.change();
      await _settle();

      expect(dashboard.statusRequests, 1);
      expect(auth.state, HermesConnectionState.connectionError);
    });

    test('does not retry when there is no saved address', () async {
      final port = await _closedPort();
      final auth = controller();
      await auth.connect('http://127.0.0.1:$port');
      final dashboard = await _Dashboard.start(port: port);
      addTearDown(dashboard.close);

      signals.change();
      await _settle();

      expect(dashboard.statusRequests, 0);
    });

    test('does not retry an address that is not the saved one', () async {
      final savedPort = await _closedPort();
      final typedPort = await _closedPort();
      await save(savedPort);
      final auth = controller();
      await auth.bootstrap();
      await auth.connect('http://127.0.0.1:$typedPort');
      final saved = await _Dashboard.start(port: savedPort);
      addTearDown(saved.close);

      signals.change();
      await _settle();

      expect(saved.statusRequests, 0);
      expect(auth.state, HermesConnectionState.connectionError);
    });

    test('does nothing when the app is connected', () async {
      final dashboard = await _Dashboard.start();
      addTearDown(dashboard.close);
      await save(dashboard.port);
      final auth = controller();
      await auth.bootstrap();
      expect(auth.state, HermesConnectionState.ready);

      signals.change();
      await _settle();

      expect(dashboard.statusRequests, 1);
    });
  });

  group('telemetry', () {
    test('reports the failure without the address', () async {
      final auth = controller();

      final port = await _closedPort();
      await auth.connect('http://127.0.0.1:$port');
      await auth.connect('http://hermes-nowhere.invalid');

      final failures = events.named('auth.connect.failed');
      expect(failures, hasLength(2));
      expect(failures.last, {
        'reason': 'dns',
        'host_kind': 'public',
        'retry': false,
      });
      for (final attributes in failures) {
        expect(attributes.values.join(' '), isNot(contains('127.0.0.1')));
        expect(attributes.values.join(' '), isNot(contains('nowhere')));
      }
    });
  });

  test('a slow connect that ends last does not replace a newer one', () async {
    final slow = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    slow.listen((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'auth_required': false}));
      unawaited(request.response.close());
    });
    final fast = await _Dashboard.start();
    addTearDown(() => slow.close(force: true));
    addTearDown(fast.close);
    final auth = controller();

    final first = auth.connect('http://127.0.0.1:${slow.port}');
    await auth.connect('http://127.0.0.1:${fast.port}');
    await first;

    expect(auth.baseUrl, 'http://127.0.0.1:${fast.port}');
    expect(
      await SharedPreferencesAsync().getString(_savedKey),
      'http://127.0.0.1:${fast.port}',
    );
  });

  test('changing the server while a connect runs keeps it cleared', () async {
    final slow = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    slow.listen((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'auth_required': false}));
      unawaited(request.response.close());
    });
    addTearDown(() => slow.close(force: true));
    final auth = controller();

    final pending = auth.connect('http://127.0.0.1:${slow.port}');
    await auth.changeServer();
    await pending;

    expect(auth.baseUrl, isNull);
    expect(auth.state, HermesConnectionState.needsServerUrl);
    expect(await SharedPreferencesAsync().getString(_savedKey), isNull);
  });
}
