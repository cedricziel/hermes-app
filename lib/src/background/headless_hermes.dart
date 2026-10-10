/// Runs Hermes work with no screen, for background refresh, App Intents and
/// notification actions.
///
/// It reads the same saved server and stored session the app does, but never
/// signs anybody out: whatever goes wrong, the stored session stays as it was
/// and the app in front decides what to do about it.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_otel/flutter_otel.dart' show AppEventLogger;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_channel/stream_channel.dart';

import '../api/hermes_api_client.dart';
import '../api/hermes_repositories.dart';
import '../api/request_timeout.dart';
import '../auth/auth_controller.dart';
import '../auth/native_login_flow.dart';
import '../auth/page_token.dart';
import '../auth/token_store.dart';
import '../chat/gateway/gateway_connection.dart';
import '../chat/gateway/hermes_gateway_transport.dart';
import '../models/hermes_session.dart';
import '../models/hermes_status.dart';
import '../telemetry/telemetry.dart';
import 'entry_points.dart';

/// How a headless run ended. Callers switch over it, so a new case breaks
/// their build rather than going unhandled.
sealed class HeadlessOutcome<T> {
  const HeadlessOutcome();
}

/// The work ran and produced [value].
final class HeadlessDone<T> extends HeadlessOutcome<T> {
  const HeadlessDone(this.value);

  final T value;
}

/// Nobody is signed in: no server saved, no session stored, or the server
/// rejected the refresh token. Stored state is untouched, even in the last
/// case.
final class HeadlessSignedOut<T> extends HeadlessOutcome<T> {
  const HeadlessSignedOut();
}

/// Secure storage cannot be read yet (on iOS: before the first unlock after
/// the device started).
final class HeadlessLocked<T> extends HeadlessOutcome<T> {
  const HeadlessLocked();
}

/// Hermes did not answer in time: the server was unreachable, the refresh
/// failed for another reason, the time budget ran out or the work threw.
final class HeadlessUnreachable<T> extends HeadlessOutcome<T> {
  const HeadlessUnreachable();
}

/// What a headless run is wired to. A run uses the device's own parts unless
/// told otherwise, which only tests do.
class HeadlessDeps {
  const HeadlessDeps({
    this.tokenStore,
    this.prefs,
    this.devServerUrl,
    this.telemetry,
    this.adapter,
    this.openSocket,
    this.minRefreshBudget = const Duration(seconds: 4),
    this.rejectionRecheck = const Duration(seconds: 1),
    this.closeGrace = const Duration(seconds: 3),
  });

  final TokenStore? tokenStore;
  final SharedPreferencesAsync? prefs;

  /// The server given at build time; empty for none.
  final String? devServerUrl;
  final ConnectionTelemetryFactory? telemetry;
  final HttpClientAdapter? adapter;
  final Future<StreamChannel<String>> Function(Uri uri)? openSocket;

  /// The least time a run must have left for a refresh to start: a refresh
  /// that the budget would cut off may rotate the refresh token without the
  /// new pair ever being stored.
  final Duration minRefreshBudget;

  /// How long a rejected refresh waits for another isolate's write to land in
  /// storage before the run gives up on the session.
  final Duration rejectionRecheck;

  /// How long ending a run waits for a refresh in flight to store its pair,
  /// and for a body to settle after the session failed.
  final Duration closeGrace;
}

