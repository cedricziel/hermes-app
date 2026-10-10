import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, Span, StatusCode, Tracer, noopAppEventLogger;

import '../telemetry/breadcrumbs.dart';
import '../telemetry/telemetry.dart';
import 'drag_out_item.dart';

/// What a drag out of the app tells telemetry: a breadcrumb when it starts, a
/// span around the work a drop triggers, and one log event when it ends.
///
/// Every value comes from [DragOutKind], [DragOutOutcome] and
/// [DragOutFailure], so no name, title, text, id, path or size can reach it.
/// Nothing here throws, so a broken exporter never breaks a drag.
class DragOutTelemetry {
  const DragOutTelemetry({
    this.breadcrumbs = Breadcrumbs.none,
    this.events = noopAppEventLogger,
    this.tracer,
    this.serverAttributes = const {},
  });

  /// The telemetry of [connection], with crumbs recorded on [breadcrumbs].
  DragOutTelemetry.forConnection(
    ConnectionTelemetry connection,
    Breadcrumbs breadcrumbs,
  ) : this(
        breadcrumbs: breadcrumbs,
        events: connection.events,
        tracer: connection.tracer,
        serverAttributes: connection.serverAttributes,
      );

  final Breadcrumbs breadcrumbs;
  final AppEventLogger events;
  final Tracer? tracer;
  final Map<String, Object> serverAttributes;

  /// A drag began.
  void started(DragOutKind kind) =>
      breadcrumbs('drag_out.started', {'kind': kind.slug});

  /// Runs [body], the work a drop triggers, inside a `drag_out.promise` span
  /// and returns what it returns. [body] reports how it ended through the
  /// outcome it returns; a throw is recorded and rethrown.
  Future<DragOutOutcome> promise(
    DragOutKind kind,
    Future<DragOutOutcome> Function() body,
  ) async {
    final span = _start(kind);
    try {
      final outcome = await body();
      _end(span, outcome);
      return outcome;
    } on Object {
      _end(span, DragOutOutcome.failed);
      rethrow;
    }
  }

  /// A drop ended with [outcome], and with [failure] when it failed.
  void completed(
    DragOutKind kind,
    DragOutOutcome outcome, {
    DragOutFailure? failure,
  }) {
    try {
      events('drag_out.completed', {
        'kind': kind.slug,
        'outcome': outcome.name,
        if (failure != null) 'failure': failure.name,
      });
    } on Object {
      // Telemetry must not break the app.
    }
  }

  Span? _start(DragOutKind kind) {
    try {
      return tracer?.startSpan(
        'drag_out.promise',
        attributes: {...serverAttributes, 'kind': kind.slug},
      );
    } on Object {
      return null;
    }
  }

  void _end(Span? span, DragOutOutcome outcome) {
    if (span == null) return;
    try {
      span.setAttributes({'outcome': outcome.name});
      if (outcome == DragOutOutcome.failed) {
        span.setStatus(StatusCode.error);
      }
      span.end();
    } on Object {
      // Telemetry must not break the app.
    }
  }
}
