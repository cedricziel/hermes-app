import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ErrorCallback;

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:hermes_app/src/telemetry/telemetry_config.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_token_store.dart';

class _RecordingExporter implements LogRecordExporter {
  final records = <LogRecord>[];

  @override
  Future<ExportResult> export(
    List<LogRecord> records,
    OTelResource resource,
  ) async {
    this.records.addAll(records);
    return const ExportResult.success();
  }

  @override
  Future<void> shutdown() async {}
}

/// A gated dashboard reporting [status], whose `/api/auth/me` waits for
/// [meGate] when it is set.
class _Dashboard {
  _Dashboard._(this._server, this.status);

  static Future<_Dashboard> start(Map<String, Object> status) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final dashboard = _Dashboard._(server, status);
    server.listen(dashboard._handle);
    return dashboard;
  }

  final HttpServer _server;
  Map<String, Object> status;
  Completer<void>? meGate;

  String get url => 'http://127.0.0.1:${_server.port}';

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final body = switch (request.uri.path) {
      '/api/status' => status,
      '/api/auth/providers' => {
        'providers': [
          {'name': 'basic', 'display_name': 'Password'},
        ],
      },
      '/auth/native/refresh' => {
        'access_token': 'at-2',
        'refresh_token': 'rt-2',
        'expires_at': _farFuture,
        'provider': 'basic',
        'user_id': 'u1',
      },
      _ => {'user_id': 'u1'},
    };
    if (request.uri.path == '/api/auth/me') await meGate?.future;
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }
}

Map<String, Object> _status(String installId, {String version = '0.14.2'}) => {
  'version': version,
  'install_id': installId,
  'auth_required': true,
  'auth_providers': ['basic'],
  'auth_flows': ['native_pkce'],
  'gateway_mode': 'multiplex',
  'profiles': ['default', 'work', 'research'],
  'gateway_state': 'running',
  'overall': 'ok',
  'hermes_home': '/home/me/.hermes',
};

final _farFuture =
    DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;

HermesSession _session({required int expiresAt}) => HermesSession(
  accessToken: 'at',
  refreshToken: 'rt',
  expiresAt: expiresAt,
  provider: 'basic',
  userId: 'u1',
);