/// Runs [body] against the saved server with the stored session, within
/// [timeout] for connecting and work together. [task] names the run in
/// telemetry. Nothing is thrown: a failing [body] ends as
/// [HeadlessUnreachable], since a background callback that throws is reported
/// to the system as a failure.
///
/// A refresh that is under way when the run ends is waited for (up to
/// [HeadlessDeps.closeGrace]) so the pair it rotated is stored before the
/// caller lets the operating system suspend the app. After the run ends,
/// nothing the body still does reaches the server.
Future<HeadlessOutcome<T>> withHeadlessHermes<T>(
  Future<T> Function(HeadlessHermes hermes) body, {
  required String task,
  Duration timeout = const Duration(seconds: 25),
  HeadlessDeps? deps,
}) async {
  final wiring = deps ?? const HeadlessDeps();
  final run = _Run(
    wiring,
    wiring.telemetry ?? backgroundTelemetry,
    DateTime.now().add(timeout),
  );
  final span = _quiet(
    () => run
        .telemetry(const {})
        .tracer
        ?.startSpan('background.task', attributes: {'task': task}),
  );
  var ended = _Ended<T>('failed', const HeadlessUnreachable());
  try {
    ended = await run
        .execute(body)
        .timeout(
          timeout,
          onTimeout: () => _Ended('timeout', const HeadlessUnreachable()),
        );
  } on Object catch (error) {
    ended = _Ended.failed(error);
  } finally {
    await run.close();
    if (span != null) {
      _quiet(() {
        span
          ..setAttributes(run.serverAttributes)
          ..setAttribute('outcome', ended.outcome)
          ..setAttribute('error.type', ended.errorType)
          ..end();
      });
    }
  }
  return ended.result;
}

/// The Hermes connection a headless run works with.
class HeadlessHermes {
  HeadlessHermes._(this._connection, this._openTransport);

  final _Connection _connection;
  final HermesGatewayTransport Function(_Connection connection) _openTransport;

  /// The repositories the app's screens use.
  HermesRepositories get repositories => _connection.repositories;

  /// The server's profile names; `[null]`, the server's default profile, when
  /// they cannot be read. Throws once the session has failed, so that the run
  /// ends as signed out rather than with a default profile.
  Future<List<String?>> profiles() async {
    try {
      final names = [
        for (final profile in await repositories.profiles.list()) profile.name,
      ];
      return names.isEmpty ? const [null] : names;
    } on Object {
      if (_connection.auth?.stopped.isCompleted ?? false) rethrow;
      return const [null];
    }
  }

  /// A gateway transport on a socket of its own, closed when the run ends.
  HermesGatewayTransport transport() => _openTransport(_connection);
}

class _Ended<T> {
  const _Ended(this.outcome, this.result, {this.errorType});

  _Ended.failed(Object error)
    : outcome = 'failed',
      result = const HeadlessUnreachable(),
      errorType = error.runtimeType.toString();

  /// The `outcome` the run's span records.
  final String outcome;
  final HeadlessOutcome<T> result;
  final String? errorType;
}

class _Run {
  _Run(this._deps, ConnectionTelemetryFactory telemetry, this._deadline)
    : telemetry = ((attributes) =>
          _quiet(() => telemetry(attributes)) ?? const ConnectionTelemetry());

  final HeadlessDeps _deps;

  /// The factory for this run's connections; a throwing one yields none.
  final ConnectionTelemetryFactory telemetry;
  final DateTime _deadline;
  final _transports = <HermesGatewayTransport>[];
  final _clients = <Dio>[];
  _HeadlessAuth? _auth;
  var _closed = false;

  Map<String, Object> serverAttributes = const {};

