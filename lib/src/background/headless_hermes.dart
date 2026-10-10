/// Runs Hermes work with no screen, for background refresh, App Intents and
/// notification actions.
///
/// It reads the same saved server and stored session the app does, but never
/// signs anybody out: whatever goes wrong, the stored session stays as it was
/// and the app in front decides what to do about it.
library;

import 'dart:async';

import 'package:dio/dio.dart';
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
  });

  final TokenStore? tokenStore;
  final SharedPreferencesAsync? prefs;

  /// The server given at build time; empty for none.
  final String? devServerUrl;
  final ConnectionTelemetryFactory? telemetry;
  final HttpClientAdapter? adapter;
  final Future<StreamChannel<String>> Function(Uri uri)? openSocket;
}

/// Runs [body] against the saved server with the stored session, within
/// [timeout] for connecting and work together. [task] names the run in
/// telemetry. Nothing is thrown: a failing [body] ends as
/// [HeadlessUnreachable], since a background callback that throws is reported
/// to the system as a failure.
Future<HeadlessOutcome<T>> withHeadlessHermes<T>(
  Future<T> Function(HeadlessHermes hermes) body, {
  required String task,
  Duration timeout = const Duration(seconds: 25),
  HeadlessDeps? deps,
}) async {
  final wiring = deps ?? const HeadlessDeps();
  final factory = wiring.telemetry ?? backgroundTelemetry;
  final span = _quiet(
    () =>
        factory(const {}).tracer
            ?.startSpan('background.task', attributes: {'task': task}),
  );
  final run = _Run<T>(wiring, factory);
  var ended = _Ended<T>('failed', const HeadlessUnreachable());
  try {
    ended = await run
        .execute(body)
        .timeout(
          timeout,
          onTimeout: () => _Ended('timeout', const HeadlessUnreachable()),
        );
  } on Object catch (error) {
    ended = _Ended(
      'failed',
      const HeadlessUnreachable(),
      errorType: error.runtimeType.toString(),
    );
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
  /// they cannot be read.
  Future<List<String?>> profiles() async {
    try {
      final names = [
        for (final profile in await repositories.profiles.list()) profile.name,
      ];
      return names.isEmpty ? const [null] : names;
    } on Object {
      return const [null];
    }
  }

  /// A gateway transport on a socket of its own, closed when the run ends.
  HermesGatewayTransport transport() => _openTransport(_connection);
}

class _Ended<T> {
  const _Ended(this.outcome, this.result, {this.errorType});

  /// The `outcome` the run's span records.
  final String outcome;
  final HeadlessOutcome<T> result;
  final String? errorType;
}

class _Run<T> {
  _Run(this._deps, this._telemetry);

  final HeadlessDeps _deps;
  final ConnectionTelemetryFactory _telemetry;
  final _transports = <HermesGatewayTransport>[];
  var _closed = false;

  Map<String, Object> serverAttributes = const {};

  Future<_Ended<T>> execute(Future<T> Function(HeadlessHermes) body) async {
    final opened = await _Connection.open(_deps, _telemetry);
    serverAttributes = opened.serverAttributes;
    final connection = opened.connection;
    if (connection == null) return _refused(opened.refusal!);
    final hermes = HeadlessHermes._(connection, _openTransport);
    final bodyEnd = () async {
      try {
        return _Ended<T>('ok', HeadlessDone(await body(hermes)));
      } on Object catch (error) {
        return _Ended<T>(
          'failed',
          const HeadlessUnreachable(),
          errorType: error.runtimeType.toString(),
        );
      }
    }();
    final authEnd = connection.auth?.stopped.future.then(
      (stop) => switch (stop) {
        _Stop.signedOut => _Ended<T>('auth_failed', const HeadlessSignedOut()),
        _Stop.unreachable => _Ended<T>(
          'auth_failed',
          const HeadlessUnreachable(),
        ),
      },
    );
    // The auth ends first when it is why the body failed, so it names the
    // outcome.
    return Future.any([bodyEnd, ?authEnd]);
  }

  _Ended<T> _refused(String outcome) => _Ended(outcome, switch (outcome) {
    'no_server' || 'no_session' => const HeadlessSignedOut(),
    'locked' => const HeadlessLocked(),
    _ => const HeadlessUnreachable(),
  });

  HermesGatewayTransport _openTransport(_Connection connection) {
    if (_closed) throw StateError('The headless run has ended');
    final telemetry = connection.repositories.telemetry.gateway();
    final transport = HermesGatewayTransport(
      connect: hermesGatewayConnect(
        baseUrl: connection.baseUrl,
        authRequired: connection.authRequired,
        api: connection.repositories.api,
        telemetry: telemetry,
        open: _deps.openSocket ?? openWebSocket,
      ),
      telemetry: telemetry,
      events: connection.repositories.telemetry.events,
    );
    _transports.add(transport);
    return transport;
  }

  Future<void> close() async {
    _closed = true;
    await Future.wait([
      for (final transport in _transports)
        transport.close().catchError((Object _) {}),
    ]);
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
    HeadlessDeps deps,
    ConnectionTelemetryFactory telemetryFor,
  ) async {
    final configured = deps.devServerUrl ?? kDevServerUrlDefine;
    final raw = configured.isNotEmpty
        ? configured
        : await (deps.prefs ?? SharedPreferencesAsync()).getString(
            kSavedServerUrlKey,
          );
    final typed = raw == null ? null : normalizeServerUrl(raw);
    if (typed == null) return const _Opened.refused('no_server');

    final unconnected = telemetryFor(const {});
    final store = deps.tokenStore ?? TokenStore(events: unconnected.events);
    // Read before any request: a locked keychain ends the run on its own.
    final stored = await store.readState(repair: false);
    if (stored is SessionUnreadable) return const _Opened.refused('locked');

    Dio dio(
      String baseUrl,
      ConnectionTelemetry telemetry, {
      Duration receive = const Duration(seconds: 12),
    }) {
      final client = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: receive,
        ),
      );
      if (deps.adapter case final adapter?) client.httpClientAdapter = adapter;
      return client
        ..interceptors.addAll([
          RequestTimeoutInterceptor(),
          ?telemetry.interceptor,
        ]);
    }

    final HermesStatus status;
    var normalized = typed;
    try {
      final probe = await HermesApiClient(
        dio(typed, unconnected, receive: const Duration(seconds: 8)),
      ).probeStatus();
      status = probe.status;
      normalized = probe.redirectedTo ?? typed;
    } on Object {
      return const _Opened.refused('unreachable');
    }
    final attributes = status.serverAttributes;
    final telemetry = telemetryFor(attributes);

    HermesSession? held;
    if (status.authRequired) {
      final session = switch (stored) {
        SessionFound(:final session) => session,
        _ => null,
      };
      // A session another dashboard minted is no use here (see
      // AuthController.connect for why the typed address counts too).
      final minter = session?.serverUrl;
      if (session == null ||
          (minter != null && minter != normalized && minter != typed)) {
        return _Opened.refused('no_session', attributes);
      }
      held = session.boundTo(normalized);
    }

    final authed = dio(normalized, telemetry);
    _HeadlessAuth? auth;
    if (held != null) {
      auth = _HeadlessAuth(
        baseUrl: normalized,
        session: held,
        store: store,
        tokenDio: dio(normalized, telemetry),
        events: telemetry.events,
      );
      authed.interceptors.add(auth.interceptor(authed));
    } else {
      final page = PageToken(HermesApiClient(dio(normalized, telemetry)));
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
  });

  final String baseUrl;
  final TokenStore store;
  final Dio tokenDio;
  final void Function(String name, [Map<String, Object> attributes]) events;

  HermesSession session;

  /// Completes with why the run cannot go on, once the session is of no use.
  final stopped = Completer<_Stop>();

  var _refreshed = false;
  Future<HermesSession?>? _inFlight;

  Interceptor interceptor(Dio dio) => InterceptorsWrapper(
    onRequest: (options, handler) async {
      if (session.needsRefresh() && session.refreshToken.isNotEmpty) {
        await _renew(session);
      }
      if (stopped.isCompleted) {
        return handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.cancel,
            error: 'The headless run has ended',
          ),
        );
      }
      options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      handler.next(options);
    },
    onError: (error, handler) async {
      final options = error.requestOptions;
      if (error.response?.statusCode != 401 ||
          options.extra['hermes_retried'] == true ||
          stopped.isCompleted ||
          session.refreshToken.isEmpty) {
        return handler.next(error);
      }
      // A request sent with a token another request has since rotated away
      // only needs the new one.
      final sentStale =
          options.headers['Authorization'] != 'Bearer ${session.accessToken}';
      final current = sentStale ? session : await _renew(session);
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

  Future<HermesSession?> _renew(HermesSession rejected) =>
      _inFlight ??= _renewOnce(rejected).whenComplete(() => _inFlight = null);

  Future<HermesSession?> _renewOnce(HermesSession held) async {
    final adopted = _newerStored(held, await _stored());
    if (adopted != null) return session = adopted;
    if (_refreshed) return null;
    _refreshed = true;

    final HermesSession refreshed;
    try {
      refreshed = (await refreshNativeSession(
        baseUrl,
        held,
        httpClient: tokenDio,
      )).rotatedFrom(held);
    } on NativeLoginException catch (e) {
      if (!e.rejected) return _stop(_Stop.unreachable);
      return _rejected(held);
    } on Object {
      return _stop(_Stop.unreachable);
    }

    session = refreshed;
    final current = await _stored();
    if (current?.refreshToken == held.refreshToken) {
      try {
        await store.write(refreshed);
      } on Object {
        // The app refreshes again from the pair it holds.
      }
    }
    return refreshed;
  }

  /// The server refused [held]'s refresh token. Storage is left as it is:
  /// the app in front may have rotated the pair since, or will find out for
  /// itself.
  Future<HermesSession?> _rejected(HermesSession held) async {
    final current = await _stored();
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

  Future<HermesSession?> _stored() async {
    try {
      return switch (await store.readState(repair: false)) {
        SessionFound(:final session) => session,
        _ => null,
      };
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
