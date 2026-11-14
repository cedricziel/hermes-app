// Named parameters cannot be private initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_otel/flutter_otel.dart' show Span;

import '../core/safe_notifier.dart';
import '../telemetry/breadcrumbs.dart';
import '../telemetry/telemetry.dart';
import 'care_result.dart';
import 'server_care_controller.dart';
import 'server_care_repository.dart';
import 'server_status.dart';

enum GatewayAction { restart, start }

enum GatewayPhase { idle, starting, waiting, returning, done, failed, slow }

/// Why a run ended without the gateway running.
enum GatewayFailure { refused, exited, unreachable }

/// Restarts or starts the messaging gateway and follows it until it is back.
///
/// `idle -> starting -> waiting (the child runs) -> returning (the gateway
/// is read until it runs) -> done`, or `failed`, or `slow` when it is not
/// back in time. The POST is sent once per [run]; an answer that is lost is
/// "may have started" and is settled by reading, never by sending again.
/// All timing is wall-clock, through the injected clock and delay, so a long
/// suspension cannot count as a few polls.
class GatewayRestart extends ChangeNotifier with SafeNotifier {
  GatewayRestart({
    required ServerCareRepository repository,
    ServerCareController? care,
    ConnectionTelemetry telemetry = const ConnectionTelemetry(),
    Breadcrumbs breadcrumbs = Breadcrumbs.none,
    DateTime Function()? now,
    Future<void> Function(Duration)? delay,
  }) : _repository = repository,
       _care = care,
       _telemetry = telemetry,
       _breadcrumbs = breadcrumbs,
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  /// How long the child's status is read for.
  static const waitWindow = Duration(seconds: 30);

  /// How long the gateway is waited for after the command.
  static const returnWindow = Duration(seconds: 90);
  static const _actionPoll = Duration(milliseconds: 1500);
  static const _statusPoll = Duration(seconds: 2);

  final ServerCareRepository _repository;
  final ServerCareController? _care;
  final ConnectionTelemetry _telemetry;
  final Breadcrumbs _breadcrumbs;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  GatewayPhase _phase = GatewayPhase.idle;
  GatewayAction? _action;
  GatewayFailure? _failure;
  String? _message;
  List<String> _logLines = const [];
  Future<void>? _running;

  GatewayPhase get phase => _phase;

  /// Null when idle.
  GatewayAction? get action => _action;

  /// Set with [GatewayPhase.failed].
  GatewayFailure? get failure => _failure;

  /// Hermes' own text: the refusal's detail, or the last lines of a failed
  /// run. Shown to the person, never logged.
  String? get message => _message;

  /// The last lines of the action's log, for "Show logs". Memory only.
  List<String> get logLines => _logLines;

  bool get busy =>
      _phase == GatewayPhase.starting ||
      _phase == GatewayPhase.waiting ||
      _phase == GatewayPhase.returning;

  /// Runs after the person confirmed. While a run is going a second call
  /// joins it and sends nothing; after `failed` or `slow` (Try again) or
  /// `done` it starts a new run with a new POST. [profile] is always sent.
  Future<void> run(GatewayAction action, {required String profile}) {
    final running = _running;
    if (running != null) return running;
    if (disposed) return Future.value();
    dismiss();
    final done = _execute(action, profile).whenComplete(() => _running = null);
    _running = done;
    return done;
  }

  /// Leaves done, failed or slow and goes back to idle.
  void dismiss() {
    if (busy || _phase == GatewayPhase.idle) return;
    _phase = GatewayPhase.idle;
    _action = null;
    _failure = null;
    _message = null;
    _logLines = const [];
    notifyListeners();
  }

  /// The person confirmed in the UI.
  void confirmed(GatewayAction action) =>
      _breadcrumbs('server_care.gateway.confirmed', {'action': action.name});

  @override
  void dispose() {
    if (busy) _care?.gatewayBusy = false;
    super.dispose();
  }

  void _enter(GatewayPhase phase) {
    if (disposed) return;
    final wasBusy = busy;
    _phase = phase;
    if (wasBusy != busy) _care?.gatewayBusy = busy;
    notifyListeners();
  }

  Future<void> _execute(GatewayAction action, String profile) async {
    _action = action;
    _failure = null;
    _message = null;
    _logLines = const [];
    final started = _now();
    Span? span;
    _quiet(
      () => span = _telemetry.tracer?.startSpan(
        'server_care.gateway',
        attributes: {..._telemetry.serverAttributes, 'action': action.name},
      ),
    );
    _enter(GatewayPhase.starting);
    String? outcome;
    try {
      outcome = await _follow(action, profile, started);
    } finally {
      final finished = outcome;
      if (finished != null) {
        _quiet(() => span?.setAttribute('outcome', finished));
      }
      _quiet(() => span?.end());
    }
    if (outcome == null) return;
    _quiet(
      () => _telemetry.events('server_care.gateway_finished', {
        'action': action.name,
        'outcome': outcome!,
      }),
    );
    final care = _care;
    if (care != null) unawaited(care.refresh());
  }

