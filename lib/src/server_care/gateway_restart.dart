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
    bool Function()? covered,
  }) : _repository = repository,
       _care = care,
       _telemetry = telemetry,
       _breadcrumbs = breadcrumbs,
       _now = now ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed,
       _covered = covered;

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

  /// Whether App Lock covers the app: Hermes' words about a failed run are
  /// not kept then.
  final bool Function()? _covered;

  GatewayPhase _phase = GatewayPhase.idle;
  GatewayAction? _action;
  GatewayFailure? _failure;
  String? _message;
  Future<void>? _running;
  int _runId = 0;
  bool _unconfirmed = false;
  String? _profile;

  /// The profile of the run in progress or just finished; null when idle.
  String? get profile => _profile;

  GatewayPhase get phase => _phase;

  /// With [GatewayPhase.slow]: the gateway never read as not running, so the
  /// run could not tell whether the restart happened at all.
  bool get unconfirmed => _unconfirmed;

  /// Null when idle.
  GatewayAction? get action => _action;

  /// Set with [GatewayPhase.failed].
  GatewayFailure? get failure => _failure;

  /// Hermes' own text: the refusal's detail, or the last lines of a failed
  /// run. Shown to the person, never logged.
  String? get message => _message;

  bool get busy =>
      _phase == GatewayPhase.starting ||
      _phase == GatewayPhase.waiting ||
      _phase == GatewayPhase.returning;

  /// Runs after the person confirmed. While a run is going a second call
  /// joins it and sends nothing; after `failed` or `slow` (Try again) or
  /// `done` it starts a new run with a new POST. [profile] is always sent.
  Future<void> run(
    GatewayAction action, {
    required String profile,
    bool shared = false,
  }) {
    final running = _running;
    if (running != null && busy) return running;
    if (disposed) return Future.value();
    dismiss();
    final id = ++_runId;
    late final Future<void> done;
    done = _execute(action, profile, shared, id).whenComplete(() {
      if (identical(_running, done)) _running = null;
    });
    _running = done;
    return done;
  }

  /// Leaves done, failed or slow and goes back to idle.
  void dismiss() {
    if (busy || _phase == GatewayPhase.idle) return;
    _phase = GatewayPhase.idle;
    _unconfirmed = false;
    _action = null;
    _profile = null;
    _failure = null;
    _message = null;
    notifyListeners();
  }

  /// Drops Hermes' own words about a failed run, for when the app is covered;
  /// the row then says only that it failed.
  void forgetText() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  /// The person confirmed in the UI.
  void confirmed(GatewayAction action) =>
      _breadcrumbs('server_care.gateway.confirmed', {'verb': action.name});

  @override
  void dispose() {
    if (busy) _care?.gatewayBusy = false;
    super.dispose();
  }

  void _enter(GatewayPhase phase) {
    if (disposed) return;
    final wasBusy = busy;
    _phase = phase;
    // Cleared by the run itself after the status was read again, so the
    // headline never flips back to the old state in between.
    if (!wasBusy && busy) _care?.gatewayBusy = true;
    notifyListeners();
  }

  Future<void> _execute(
    GatewayAction action,
    String profile,
    bool shared,
    int id,
  ) async {
    _unconfirmed = false;
    _action = action;
    _profile = profile;
    _failure = null;
    _message = null;
    final started = _now();
    Span? span;
    _quiet(
      () => span = _telemetry.tracer?.startSpan(
        'server_care.gateway',
        attributes: {
          ..._telemetry.serverAttributes,
          'verb': action.name,
          'shared': shared,
        },
      ),
    );
    _enter(GatewayPhase.starting);
    String? outcome;
    try {
      outcome = await _follow(action, profile, started);
    } finally {
      final finished = outcome;
      if (finished != null) {
        _quiet(() {
          span?.setAttribute('outcome', finished);
          span?.setAttribute('duration', _bucket(_now().difference(started)));
        });
      }
      _quiet(() => span?.end());
    }
    if (outcome == null) return;
    _quiet(
      () => _telemetry.events('server_care.gateway_finished', {
        'verb': action.name,
        'outcome': outcome!,
      }),
    );
    final care = _care;
    if (care == null) return;
    await care.refresh();
    // A newer run (Try again) owns the mark by now.
    if (!disposed && id == _runId) care.gatewayBusy = false;
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
        kind: CareFailureKind.offline ||
            CareFailureKind.unreadable ||
            CareFailureKind.server,
        message: null,
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

    // The child runs. Exit 0 is success of the command; a child still
    // running when the window ends is too (without a service manager it
    // becomes the gateway and never exits).
    //
    // For a restart the old gateway is running when the run starts, so
    // "running" alone proves nothing: it counts only after the gateway was
    // seen down, or the child exited 0 (the command itself finished). The
    // status is read beside the action to catch the short gap.
    var sawDown = action == GatewayAction.start;
    var exitedClean = false;
    final waitStart = _now();
    while (true) {
      final status = await _repository.actionStatus(name, lines: 40);
      if (disposed) return null;
      if (status case CareOk(:final value)) {
        if (!value.running) {
          final code = value.exitCode;
          if (code != null && code != 0) {
            return _fail(GatewayFailure.exited, _tail(value.lines));
          }
          exitedClean = code == 0;
          break;
        }
      }
      if (!sawDown) {
        final gateway = await _repository.status(profile: profile);
        if (disposed) return null;
        if (gateway case CareOk(:final value) when !_isBack(value)) {
          sawDown = true;
        }
      }
      if (_now().difference(waitStart) >= waitWindow) break;
      await _delay(_actionPoll);
      if (disposed) return null;
    }
    return _awaitReturn(
      profile,
      started,
      returnWindow,
      sawDown: sawDown || exitedClean,
      watch: exitedClean ? null : name,
    );
  }

  /// The POST's answer was lost. Read the action and the gateway until one
  /// settles it; after [returnWindow] without either it is `slow`.
  ///
  /// The action status keeps the answer of an earlier run until a new one
  /// starts and its start header is cut off by the parser, so only a child
  /// that is running now counts as the run's own: it hands over to the wait
  /// for the gateway, which keeps reading that child's action. An exit code
  /// seen before such a child is not trusted here.
  Future<String?> _settleLostAnswer(
    CareAction name,
    String profile,
    DateTime started,
  ) async {
    // A restart found the old gateway running; "running" alone proves
    // nothing until it has been seen down. A start has no such old state.
    var sawDown = name == CareAction.gatewayStart;
    var lastBack = false;
    while (true) {
      final action = await _repository.actionStatus(name, lines: 40);
      if (disposed) return null;
      if (action case CareOk(:final value)) {
        if (value.running) {
          return _awaitReturn(
            profile,
            started,
            returnWindow,
            sawDown: sawDown,
            watch: name,
            // The action registry is per dashboard, not per profile: after a
            // lost answer the child seen running may belong to another
            // profile's run, so its exit 0 proves nothing about this one. A
            // failure still ends the run.
            exitZeroCounts: false,
          );
        }
      }
      final gateway = await _repository.status(profile: profile);
      if (disposed) return null;
      if (gateway case CareOk(:final value)) {
        lastBack = _isBack(value);
        if (lastBack) {
          if (sawDown) return _done();
        } else {
          sawDown = true;
        }
      }
      if (_now().difference(started) >= returnWindow) {
        return _slow(gatewayRunning: !sawDown && lastBack);
      }
      await _delay(_actionPoll);
      if (disposed) return null;
    }
  }

  /// Reads the gateway until it runs again. With [watch] the action of a
  /// child this run saw running is read too, until the gateway was seen down:
  /// its exit 0 counts as the restart finished, a non-zero exit fails the run.
  Future<String?> _awaitReturn(
    String profile,
    DateTime from,
    Duration window, {
    required bool sawDown,
    CareAction? watch,
    bool exitZeroCounts = true,
  }) async {
    _enter(GatewayPhase.returning);
    var lastBack = false;
    var watching = watch != null;
    while (true) {
      // The child is read until it ended, whether or not the gateway was
      // seen down: a child that fails with the gateway stopped is a failed
      // run with its reason, not a slow one.
      if (watching) {
        final action = await _repository.actionStatus(watch!, lines: 40);
        if (disposed) return null;
        if (action case CareOk(:final value) when !value.running) {
          watching = false;
          final code = value.exitCode;
          if (code != null && code != 0) {
            return _fail(GatewayFailure.exited, _tail(value.lines));
          }
          if (code == 0 && exitZeroCounts) sawDown = true;
        }
      }
      final gateway = await _repository.status(profile: profile);
      if (disposed) return null;
      if (gateway case CareOk(:final value)) {
        lastBack = _isBack(value);
        if (lastBack) {
          if (sawDown) return _done();
        } else {
          sawDown = true;
        }
      }
      if (_now().difference(from) >= window) {
        return _slow(gatewayRunning: !sawDown && lastBack);
      }
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
    return 'back';
  }

  String _slow({required bool gatewayRunning}) {
    _unconfirmed = gatewayRunning;
    _enter(GatewayPhase.slow);
    return 'slow';
  }

  String _fail(GatewayFailure failure, String? message) {
    _failure = failure;
    _message = (_covered?.call() ?? false) ? null : message;
    _enter(GatewayPhase.failed);
    return failure == GatewayFailure.refused ? 'refused' : 'failed';
  }

  static String _bucket(Duration d) => switch (d.inSeconds) {
    <= 10 => '0-10s',
    <= 30 => '11-30s',
    <= 90 => '31-90s',
    _ => '>90s',
  };

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
