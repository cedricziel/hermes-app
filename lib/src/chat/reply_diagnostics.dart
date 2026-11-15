import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_otel/flutter_otel.dart' show AppEventLogger;

import '../telemetry/diagnosis_buckets.dart';
import 'chat_transport.dart';
import 'gateway/gateway_rpc_client.dart';

/// Every `cause` of a `chat.reply.ended` event.
const kReplyEndCauses = {
  'none',
  'user_stop',
  'reconnect_gave_up',
  'session_gone',
  'turn_ended',
  'connection_closed',
  'timeout',
  'rejected',
  'profile',
  'not_sent',
  'server_error',
  'withdrawn',
  'other',
};

/// Every `outcome` of a `chat.reply.ended` event. `lost_connection` is not an
/// end: the turn may still run on the server and the reply waits for it, so a
/// later `chat.reply.ended` closes the same reply.
const kReplyEndOutcomes = {
  'completed',
  'failed',
  'stopped',
  'folded',
  'lost_connection',
  'withdrawn',
};

/// Every `step` of a `chat.reply.ended` event (`none` when no send step was
/// named).
const kReplyEndSteps = {'none', 'connect', 'open', 'attach', 'submit', 'reply'};

/// Every `kind` of a `chat.reply.late_event`.
const kLateEventKinds = {'delta', 'tool', 'completed', 'request'};

/// Every `state` of a `chat.queue.state` event.
const kQueueStates = {'held', 'paused', 'drained', 'abandoned'};

/// What a reply ended with, as a fixed name. Never the error's message.
String replyEndCause(Object? error, {required bool stopped}) {
  if (stopped) return 'user_stop';
  final cause = error is SendFailure ? error.cause : error;
  return switch (cause) {
    null => 'none',
    GatewayReplyLost() => 'reconnect_gave_up',
    GatewaySessionGone() => 'session_gone',
    GatewayTurnEnded() => 'turn_ended',
    GatewayCallTimedOut() => 'timeout',
    TimeoutException() => 'timeout',
    GatewayConnectionClosed() => 'connection_closed',
    GatewayRpcException() => 'rejected',
    ProfileUnavailableException() => 'profile',
    PromptNotSent() => 'not_sent',
    _ => 'other',
  };
}

/// What one reply of this client has been through, from the prompt being sent
/// to its end.
class ReplyRun {
  ReplyRun._(this._startedAt, this._awayAtStart);

  final DateTime _startedAt;
  final Duration _awayAtStart;

  /// How many times the reply lost its connection and was held for a retry.
  int holds = 0;

  /// How many times a held reply was picked up again.
  int pickUps = 0;
}

