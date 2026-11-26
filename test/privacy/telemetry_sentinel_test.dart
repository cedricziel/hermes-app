import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart'
    show Dio, HttpClientAdapter, RequestOptions, ResponseBody;
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_otel/flutter_otel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_api_client.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/auth/auth_controller.dart';
import 'package:hermes_app/src/chat/chat_controller.dart';
import 'package:hermes_app/src/chat/chat_transport.dart';
import 'package:hermes_app/src/chat/gateway/gateway_rpc_client.dart';
import 'package:hermes_app/src/notifications/attention_notifier.dart';
import 'package:hermes_app/src/chat/gateway/hermes_gateway_transport.dart';
import 'package:hermes_app/src/chat/tool_image_loader.dart';
import 'package:hermes_app/src/chat/widgets/tool_call_card.dart';
import 'package:hermes_app/src/chat/widgets/tool_image_tile.dart';
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
import '../support/image_tool_fixtures.dart';
import '../support/memory_token_store.dart';
import '../support/pump_chat.dart';
import '../support/pump_on_platform.dart';
import '../support/recording_tracer.dart';

/// A [Random] whose draws are fixed, so reconnect backoff is known.
class _FixedRandom implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => max ~/ 2;
}

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

  test('reply loss: socket close, reconnect attempts, reattach', () {
    fakeAsync((async) {
      final gateway = FakeGateway()
        ..stampSeq = true
        ..sendReady = true
        ..createResult = {
          'session_id': _runtimeSession,
          'stored_session_id': _storedSession,
        }
        ..resumeResult = {'session_id': _runtimeSession, 'running': true}
        ..turn = (g, sid) {
          g.event('message.start', sid);
          g.event('message.delta', sid, {'text': 'echo $_msg'});
          g.drop();
        };
      final connection = sinks.connection(_serverAttributes);
      var opened = 0;
      var unreachable = true;
      final transport = HermesGatewayTransport(
        connect: () async {
          // The first socket is the chat's; until the recovery window runs
          // out every later one fails with a message that quotes the server's
          // address. After that the server answers, but never the resume.
          if (opened++ > 0 && unreachable) {
            throw StateError('cannot reach $_host with $_token');
          }
          return gateway.connect();
        },
        telemetry: connection.gateway(),
        events: connection.events,
        random: _FixedRandom(),
      );

      unawaited(
        sinks.capturingPrint(() async {
          final seen = transport
              .send(text: _msg, profile: _profile)
              .listen((_) {}, onError: (Object _) {});
          // The recovery window (60 s of fake time) runs out.
          await Future<void>.delayed(const Duration(seconds: 70));
          unawaited(seen.cancel());
          unreachable = false;
          gateway.silent.add('session.resume');
          // A pick-up of the thread the reply lost.
          final follow = transport
              .followUps(_storedSession, profile: _profile)
              .listen((_) {}, onError: (Object _) {});
          await Future<void>.delayed(const Duration(seconds: 30));
          await follow.cancel();
          await transport.close();
        }),
      );
      async.elapse(const Duration(seconds: 110));
      async.flushMicrotasks();

      for (final name in [
        'gateway.socket_closed',
        'gateway.reconnect_attempt',
        'gateway.reattach',
      ]) {
        expect(
          sinks.records.any((r) => r.text.contains(name)),
          isTrue,
          reason: '$name was captured',
        );
      }
      expectClean();
    });
  });

  testWidgets('reply loss: lifecycle, ended, late event, queue', (
    tester,
  ) async {
    final connection = sinks.connection(_serverAttributes);
    final transport = FakeChatTransport();
    final attention = AttentionNotifier(
      service: null,
      settings: null,
      onOpen: (_) {},
    );
    final chat = ChatController(
      transport: transport,
      attention: attention,
      report: (_) {},
      events: connection.events,
      breadcrumbs: sinks.breadcrumbs,
      reconnectRetry: const Duration(hours: 1),
    );
    addTearDown(() {
      chat.dispose();
      attention.dispose();
    });

    await sinks.capturingPrint(() async {
      await tester.runAsync(() async {
        chat.newThread();
        await chat.submit(_msg, const []);
        transport.sends.single
          ..emit(const ThreadBound(_storedSession))
          ..emit(const PromptAcknowledged(1))
          ..emit(ReplyDelta('echo $_msg'));
        await pumpEventQueue();
        await chat.submit('queued $_msg', const []);
        chat.appLifecycleChanged(AppLifecycleState.paused);
        transport.sends.single.fail(const GatewayReplyLost());
        await pumpEventQueue();
        chat.appLifecycleChanged(AppLifecycleState.resumed);
        chat.checkConnection();
        await pumpEventQueue();
        transport.followUpStreams[_storedSession]!
          ..emit(const ReplyStarted())
          ..emit(ReplyDelta('late $_msg'))
          ..emit(ReplyCompleted('done $_msg'));
        await pumpEventQueue();
        // A reply the server could not confirm, settled as lost.
        chat.newThread();
        await chat.submit('again $_msg', const []);
        transport.sends.last
          ..emit(const ThreadBound(_session))
          ..emit(const PromptAcknowledged(2))
          ..fail(const GatewayReplyUnconfirmed());
        await pumpEventQueue();
      });
    });

    expect(
      sinks.records.any((r) => r.text.contains('chat.reply.ended')),
      isTrue,
    );
    expectClean();
  });

  testWidgets('image load: tap, load, failure, not secure, too large', (
    tester,
  ) async {
    final adapter = _ImageAdapter();
    final loader = ToolImageLoader(
      dio: Dio()..httpClientAdapter = adapter,
      maxBytes: 8,
      breadcrumbs: sinks.breadcrumbs,
    );
    String address(String name) => 'https://$_host/$_titleMarker/$name.png';
    await pumpOnPlatform(
      tester,
      Provider<ToolImageLoader?>.value(
        value: loader,
        child: SingleChildScrollView(
          child: ToolCallCard(
            call: imagesCall(
              imagesAnswer([
                pageImage(address('ok'), alt: _title),
                pageImage(address('fail'), alt: _title),
                pageImage(address('big'), alt: _title),
                pageImage('http://$_host/$_titleMarker/plain.png', alt: _title),
              ]),
            ),
            initiallyOpen: true,
          ),
        ),
      ),
      platform: TargetPlatform.android,
    );

    await sinks.capturingPrint(() async {
      for (final tile in tester.widgetList<ToolImageTile>(
        find.byType(ToolImageTile),
      )) {
        if (tile.onTap == null || tile.state == ToolImageState.insecure) {
          continue;
        }
        tile.onTap!();
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
      }
    });

    expect(adapter.requested, 3);
    expect(
      sinks.records.where((r) => r.text.startsWith('chat.tool_image.loaded')),
      hasLength(3),
    );
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

/// A 1 x 1 PNG: the loader reads the size from the header.
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/'
  'iZk9HQAAAABJRU5ErkJggg==',
);

/// Answers an image by its name: `ok` is small, `fail` is refused, anything
/// else is over the loader's limit.
class _ImageAdapter implements HttpClientAdapter {
  var requested = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requested++;
    final name = options.uri.pathSegments.last;
    return name == 'ok.png'
        ? ResponseBody.fromBytes(_pngBytes, 200)
        : name == 'fail.png'
        ? ResponseBody.fromBytes(const [], 500)
        : ResponseBody.fromBytes(Uint8List(64), 200);
  }

  @override
  void close({bool force = false}) {}
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