  /// A client for [baseUrl] that [close] shuts down.
  Dio client(
    String baseUrl,
    ConnectionTelemetry connection, {
    Duration receive = const Duration(seconds: 12),
  }) {
    if (_closed) throw StateError('The headless run has ended');
    final client = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: receive,
      ),
    );
    if (_deps.adapter case final adapter?) client.httpClientAdapter = adapter;
    client.interceptors.addAll([
      RequestTimeoutInterceptor(),
      ?connection.interceptor,
    ]);
    _clients.add(client);
    return client;
  }

  Future<_Ended<T>> execute<T>(Future<T> Function(HeadlessHermes) body) async {
    final opened = await _Connection.open(this, _deps, _deadline);
    serverAttributes = opened.serverAttributes;
    final connection = opened.connection;
    if (connection == null) return _refused<T>(opened.refusal!);
    _auth = connection.auth;
    final hermes = HeadlessHermes._(connection, _openTransport);
    final bodyEnd = () async {
      try {
        return _Ended<T>('ok', HeadlessDone(await body(hermes)));
      } on Object catch (error) {
        return _Ended<T>.failed(error);
      }
    }();
    final stop = connection.auth?.stopped.future;
    if (stop == null) return bodyEnd;
    final first = await Future.any<_Ended<T>?>([
      bodyEnd,
      stop.then((_) => null),
    ]);
    if (first != null) return first;
    // The session failed under the body. It is why a body that then fails
    // did so, but one that got through anyway keeps its result.
    final authEnded = _Ended<T>('auth_failed', switch (await stop) {
      _Stop.signedOut => const HeadlessSignedOut(),
      _Stop.unreachable => const HeadlessUnreachable(),
    });
    final settled = await bodyEnd.timeout(
      _deps.closeGrace,
      onTimeout: () => authEnded,
    );
    return settled.outcome == 'ok' ? settled : authEnded;
  }

  _Ended<T> _refused<T>(String outcome) => _Ended(outcome, switch (outcome) {
    'no_server' || 'no_session' => const HeadlessSignedOut(),
    'locked' => const HeadlessLocked(),
    _ => const HeadlessUnreachable(),
  });

  HermesGatewayTransport _openTransport(_Connection connection) {
    if (_closed) throw StateError('The headless run has ended');
    final connectionTelemetry = connection.repositories.telemetry;
    final tracer = _quiet(connectionTelemetry.gateway);
    final transport = HermesGatewayTransport(
      connect: hermesGatewayConnect(
        baseUrl: connection.baseUrl,
        authRequired: connection.authRequired,
        api: connection.repositories.api,
        telemetry: tracer,
        open: _deps.openSocket ?? openWebSocket,
      ),
      telemetry: tracer,
      events: _quietEvents(connectionTelemetry.events),
    );
    _transports.add(transport);
    return transport;
  }

  /// Ends the run: no new refresh or request starts, a refresh in flight gets
  /// to store its pair, then every socket and client is closed so that
  /// nothing the body still does reaches the server.
  Future<void> close() async {
    _closed = true;
    await _auth?.shutdown(_deps.closeGrace);
    await Future.wait([
      for (final transport in _transports)
        transport.close().catchError((Object _) {}),
    ]);
    for (final client in _clients) {
      client.close(force: true);
    }
  }
}

class _Opened {
  const _Opened.refused(String this.refusal, [this.serverAttributes = const {}])
    : connection = null;
  const _Opened.connected(_Connection this.connection, this.serverAttributes)
    : refusal = null;

  final _Connection? connection;
  final String? refusal;
  final Map<String, Object> serverAttributes;
}

class _Connection {
  _Connection({
    required this.baseUrl,
    required this.authRequired,
    required this.repositories,
    this.auth,
  });

  /// The server's answer to `/api/status`, the saved session, and everything
  /// built from them; or why there is none.
  static Future<_Opened> open(
    _Run run,
    HeadlessDeps deps,
    DateTime deadline,
  ) async {
    final configured = deps.devServerUrl ?? kDevServerUrlDefine;
    final raw = configured.isNotEmpty
        ? configured
        : await (deps.prefs ?? SharedPreferencesAsync()).getString(
            kSavedServerUrlKey,
          );
    final typed = raw == null ? null : normalizeServerUrl(raw);
    if (typed == null) return const _Opened.refused('no_server');

    final unconnected = run.telemetry(const {});
    final store = deps.tokenStore ?? TokenStore(events: unconnected.events);
    // Read before any request: a locked keychain ends the run on its own.
    final stored = await store.readState(repair: false);
    if (stored is SessionUnreadable) {
      return _Opened.refused(stored.locked ? 'locked' : 'unreachable');
    }

    final HermesStatus status;
    var normalized = typed;
    try {
      final probe = await HermesApiClient(
        run.client(typed, unconnected, receive: const Duration(seconds: 8)),
      ).probeStatus();
      status = probe.status;
      normalized = probe.redirectedTo ?? typed;
    } on Object {
      return const _Opened.refused('unreachable');
    }
    final attributes = status.serverAttributes;
    final telemetry = run.telemetry(attributes);

    HermesSession? held;
    if (status.authRequired) {
      final session = stored.session;
      // A session another dashboard minted is no use here (see
      // AuthController.connect for why the typed address counts too).
      final minter = session?.serverUrl;
      if (session == null ||
          (minter != null && minter != normalized && minter != typed)) {
        return _Opened.refused('no_session', attributes);
      }
      held = session.boundTo(normalized);
    }

    final authed = run.client(normalized, telemetry);
    _HeadlessAuth? auth;
    if (held != null) {
      auth = _HeadlessAuth(
        baseUrl: normalized,
        session: held,
        store: store,
        tokenDio: run.client(normalized, telemetry),
        events: _quietEvents(telemetry.events),
        deadline: deadline,
        minRefreshBudget: deps.minRefreshBudget,
        rejectionRecheck: deps.rejectionRecheck,
      );
      authed.interceptors.add(auth.interceptor(authed));
    } else {
      final page = PageToken(
        HermesApiClient(run.client(normalized, telemetry)),
      );
      authed.interceptors.add(pageTokenInterceptor(authed, page));
    }
    return _Opened.connected(
      _Connection(
        baseUrl: normalized,
        authRequired: status.authRequired,
        repositories: HermesRepositories(
          HermesApiClient(authed),
          telemetry: telemetry,
        ),
        auth: auth,
      ),
      attributes,
    );
  }