/// Reply-loss diagnosis for [ChatController]: what the app was doing while a
/// reply ran (`app.lifecycle`), how the reply ended (`chat.reply.ended`), what
/// came after a failed end (`chat.reply.late_event`) and what happened to the
/// queue behind it (`chat.queue.state`).
///
/// Every attribute is a fixed name, a flag, a bucket (see
/// `telemetry/diagnosis_buckets.dart`) or a small count: never a prompt, a
/// title, a profile, an address or an id. Logging never throws.
class ReplyDiagnostics {
  ReplyDiagnostics({required this._events, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final AppEventLogger _events;
  final DateTime Function() _now;

  DateTime? _awaySince;
  Duration _awayBefore = Duration.zero;
  bool _ranAtPause = false;

  /// The reply each thread holds for a reconnect, by thread.
  final _held = <Object, ReplyRun>{};

  /// When a thread's reply was declared failed, until its next send.
  final _failedAt = <Object, DateTime>{};
  final _lateKinds = <Object, Set<String>>{};
  final _queueState = <Object, String>{};

  void _log(String name, Map<String, Object> attributes) {
    try {
      _events(name, attributes);
    } on Object {
      // Telemetry must not take a reply down with it.
    }
  }

  Duration get _awayTotal =>
      _awayBefore +
      (_awaySince == null ? Duration.zero : _now().difference(_awaySince!));

  /// The app changed lifecycle state. Logged only while a reply runs, and on
  /// the return from the background of a reply that ran when it left.
  void lifecycle(AppLifecycleState state, {required bool replyRunning}) {
    try {
      final leaving =
          state == AppLifecycleState.hidden ||
          state == AppLifecycleState.paused ||
          state == AppLifecycleState.detached;
      final away = state == AppLifecycleState.resumed && _awaySince != null
          ? _now().difference(_awaySince!)
          : null;
      final report =
          replyRunning || (state == AppLifecycleState.resumed && _ranAtPause);
      if (leaving) {
        _awaySince ??= _now();
        _ranAtPause = _ranAtPause || replyRunning;
      }
      if (state == AppLifecycleState.resumed) {
        if (away != null) _awayBefore += away;
        _awaySince = null;
      }
      if (report) {
        _log('app.lifecycle', {
          'state': state.name,
          'reply_running': replyRunning,
          'away': away == null ? 'none' : awayBucket(away),
        });
      }
      if (state == AppLifecycleState.resumed) _ranAtPause = false;
    } on Object {
      // Telemetry must not break the app lifecycle.
    }
  }

  /// A reply starts: what it measures its time away from.
  ReplyRun begin(Object thread) {
    _failedAt.remove(thread);
    _lateKinds.remove(thread);
    _held.remove(thread);
    _queueState.remove(thread);
    return ReplyRun._(_now(), _awayTotal);
  }

  /// [run]'s reply lost its connection and waits for the server.
  void hold(Object thread, ReplyRun run) {
    run.holds++;
    _held[thread] = run;
  }

  /// A held reply of [thread] lost its connection again.
  void holdAgain(Object thread) => _held[thread]?.holds++;

  /// A held reply of [thread] is picked up again.
  void pickedUp(Object thread) => _held[thread]?.pickUps++;

  /// Whether [thread] has a reply held for a reconnect.
  bool isHeld(Object thread) => _held.containsKey(thread);

  /// Logs `chat.reply.ended` for [run].
  ///
  /// [outcome] is one of [kReplyEndOutcomes]; [error] and [stopped] give the
  /// `cause`; [step] names the send step a [SendFailure] stopped at; [queued]
  /// is how many prompts wait behind the reply.
  void ended(
    Object thread,
    ReplyRun run, {
    required String outcome,
    required Object? error,
    required bool stopped,
    required int queued,
    bool serverReportedFailure = false,
  }) {
    try {
      final failed = outcome == 'failed';
      var cause = replyEndCause(error, stopped: stopped);
      if (failed && cause == 'none' && serverReportedFailure) {
        cause = 'server_error';
      }
      if (outcome == 'withdrawn') cause = 'withdrawn';
      final step = error is SendFailure ? error.step.name : 'none';
      _log('chat.reply.ended', {
        'outcome': outcome,
        'cause': cause,
        'step': step,
        'reconnect_attempts': run.holds + run.pickUps,
        'away': awayBucket(_awayTotal - run._awayAtStart),
        'duration': durationBucket(_now().difference(run._startedAt)),
        'queue_len': countBucket(queued),
      });
      if (failed) {
        _failedAt[thread] = _now();
        _lateKinds[thread] = {};
      }
    } on Object {
      // Telemetry must not take a reply down with it.
    }
  }

  /// A held reply of [thread] ended for good on the follow-ups.
  void endedHeld(
    Object thread, {
    required String outcome,
    required Object? error,
    required int queued,
  }) {
    final run = _held.remove(thread);
    if (run == null) return;
    ended(
      thread,
      run,
      outcome: outcome,
      error: error,
      stopped: outcome == 'stopped',
      queued: queued,
    );
  }

  /// Forgets what [thread] held.
  void forget(Object thread) {
    _held.remove(thread);
    _failedAt.remove(thread);
    _lateKinds.remove(thread);
    _queueState.remove(thread);
  }

  /// A frame arrived on [thread]'s follow-ups, which carries a reply that was
  /// declared failed and has had no new prompt since. Counted once per kind
  /// and failed end, so a long stream is one record, not hundreds.
  void follow(Object thread, ChatEvent event) {
    try {
      final failedAt = _failedAt[thread];
      if (failedAt == null) return;
      final kind = switch (event) {
        ReplyDelta() || ReplyRebuilt() => 'delta',
        ToolStarted() || ToolFinished() || ToolPreparing() => 'tool',
        ReplyCompleted() => 'completed',
        ApprovalRequested() || ClarifyRequested() => 'request',
        _ => null,
      };
      if (kind == null) return;
      final seen = _lateKinds[thread] ??= {};
      if (!seen.add(kind)) return;
      _log('chat.reply.late_event', {
        'kind': kind,
        'since_end': durationBucket(_now().difference(failedAt)),
      });
    } on Object {
      // Telemetry must not break the follow-ups.
    }
  }

  /// The queue behind [thread]'s reply changed: [state] is one of
  /// [kQueueStates], [count] how many prompts it holds. The same state and
  /// count twice in a row is one record.
  void queue(Object thread, String state, int count) {
    final key = '$state/${countBucket(count)}';
    if (_queueState[thread] == key) return;
    _queueState[thread] = key;
    _log('chat.queue.state', {'state': state, 'count': countBucket(count)});
  }
}
