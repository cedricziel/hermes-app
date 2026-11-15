import 'package:flutter_otel/flutter_otel.dart' show Span, StatusCode;

import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';

/// How a followed curator pass ended, as the span and the log event name it.
enum CuratorRunOutcome {
  /// `running` false, a start header after the POST, exit code 0.
  done,

  /// The same proof with a non-zero exit code, or a start that was refused.
  failed,

  /// Nothing proves how it ended: a lost answer, lost progress, a stop with
  /// no exit code, no start header.
  unknown,

  /// Still running when the 15-minute follow window ended.
  timedOut;

  String get slug => this == timedOut ? 'timed_out' : name;
}

/// What the skill curator tells telemetry: the span `skills_curator.run`
/// (the POST to the end), the event `skills_curator.run_finished`, and the
/// crumbs `skills_curator.run.confirmed` and `skills_curator.paused`.
///
/// Every value is a fixed name, a flag or a count: never a profile, a skill
/// name, an output line or an action id. Nothing here throws.
class CuratorTelemetry {
  const CuratorTelemetry([
    this.connection = const ConnectionTelemetry(),
    this.breadcrumbs = Breadcrumbs.none,
  ]);

  final ConnectionTelemetry connection;
  final Breadcrumbs breadcrumbs;

  void confirmed() => _quiet(() => breadcrumbs('skills_curator.run.confirmed'));

  void paused({required bool paused}) =>
      _quiet(() => breadcrumbs('skills_curator.paused', {'paused': paused}));

  Span? startRun() {
    try {
      return connection.tracer?.startSpan(
        'skills_curator.run',
        attributes: connection.serverAttributes,
      );
    } on Object {
      return null;
    }
  }

  /// Ends the run's span. [triggerLost] is true when the answer to the POST
  /// never came, so whether it started is not known.
  void endRun(
    Span? span,
    CuratorRunOutcome outcome, {
    required bool triggerLost,
  }) {
    // Each call has its own guard: one that throws must not leave the span
    // open.
    _quiet(
      () => span?.setAttributes({
        'outcome': outcome.slug,
        'trigger_lost': triggerLost,
      }),
    );
    if (outcome != CuratorRunOutcome.done) {
      _quiet(() => span?.setStatus(StatusCode.error));
    }
    _quiet(() => span?.end());
  }

  /// [archived] is the number of the `archived=N` line Hermes printed, or
  /// null when no such line was found. A pass that ended unknown or timed
  /// out is logged then; when a later Check status resolves it as done or
  /// failed it is logged again with [resolvedByCheck] true, so one pass can
  /// have two events and the second is the one that says how it ended.
  void runFinished(
    CuratorRunOutcome outcome, {
    int? archived,
    bool resolvedByCheck = false,
  }) => _quiet(
    () => connection.events('skills_curator.run_finished', {
      'outcome': outcome.slug,
      if (resolvedByCheck) 'resolved_by_check': true,
      'archived': ?archived,
    }),
  );

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}
