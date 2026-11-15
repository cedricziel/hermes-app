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
import 'package:hermes_app/src/kanban/kanban_repository.dart';
import 'package:hermes_app/src/models/hermes_session.dart';
import 'package:hermes_app/src/server_care/server_care_controller.dart';
import 'package:hermes_app/src/server_care/server_care_repository.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/telemetry/telemetry.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

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
/// spans and `debugPrint` carry fixed names, counts, flags and outcomes, never
/// what the user typed or named.
///
/// Every sink is captured while the widest flows the test support allows run
/// on data made of sentinels. A sentinel in any captured record is a leak.
/// When a feature adds telemetry, add its flow here.
///
/// Exempt by design: the `hermes.*` server attributes (version, install id)
/// and the crash reporter's error payload. Crash breadcrumbs are the trail
/// captured here, so they are checked.

const _msg = 'SENTINEL_MSG_7f3a';
const _title = 'SENTINEL_TITLE_7f3a';
const _profile = 'SENTINEL_PROFILE_7f3a';
const _host = 'sentinel-host-7f3a.example';
const _token = 'SENTINEL_TOKEN_7f3a';
const _password = 'SENTINEL_PW_7f3a';
const _session = 'sess-sentinel-7f3a';
const _user = 'SENTINEL_USER_7f3a';

const _sentinels = [
  _msg,
  _title,
  _profile,
  _host,
  _token,
  _password,
  _session,
  _user,
];

/// Known leaks of main, as `sink|sentinel`, each with a TODO to fix it. The
/// list only shrinks.
const _knownLeaks = <String>{};

typedef _Record = ({String sink, String text});

/// Everything the app's telemetry and logging produced during one test.
class _Sinks {
  final records = <_Record>[];
  final tracer = _CapturingTracer();
  late final trail = _CapturingTrail(this);
  late final logger = _CapturingLogger(this);

  void add(String sink, String text) => records.add((sink: sink, text: text));

  /// A connection built like `Telemetry.forConnection` builds one, with every
  /// sink captured.
  ConnectionTelemetry connection(Map<String, Object> serverAttributes) =>
      ConnectionTelemetry(
        interceptor: httpInterceptor(
          logger,
          tracer,
          serverAttributes: serverAttributes,
        ),
        tracer: tracer,
        serverAttributes: serverAttributes,
        events: trail.asAppEventLogger(
          (name, [attributes = const {}]) =>
              logger.emit(LogRecord(body: name, attributes: attributes)),
        ),
      );

  Breadcrumbs get breadcrumbs => Breadcrumbs.of(trail);

  /// Every record that carries a sentinel, one line each.
  List<String> leaks() {
    final found = <String>[];
    void check(String sink, String text) {
      final haystack = text.toLowerCase();
      for (final sentinel in _sentinels) {
        if (!haystack.contains(sentinel.toLowerCase())) continue;
        if (_knownLeaks.contains('$sink|$sentinel')) continue;
        found.add('$sink | $sentinel | $text');
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
    // The server's own description, exempt by design.
    if (!e.key.startsWith('hermes.')) '${e.key}=${e.value}',
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

const _serverAttributes = <String, Object>{
  'hermes.version': '0.22.2',
  'hermes.install_id': 'inst_7f3a',
};

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

    // The sentinel address resolves to the local dashboard.
    await HttpOverrides.runWithHttpOverrides(() async {
      await auth.connect('http://$_host:80', allowCleartext: true);
      expect(auth.state, HermesConnectionState.needsLogin);
      await auth.signInWithProvider(auth.providers.single);
      expect(auth.state, HermesConnectionState.ready);
      await auth.signOut();
      await auth.changeServer();
    }, _RedirectTo(dashboard));

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
    final transport = FakeChatTransport();

    await pumpChatScreen(
      tester,
      server: server,
      withProfiles: true,
      transport: transport,
      providers: [
        Provider<Breadcrumbs>.value(value: sinks.breadcrumbs),
        Provider<HermesRepositories>.value(
          value: HermesRepositories(
            _client(server, connection),
            telemetry: connection,
          ),
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

    expect(sinks.records, isNotEmpty);
    expectClean();
  });

  test('gateway: prompt with the message, reply that echoes it', () async {
    final gateway = FakeGateway()
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

    final events = await transport
        .send(text: _msg, threadId: _session, profile: _profile)
        .toList();
    expect(events.whereType<ReplyCompleted>(), isNotEmpty);

    expect(sinks.tracer.all, isNotEmpty);
    expectClean();
  });

  test('server care and kanban', () async {
    final server = FakeHermesServer()
      ..on('GET', '/api/status', statusHealthy())
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
    await care.refresh();
    await KanbanRepository(api).loadBoard();

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