void main() {
  late _RecordingExporter exporter;
  late Telemetry telemetry;
  late _Dashboard a;
  late AuthController controller;
  late FlutterExceptionHandler? previousFlutterHandler;
  late ErrorCallback? previousPlatformHandler;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    previousFlutterHandler = FlutterError.onError;
    previousPlatformHandler = PlatformDispatcher.instance.onError;
    exporter = _RecordingExporter();
    telemetry = await Telemetry.initialize(
      TelemetryConfig(
        otlpEndpoint: 'http://127.0.0.1:9',
        otlpHeaders: const {},
        serviceName: 'hermes-app',
        serviceVersion: '',
        deploymentEnvironment: 'test',
      ),
      logExporter: exporter,
    );
    a = await _Dashboard.start(_status('inst_a'));
    controller = AuthController(
      tokenStore: MemoryTokenStore(),
      // Expired, so the first request after signing in refreshes it.
      login: (url, {provider, httpClient, cancelled}) async =>
          _session(expiresAt: 0),
      telemetry: telemetry.forConnection,
    );
  });

  tearDown(() async {
    FlutterError.onError = previousFlutterHandler;
    PlatformDispatcher.instance.onError = previousPlatformHandler;
    controller.dispose();
    await a.close();
  });

  Future<List<LogRecord>> records() async {
    await telemetry.flush();
    return exporter.records;
  }

  Iterable<LogRecord> named(List<LogRecord> all, String body) =>
      all.where((r) => r.body == body);

  Iterable<LogRecord> requests(List<LogRecord> all, String route) =>
      all.where((r) => r.attributes['http.route'] == route);

  bool describesServer(LogRecord record) =>
      record.attributes.keys.any((key) => key.startsWith('hermes.'));

  Future<void> signIn() async {
    await controller.signInWithProvider(controller.providers.single);
    expect(controller.state, HermesConnectionState.ready);
  }

  test('describes the requests and events of a connection with its server, '
      'but not the probe or what came before it', () async {
    await controller.connect(a.url);
    await signIn();
    await controller.api!.fetchMe();

    final all = await records();
    final me = requests(all, '/api/auth').last;
    expect(me.attributes, containsPair('hermes.install_id', 'inst_a'));
    expect(me.attributes, containsPair('hermes.version', '0.14.2'));
    expect(me.attributes, containsPair('hermes.auth.required', true));
    expect(me.attributes, containsPair('hermes.auth.providers', ['basic']));
    expect(me.attributes, containsPair('hermes.gateway.mode', 'multiplex'));
    expect(me.attributes, containsPair('hermes.profile.count', 3));
    expect(me.attributes, containsPair('hermes.gateway.state', 'running'));
    expect(me.attributes, containsPair('hermes.overall', 'ok'));
    expect(me.attributes.values, isNot(contains('/home/me/.hermes')));
    expect(
      requests(all, '/auth/native').single.attributes,
      containsPair('hermes.install_id', 'inst_a'),
    );
    for (final event in [
      'server.connected',
      'auth.sign_in.started',
      'auth.sign_in.succeeded',
      'auth.session.refreshed',
    ]) {
      expect(
        named(all, event).single.attributes,
        containsPair('hermes.install_id', 'inst_a'),
        reason: event,
      );
    }
    expect(describesServer(requests(all, '/api/status').single), isFalse);
    final connecting = named(
      all,
      'auth.state',
    ).firstWhere((r) => r.attributes['state'] == 'connecting');
    expect(describesServer(connecting), isFalse);
  });

  test('keeps the connection across a sign-out', () async {
    await controller.connect(a.url);
    await signIn();
    await controller.signOut();
    await signIn();

    final starts = named(await records(), 'auth.sign_in.started').toList();
    expect(starts, hasLength(2));
    expect(starts.last.attributes, containsPair('hermes.install_id', 'inst_a'));
  });

  test('says nothing of a server after Change Server', () async {
    final b = await _Dashboard.start(_status('inst_b'));
    addTearDown(b.close);
    await controller.connect(a.url);
    await signIn();
    await telemetry.flush();
    final before = exporter.records.length;

    await controller.changeServer();
    await controller.connect(b.url);
    await controller.api!.fetchAuthProviders();

    final after = (await records()).skip(before).toList();
    expect(after.where((r) => r.attributes.values.contains('inst_a')), isEmpty);
    expect(
      requests(after, '/api/auth').last.attributes,
      containsPair('hermes.install_id', 'inst_b'),
    );
  });

  test('a failed connect to a new address carries no server', () async {
    await controller.connect(a.url);
    final unreachable = await ServerSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = unreachable.port;
    await unreachable.close();
    await telemetry.flush();
    final before = exporter.records.length;

    await controller.connect('http://127.0.0.1:$port');

    final after = (await records()).skip(before).toList();
    expect(named(after, 'auth.connect.failed'), hasLength(1));
    expect(after.where(describesServer), isEmpty);
  });

  test('a new connect to the same server reads its status again', () async {
    await controller.connect(a.url);
    a.status = _status('inst_a', version: '0.15.0');
    await controller.connect(a.url);

    expect(
      named(
        await records(),
        'server.connected',
      ).map((r) => r.attributes['hermes.version']),
      ['0.14.2', '0.15.0'],
    );
  });

  test('a request keeps its server when it finishes after a switch', () async {
    final b = await _Dashboard.start(_status('inst_b'));
    addTearDown(b.close);
    await controller.connect(a.url);
    await signIn();
    final gate = a.meGate = Completer<void>();
    final pending = controller.api!.fetchMe();

    await controller.connect(b.url);
    gate.complete();
    await pending;

    final me = requests(await records(), '/api/auth').last;
    expect(me.attributes, containsPair('hermes.install_id', 'inst_a'));
  });

  test('a crash lists the server version once and no other server '
      'attribute', () async {
    telemetry.logUncaughtErrors();
    await controller.connect(a.url);
    await signIn();

    FlutterError.onError!(FlutterErrorDetails(exception: StateError('boom')));

    final crash = named(await records(), 'Uncaught Flutter error').single;
    final breadcrumbs = (crash.attributes['breadcrumbs']! as List)
        .cast<String>();
    final connected = breadcrumbs.singleWhere(
      (b) => b.contains('server.connected'),
    );
    expect(connected, contains('0.14.2'));
    expect(connected, isNot(contains('inst_a')));
    expect(
      breadcrumbs.where((b) => b != connected && b.contains('hermes.')),
      isEmpty,
    );
  });
}
