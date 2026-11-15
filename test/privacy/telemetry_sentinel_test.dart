import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/kanban/kanban_board_controller.dart';
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/server_care/server_care_controller.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/hermes_server_attributes.dart';
import 'package:hermes_app/src/telemetry/suspension_marking_tracer.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:stream_channel/stream_channel.dart';

import '../server_care/server_care_fixtures.dart';
import '../support/fake_chat_transport.dart';
import '../support/fake_gateway.dart';
import '../support/fake_hermes_server.dart';
import '../support/kanban_fixtures.dart';
import '../support/local_dashboard.dart';
import '../support/memory_token_store.dart';
import '../support/pump_chat.dart';
import '../support/recording_tracer.dart';

/// The privacy guard for telemetry: breadcrumbs, app events, request logs,
/// spans, `debugPrint` and `print` carry fixed names, counts, flags and
/// outcomes, never what the user typed or named.
///
/// The connection's telemetry is built by the production wiring
/// (`buildConnectionTelemetry`) with every sink captured, then the widest
/// flows the test support allows run on data made of sentinels. A sentinel in
/// any captured record, in the raw, URL-encoded or base64 form, is a leak.
/// When a feature adds telemetry, add its flow here.
///
/// Exempt by design: the exact `hermes.*` attribute pairs the server's status
/// answer yields (`hermesServerAttributes`) and the crash reporter's error
/// payload. Crash breadcrumbs are the trail captured here, so they are
/// checked.

const _msg = 'SENTINEL_MSG_7f3a';
// A space and an ampersand, so URL escaping is exercised.
const _title = 'SENTINEL_TITLE_7f3a & more';
const _titleMarker = 'SENTINEL_TITLE_7f3a';
const _profile = 'SENTINEL_PROFILE_7f3a';
const _host = 'sentinel-host-7f3a.example';
const _token = 'SENTINEL_TOKEN_7f3a';
const _password = 'SENTINEL_PW_7f3a';
const _session = 'sess-sentinel-7f3a';
const _runtimeSession = 'rt-sentinel-7f3a';
const _storedSession = 'stored-sentinel-7f3a';
const _user = 'SENTINEL_USER_7f3a';

const _sentinels = [
  _msg,
  _title,
  _titleMarker,
  _profile,
  _host,
  _token,
  _password,
  _session,
  _runtimeSession,
  _storedSession,
  _user,
];

/// Known leaks of main, as `sink|sentinel`, each with a TODO to fix it. The
/// list only shrinks.
const _knownLeaks = <String>{};

/// What the server's status answer describes it with: the only `hermes.*`
/// pairs allowed in telemetry.
final _serverAttributes = hermesServerAttributes({
  'version': '0.22.2',
  'install_id': 'inst_7f3a',
  'auth_required': true,
  'gateway_state': 'running',
});

/// The forms a sentinel can take in a record: as is (any case), URL-encoded,
/// and base64 or base64url at any alignment.
class _Needle {
  _Needle(this.sentinel) {
    final bytes = utf8.encode(sentinel);
    caseless = {
      sentinel,
      Uri.encodeComponent(sentinel),
      Uri.encodeQueryComponent(sentinel),
    }.map((s) => s.toLowerCase()).toList();
    for (var shift = 0; shift < 3; shift++) {
      final encoded = base64
          .encode([...List.filled(shift, 0), ...bytes])
          .replaceAll('=', '');
      // Only the characters made of the sentinel's bytes alone.
      final from = (shift * 8 + 5) ~/ 6;
      final to = ((shift + bytes.length) * 8) ~/ 6;
      final stable = encoded.substring(from, to);
      exact
        ..add(stable)
        ..add(stable.replaceAll('+', '-').replaceAll('/', '_'));
    }
  }

  final String sentinel;
  late final List<String> caseless;
  final exact = <String>{};

  bool inside(String text) {
    final lower = text.toLowerCase();
    return caseless.any(lower.contains) || exact.any(text.contains);
  }
}