  /// Runs to the end and returns the outcome name; null when disposed.
  Future<String?> _follow(
    GatewayAction action,
    String profile,
    DateTime started,
  ) async {
    final result = switch (action) {
      GatewayAction.restart => await _repository.restartGateway(
        profile: profile,
      ),
      GatewayAction.start => await _repository.startGateway(profile: profile),
    };
    if (disposed) return null;
    var lost = false;
    switch (result) {
      case CareOk():
        break;
      case CareFailed(
        kind: CareFailureKind.offline || CareFailureKind.unreadable,
      ):
        // The answer is lost: it may have started. Never send it again.
        lost = true;
      case CareFailed(:final kind, :final message):
        final refused =
            kind == CareFailureKind.refused ||
            kind == CareFailureKind.server ||
            kind == CareFailureKind.storeUnreadable;
        return _fail(
          refused ? GatewayFailure.refused : GatewayFailure.unreachable,
          message,
        );
      case CareUnsupported():
        return _fail(GatewayFailure.unreachable, null);
    }
    final name = action == GatewayAction.restart
        ? CareAction.gatewayRestart
        : CareAction.gatewayStart;
    _enter(GatewayPhase.waiting);
    if (lost) {
      return _settleLostAnswer(name, profile, started);
    }

    // The child runs. Exit 0, or still running when the window ends, is
    // success of the command.
    final waitStart = _now();
    while (true) {
      final status = await _repository.actionStatus(name, lines: 40);
      if (disposed) return null;
      if (status case CareOk(:final value)) {
        _logLines = value.lines;
        if (!value.running) {
          final code = value.exitCode;
          if (code != null && code != 0) {
            return _fail(GatewayFailure.exited, _tail(value.lines));
          }
          break;
        }
      }
      if (_now().difference(waitStart) >= waitWindow) break;
      await _delay(_actionPoll);
      if (disposed) return null;
    }
    return _awaitReturn(profile, _now(), returnWindow);
  }

  /// The POST's answer was lost. Read the action and the gateway until one
  /// settles it; after [returnWindow] without either it is `slow`.
  ///
  /// The action status keeps the answer of an earlier run until a new one
  /// starts and its start header is cut off by the parser, so only a child
  /// that is running now counts as the run's own: it hands over to the usual
  /// wait. A non-zero exit is not trusted here.
  Future<String?> _settleLostAnswer(
    CareAction name,
    String profile,
    DateTime started,
  ) async {
    while (true) {
      final action = await _repository.actionStatus(name, lines: 40);
      if (disposed) return null;
      if (action case CareOk(:final value)) {
        _logLines = value.lines;
        if (value.running) {
          return _awaitReturn(profile, _now(), returnWindow);
        }
      }
      final gateway = await _repository.status(profile: profile);
      if (disposed) return null;
      if (gateway case CareOk(:final value) when _isBack(value)) {
        return _done();
      }
      if (_now().difference(started) >= returnWindow) return _slow();
      await _delay(_actionPoll);
      if (disposed) return null;
    }
  }

  Future<String?> _awaitReturn(
    String profile,
    DateTime from,
    Duration window,
  ) async {
    _enter(GatewayPhase.returning);
    while (true) {
      final gateway = await _repository.status(profile: profile);
      if (disposed) return null;
      if (gateway case CareOk(:final value) when _isBack(value)) {
        return _done();
      }
      if (_now().difference(from) >= window) return _slow();
      await _delay(_statusPoll);
      if (disposed) return null;
    }
  }

  static bool _isBack(ServerStatus status) =>
      status.gatewayRunning &&
      (status.gatewayState == GatewayState.running ||
          status.gatewayState == GatewayState.degraded);

  String _done() {
    _enter(GatewayPhase.done);
    return 'done';
  }

  String _slow() {
    _enter(GatewayPhase.slow);
    return 'slow';
  }

  String _fail(GatewayFailure failure, String? message) {
    _failure = failure;
    _message = message;
    _enter(GatewayPhase.failed);
    return failure.name;
  }

  static String? _tail(List<String> lines) {
    final text = [
      for (final line in lines)
        if (line.trim().isNotEmpty) line.trim(),
    ];
    if (text.isEmpty) return null;
    return text.skip(text.length > 5 ? text.length - 5 : 0).join('\n');
  }

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}