  final String baseUrl;
  final bool authRequired;
  final HermesRepositories repositories;
  final _HeadlessAuth? auth;
}

/// Why the session ended a run.
enum _Stop { signedOut, unreachable }

/// The longest one attempt at a refresh waits, as in the app.
const _maxRefreshAttempt = Duration(seconds: 12);

/// Attaches the stored session's token and refreshes it at most once per run,
/// writing the new pair back only when storage still holds the pair that was
/// spent. It never clears or overwrites a session otherwise: the foreground
/// app may rotate the same tokens at about the same time, and signing out is
/// its decision alone.
class _HeadlessAuth {
  _HeadlessAuth({
    required this.baseUrl,
    required this.session,
    required this.store,
    required this.tokenDio,
    required this.events,
    required this.deadline,
    required this.minRefreshBudget,
    required this.rejectionRecheck,
  });

  final String baseUrl;
  final TokenStore store;
  final Dio tokenDio;
  final AppEventLogger events;
  final DateTime deadline;
  final Duration minRefreshBudget;
  final Duration rejectionRecheck;

  HermesSession session;

  /// Completes with why the run cannot go on, once the session is of no use.
  final stopped = Completer<_Stop>();

  var _refreshed = false;
  var _proactiveTried = false;
  var _closing = false;
  Future<HermesSession?>? _inFlight;

  /// Whether the run is over, so nothing may start.
  bool get _over => _closing || stopped.isCompleted;

  /// Stops new refreshes and requests, then waits up to [grace] for a refresh
  /// in flight, which must store the pair it rotated.
  Future<void> shutdown(Duration grace) async {
    _closing = true;
    final running = _inFlight;
    if (running == null) return;
    try {
      await running.timeout(grace);
    } on Object {
      // Gave up waiting; the refresh may still finish without being stored.
    }
  }

  Interceptor interceptor(Dio dio) => InterceptorsWrapper(
    onRequest: (options, handler) async {
      DioException? refusal;
      try {
        await _ensureFresh();
        if (_over) {
          refusal = DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: 'The headless run has ended',
          );
        } else {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
      } on Object catch (error) {
        refusal = DioException(requestOptions: options, error: error);
      }
      if (refusal != null) return handler.reject(refusal);
      handler.next(options);
    },
    onError: (error, handler) async {
      final options = error.requestOptions;
      if (error.response?.statusCode != 401 ||
          options.extra['hermes_retried'] == true ||
          _over ||
          session.refreshToken.isEmpty) {
        return handler.next(error);
      }
      HermesSession? current;
      try {
        // A request sent with a token another request has since rotated away
        // only needs the new one.
        final sentStale =
            options.headers['Authorization'] != 'Bearer ${session.accessToken}';
        current = sentStale ? session : await _renew(session);
      } on Object {
        current = null;
      }
      if (current == null) return handler.next(error);
      options
        ..headers['Authorization'] = 'Bearer ${current.accessToken}'
        ..extra['hermes_retried'] = true;
      try {
        handler.resolve(await dio.fetch<dynamic>(options));
      } on DioException catch (e) {
        handler.next(e);
      }
    },
  );

