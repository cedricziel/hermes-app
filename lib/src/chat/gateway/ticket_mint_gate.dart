import 'dart:math';

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';

import '../../api/hermes_api_client.dart';

/// The gate gave up on a ticket mint without asking the server: its last
/// answer to one was a refusal or an error, and the wait after it has not
/// run out. Nothing was sent. [refused] says the answer was a 401 or 403;
/// [retryAfter] is what is left of the wait.
class GatewayCredentialBackedOff implements Exception {
  const GatewayCredentialBackedOff({
    required this.refused,
    required this.retryAfter,
  });

  final bool refused;
  final Duration retryAfter;

  @override
  String toString() => refused
      ? 'Minting a ticket is paused after the server refused'
      : 'Minting a ticket is paused after a server error';
}

/// Whether [error] says the server refused the credential: a 401 or 403 to
/// the ticket request (the HTTP client has already refreshed once and tried
/// again, so it is no stale token), or the gate repeating one.
bool isCredentialRefusal(Object? error) => switch (error) {
  GatewayCredentialBackedOff(:final refused) => refused,
  DioException(:final type, :final response) =>
    type == DioExceptionType.badResponse &&
        (response?.statusCode == 401 || response?.statusCode == 403),
  _ => false,
};

/// Whether a reconnect that failed with [error] should stop at once rather
/// than try again: the credential was refused, or the HTTP client cancelled
/// the request because the session ended or protected requests are
/// suspended. Asking again would change nothing until something else does.
bool isCredentialStop(Object? error) =>
    isCredentialRefusal(error) ||
    (error is DioException && error.type == DioExceptionType.cancel);

/// Paces the single-use tickets a client mints for its sockets.
///
/// Every socket the app opens mints a ticket first, and callers that retry
/// (a reconnecting reply, a poll, the Kanban stream) ask again for as long as
/// they live. When the server refuses, each of them would repeat the refused
/// request for hours. After an answer that is an error, the gate fails the
/// next mints locally for a wait that doubles with each failure up to a cap,
/// drawn with jitter between half the bound and the bound, and any success starts over.
///
/// A request that never reached the server (cancelled by the HTTP client, no
/// network) is not counted: the reconnect loops pace those themselves.
class TicketMintGate {
  TicketMintGate({
    Random? random,
    Object? Function()? sessionEpoch,
    bool Function()? sessionEnded,
  }) : _random = random ?? Random(),
       _sessionEpoch = sessionEpoch ?? _noEpoch,
       _sessionEnded = sessionEnded ?? _never;

  static Object? _noEpoch() => 0;
  static bool _never() => false;

  static final _gates = Expando<TicketMintGate>('TicketMintGate');

  /// The gate of [api]: all sockets of one client share the ticket route.
  static TicketMintGate of(HermesApiClient api) =>
      _gates[api] ??= TicketMintGate(
        sessionEpoch: () => api.sessionEpoch,
        sessionEnded: () => api.sessionEnded,
      );

  // The first wait, and the longest, after a 401 or 403 ...
  static const _refusedBase = Duration(seconds: 30);
  static const _refusedCap = Duration(minutes: 10);

  // ... and after any other answer with an error.
  // Short at first: a caller's own one retry after 500 ms (a voice call
  // opening its socket) is not turned away by the first wait.
  static const _errorBase = Duration(milliseconds: 300);
  static const _errorCap = Duration(minutes: 1);

  final Random _random;
  final Object? Function() _sessionEpoch;
  final bool Function() _sessionEnded;
  Object? _epoch = 0;
  var _failures = 0;
  var _refused = false;
  DateTime? _until;

  bool get _cooling => _until?.isAfter(clock.now()) ?? false;

  /// What is left of the wait, or null when none runs.
  Duration? _left() {
    final left = _until?.difference(clock.now());
    return left != null && left > Duration.zero ? left : null;
  }

  /// Drops the wait when the session or token it began under has changed;
  /// returns the current epoch.
  Object? _checkEpoch() {
    final epoch = _sessionEpoch();
    if (epoch != _epoch) {
      _epoch = epoch;
      _failures = 0;
      _until = null;
    }
    return epoch;
  }

  /// Runs [mint] unless the wait after the last failure is still running, in
  /// which case it throws [GatewayCredentialBackedOff] with nothing sent. A
  /// wait never outlives its session: when it ends, or the access token is
  /// renewed, the next mint goes out.
  Future<T> run<T>(Future<T> Function() mint) async {
    _checkEpoch();
    final left = _left();
    if (left != null) {
      throw GatewayCredentialBackedOff(refused: _refused, retryAfter: left);
    }
    try {
      final minted = await mint();
      _failures = 0;
      _until = null;
      return minted;
    } on DioException catch (error) {
      // Answers that land together count as one failure. A failure whose 401
      // ended the session leaves nothing to wait for: the next request is
      // cancelled locally until a new sign-in. Otherwise the wait belongs to
      // the credential in use now, which a refresh during the request may
      // have renewed.
      if (error.response != null && !_cooling && !_sessionEnded()) {
        _epoch = _sessionEpoch();
        _backOff(error);
      }
      rethrow;
    }
  }

  void _backOff(DioException error) {
    final refused = _refused = isCredentialRefusal(error);
    final base = refused ? _refusedBase : _errorBase;
    final cap = refused ? _refusedCap : _errorCap;
    final bound = min(
      cap.inMicroseconds.toDouble(),
      base.inMicroseconds * pow(2, _failures++).toDouble(),
    );
    // Half the bound at least: a draw near zero would let a refused request
    // straight through again, which is what the gate is there to stop.
    final wait = bound * (0.5 + _random.nextDouble() / 2);
    _until = clock.now().add(Duration(microseconds: wait.floor()));
  }
}