final _needles = [for (final s in _sentinels) _Needle(s)];

typedef _Record = ({String sink, String text});

/// Everything the app's telemetry and logging produced during one test.
class _Sinks {
  final records = <_Record>[];
  final tracer = _CapturingTracer();
  late final trail = _CapturingTrail(this);
  late final logger = _CapturingLogger(this);

  void add(String sink, String text) => records.add((sink: sink, text: text));

  /// The connection's telemetry as production wires it, with every sink
  /// captured.
  ConnectionTelemetry connection(Map<String, Object> serverAttributes) =>
      buildConnectionTelemetry(
        logger: logger,
        tracer: tracer,
        suspensions: AppSuspensions.manual(),
        breadcrumbs: trail,
        serverAttributes: serverAttributes,
      );

  Breadcrumbs get breadcrumbs => Breadcrumbs.of(trail);

  /// Runs [body] with `print` captured, so a stray print is a record too.
  Future<T> capturingPrint<T>(Future<T> Function() body) => runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => add('print', line),
    ),
  );

  /// Every record that carries a sentinel, one line each.
  List<String> leaks() {
    final found = <String>[];
    void check(String sink, String text) {
      for (final needle in _needles) {
        if (!needle.inside(text)) continue;
        if (_knownLeaks.contains('$sink|${needle.sentinel}')) continue;
        found.add('$sink | ${needle.sentinel} | $text');
      }
    }

    for (final r in records) {
      check(r.sink, r.text);
    }
    for (final span in tracer.all) {
      check('span', span.describe());
    }
    return found;
  }
}

String _describe(Map<String, Object?> attributes) => [
  for (final e in attributes.entries)
    // The server's own description, exempt by design: only the exact pair.
    if (_serverAttributes[e.key] != e.value ||
        !_serverAttributes.containsKey(e.key))
      '${e.key}=${e.value}',
].join(', ');

class _CapturingTrail extends BreadcrumbTrail {
  _CapturingTrail(this._sinks) : super(capacity: 100000);

  final _Sinks _sinks;

  @override
  void record(String name, [Map<String, Object> attributes = const {}]) {
    _sinks.add('breadcrumb', '$name {${_describe(attributes)}}');
    super.record(name, attributes);
  }
}

class _CapturingLogger extends Logger {
  _CapturingLogger(this._sinks);

  final _Sinks _sinks;

  @override
  void emit(LogRecord record) =>
      _sinks.add('log', '${record.body} {${_describe(record.attributes)}}');
}

class _CapturingSpan extends RecordingSpan {
  _CapturingSpan(super.name, super.kind, super.spanContext);

  String describe() =>
      '$name {${_describe(attributes)}} events=$eventDetails '
      'status=$statusDescription';
}

class _CapturingTracer extends RecordingTracer {
  final all = <_CapturingSpan>[];

  @override
  Span startSpan(
    String name, {
    SpanKind kind = SpanKind.internal,
    Map<String, Object?>? attributes,
    SpanContext? parentContext,
    List<SpanLink> links = const [],
  }) {
    final span = _CapturingSpan(
      name,
      kind,
      SpanContext(
        traceId: 'a' * 32,
        spanId: '${all.length + 1}'.padLeft(16, '0'),
      ),
    );
    if (attributes != null) span.setAttributes(attributes);
    all.add(span);
    return span;
  }
}