  /// Refreshes ahead of a request when the access token is about to expire,
  /// once per run: a pair that is still expiring after that (a skewed clock)
  /// would otherwise read the keychain for every request.
  Future<void> _ensureFresh() async {
    if (_inFlight case final running?) {
      await running;
      return;
    }
    if (_proactiveTried ||
        !session.needsRefresh() ||
        session.refreshToken.isEmpty) {
      return;
    }
    _proactiveTried = true;
    await _renew(session);
  }

  Future<HermesSession?> _renew(HermesSession rejected) =>
      _inFlight ??= _renewOnce(rejected)
          .then<HermesSession?>((s) => s, onError: (Object _) => null)
          .whenComplete(() => _inFlight = null);

  Future<HermesSession?> _renewOnce(HermesSession held) async {
    final adopted = _newerStored(held, await _stored());
    if (adopted != null) return session = adopted;
    if (_refreshed || _over) return null;
    final remaining = deadline.difference(DateTime.now());
    // Spending the refresh token needs time to store the new one.
    if (remaining < minRefreshBudget) return _stop(_Stop.unreachable);
    _refreshed = true;

    final HermesSession refreshed;
    try {
      final half = remaining ~/ 2;
      refreshed = (await refreshNativeSession(
        baseUrl,
        held,
        httpClient: tokenDio,
        attemptTimeout: half < _maxRefreshAttempt ? half : _maxRefreshAttempt,
      )).rotatedFrom(held);
    } on NativeLoginException catch (e) {
      if (!e.rejected) return _stop(_Stop.unreachable);
      return _rejected(held);
    } on Object {
      return _stop(_Stop.unreachable);
    }

    session = refreshed;
    await _writeBack(held, refreshed);
    return refreshed;
  }

  /// Stores [refreshed] unless storage no longer holds the pair [spent]
  /// came from: the app may have rotated it or the user signed out since.
  /// A storage that cannot be read is written anyway, since [spent] is gone
  /// whatever it holds.
  Future<void> _writeBack(HermesSession spent, HermesSession refreshed) async {
    final current = await _storedState();
    if (current is SessionEmpty) return;
    if (current is SessionFound &&
        current.session.refreshToken != spent.refreshToken) {
      return;
    }
    try {
      await store.write(refreshed);
    } on Object catch (error) {
      events('auth.session.store_failed', {
        'error.type': error.runtimeType.toString(),
      });
    }
  }

  /// The server refused [held]'s refresh token. The app in front may have
  /// rotated the pair, and its write may still be under way, so storage is
  /// read again a moment later, as `AuthController` does. Storage is never
  /// cleared: the app finds out for itself.
  Future<HermesSession?> _rejected(HermesSession held) async {
    HermesSession? current;
    for (final wait in [Duration.zero, rejectionRecheck]) {
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      current = await _stored();
      final adopted = _newerStored(held, current);
      if (adopted != null) return session = adopted;
    }
    if (current != null && current.refreshToken != held.refreshToken) {
      events('background.refresh_conflict');
      return _stop(_Stop.unreachable);
    }
    return _stop(_Stop.signedOut);
  }

  HermesSession? _newerStored(HermesSession held, HermesSession? stored) =>
      stored != null && stored.sameOwner(held) && stored.isNewerThan(held)
      ? stored
      : null;

  Future<HermesSession?> _stored() async => (await _storedState())?.session;

  Future<SessionRead?> _storedState() async {
    try {
      return await store.readState(repair: false);
    } on Object {
      return null;
    }
  }

  HermesSession? _stop(_Stop reason) {
    if (!stopped.isCompleted) stopped.complete(reason);
    return null;
  }
}

/// Runs [action] and returns its result, or null when it throws: telemetry
/// must never break background work.
R? _quiet<R>(R Function() action) {
  try {
    return action();
  } on Object {
    return null;
  }
}

AppEventLogger _quietEvents(AppEventLogger events) =>
    (name, [attributes = const {}]) => _quiet(() => events(name, attributes));