/// A client on [server] whose base URL is the sentinel host, so a request log
/// or span that names the server shows it.
HermesApiClient _client(FakeHermesServer server, ConnectionTelemetry c) {
  final dio = server.dio()..options.baseUrl = 'http://$_host';
  final interceptor = c.interceptor;
  if (interceptor != null) dio.interceptors.add(interceptor);
  return HermesApiClient(dio);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Sinks sinks;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    sinks = _Sinks();
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      sinks.add('debugPrint', message ?? '');
    };
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
  });

  void expectClean() {
    // The binding checks that tests leave foundation variables alone before
    // tearDown runs.
    debugPrint = originalDebugPrint;
    final leaks = sinks.leaks();
    expect(
      leaks,
      isEmpty,
      reason:
          'User content reached telemetry. Each line is sink | sentinel | '
          'record. Rule: use a fixed name or a count; see '
          'docs/architecture/telemetry.md.\n${leaks.join('\n')}',
    );
  }

  test('sign in, sign out and change server', () async {
    final dashboard = await LocalDashboard.start({
      '/api/status': {
        'auth_required': true,
        'auth_flows': ['native_pkce', 'password'],
        'version': '0.22.2',
      },
      '/api/auth/providers': {
        'providers': [
          {'name': 'basic', 'display_name': 'Password', 'password': true},
        ],
      },
      '/api/auth/me': {
        'user_id': _user,
        'email': '$_user@$_host',
        'display_name': _user,
        'org_id': 'acme',
        'provider': 'basic',
      },
    });
    addTearDown(dashboard.close);

    final auth = AuthController(
      tokenStore: MemoryTokenStore(),
      telemetry: sinks.connection,
      login: (baseUrl, {provider, httpClient, cancelled}) async =>
          // The password ($_password) is typed into the browser page, never
          // into the app; the app only gets the tokens back.
          const HermesSession(
            accessToken: _token,
            refreshToken: _token,
            expiresAt: 4102444800,
            provider: 'basic',
            userId: _user,
          ),
    );
    addTearDown(auth.dispose);

    await sinks.capturingPrint(
      // The sentinel address resolves to the local dashboard.
      () => HttpOverrides.runWithHttpOverrides(() async {
        await auth.connect('http://$_host:80', allowCleartext: true);
        expect(auth.state, HermesConnectionState.needsLogin);
        await auth.signInWithProvider(auth.providers.single);
        expect(auth.state, HermesConnectionState.ready);
        await auth.signOut();
        await auth.changeServer();
      }, _RedirectTo(dashboard)),
    );

    expect(sinks.records, isNotEmpty);
    expectClean();
  });

  testWidgets('chat: list, open, send, reply, switch profile', (tester) async {
    final server = FakeHermesServer()
      ..on(
        'GET',
        '/api/profiles',
        profileListBody([
          profileRow(name: 'default', isDefault: true),
          profileRow(name: _profile, displayName: _profile),
        ]),
      )
      ..on('POST', '/api/profiles/active', {'ok': true})
      ..on('GET', '/api/profiles/active', activeProfileBody(active: 'default'));
    for (final profile in ['default', _profile]) {
      server
        ..on(
          'GET',
          '/api/sessions',
          sessionListBody([sessionRow(id: _session, title: _title)]),
          query: {'profile': profile},
        )
        ..on(
          'GET',
          '/api/sessions/$_session/messages',
          messageListBody(_session, [
            messageRow(id: 1, role: 'user', content: _msg),
            messageRow(id: 2, role: 'assistant', content: 'echo $_msg'),
          ]),
          query: {'profile': profile},
        );
    }
    final connection = sinks.connection(_serverAttributes);
    final api = _client(server, connection);
    final transport = FakeChatTransport();

    await sinks.capturingPrint(() async {
      await pumpChatScreen(
        tester,
        api: api,
        withProfiles: true,
        transport: transport,
        providers: [
          Provider<Breadcrumbs>.value(value: sinks.breadcrumbs),
          Provider<HermesRepositories>.value(
            value: HermesRepositories(api, telemetry: connection),
          ),
        ],
      );
      await openThread(tester, _title);
      await tester.enterText(composerField, _msg);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump(const Duration(seconds: 1));
      transport.sends.single
        ..emit(const ReplyStarted())
        ..emit(ReplyDelta('reply with $_msg'))
        ..emit(ReplyCompleted('final reply with $_msg'));
      await tester.pumpAndSettle();

      await openSidebarMore(tester);
      await tester.tap(find.text('Profiles'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_profile));
      await tester.pumpAndSettle();
    });

    // The chat's own requests reached the sinks.
    expect(
      sinks.tracer.all.map((s) => s.attributes.values.join(' ')).join('\n'),
      contains('/api/sessions'),
    );
    expect(sinks.records, isNotEmpty);
    expectClean();
  });

  test('gateway: prompt with the message, reply that echoes it', () async {
    final gateway = FakeGateway()
      ..createResult = {
        'session_id': _runtimeSession,
        'stored_session_id': _storedSession,
      }
      ..resumeResult = {
        'session_id': _runtimeSession,
        'session_key': _storedSession,
      }
      ..turn = (g, sid) {
        g.event('message.start', sid);
        g.event('message.delta', sid, {'text': 'echo $_msg'});
        g.event('message.complete', sid, {
          'text': 'echo $_msg',
          'status': 'complete',
        });
      };
    final connection = sinks.connection(_serverAttributes);
    final transport = HermesGatewayTransport(
      connect: () async => gateway.channel,
      telemetry: connection.gateway(),
      events: connection.events,
    );
    addTearDown(transport.close);

    await sinks.capturingPrint(() async {
      // A new chat, then the sentinel chat resumed.
      await transport.send(text: _msg, profile: _profile).toList();
      final events = await transport
          .send(text: _msg, threadId: _session, profile: _profile)
          .toList();
      expect(events.whereType<ReplyCompleted>(), isNotEmpty);
    });

    expect(sinks.tracer.all, isNotEmpty);
    expectClean();
  });

  test('server care and kanban', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/status', statusHealthy())
      ..on(
        'GET',
        '/api/plugins/kanban/boards',
        kanbanBoardsBody([
          (slug: 'default', name: _title, total: 1, current: true),
        ]),
      )
      ..on(
        'GET',
        '/api/plugins/kanban/board',
        kanbanBoardBody([kanbanTaskRow(id: 't1', title: _title)]),
      );
    final connection = sinks.connection(_serverAttributes);
    final api = _client(server, connection);

    final care = ServerCareController(
      repository: ServerCareRepository(api),
      telemetry: connection,
      profile: _profile,
    );
    addTearDown(care.dispose);

    final sockets = <StreamChannelController<String>>[];
    var attempts = 0;
    final kanbanTracer = connection.kanban()!;
    final board = KanbanBoardController(
      repository: KanbanRepository(api),
      connect: ({required since, board}) async {
        // The first attempt fails, so the reconnect is logged.
        if (attempts++ == 0) throw const SocketException('refused');
        final socket = StreamChannelController<String>();
        sockets.add(socket);
        return kanbanTracer.connecting(
          () async => socket.foreign,
          route: '/api/plugins/kanban/events',
        );
      },
      debounce: Duration.zero,
      reconnectDelay: (_) => Duration.zero,
      log: connection.events,
    );
    addTearDown(board.dispose);

    await sinks.capturingPrint(() async {
      await care.refresh();
      await board.start();
      for (var i = 0; i < 50 && sockets.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(sockets, isNotEmpty);
      kanbanTracer.event('status');
      sockets.single.local.sink.add(
        jsonEncode({
          'cursor': 1,
          'events': [
            {'id': 1, 'task_id': 't1', 'kind': 'status'},
          ],
        }),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });

    expect(sinks.tracer.all, isNotEmpty);
    expectClean();
  });
}

/// Sends every connection to [dashboard], whatever host it names.
class _RedirectTo extends HttpOverrides {
  _RedirectTo(this.dashboard);

  final LocalDashboard dashboard;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    final port = Uri.parse(dashboard.url).port;
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (uri, proxyHost, proxyPort) =>
        Socket.startConnect(InternetAddress.loopbackIPv4, port);
    return client;
  }
}
