import 'package:flutter_otel/flutter_otel.dart' show Span, StatusCode;

import '../telemetry/breadcrumbs.dart';
import '../telemetry/telemetry.dart';
import 'widgets/session_export_failure.dart';

/// The size of the received file, in the buckets `session_export.fetch` carries.
String sessionExportBytesBucket(int bytes) => switch (bytes) {
  < 100 * 1024 => '<100KB',
  < 5 * 1024 * 1024 => '<5MB',
  < 50 * 1024 * 1024 => '<50MB',
  _ => '>=50MB',
};

/// The number of messages in the file, in buckets.
String sessionExportMessagesBucket(int count) => switch (count) {
  0 => '0',
  <= 50 => '1-50',
  <= 500 => '51-500',
  _ => '>500',
};

/// The snake_case name of a failure, shared by the span outcome and the
/// `session_export.failed` reason.
extension SessionExportFailureSlug on SessionExportFailure {
  String get slug => switch (this) {
    SessionExportFailure.gone => 'gone',
    SessionExportFailure.unsupported => 'unsupported',
    SessionExportFailure.profileMissing => 'profile_missing',
    SessionExportFailure.profileInvalid => 'profile_invalid',
    SessionExportFailure.unreadable => 'unreadable',
    SessionExportFailure.lost => 'lost',
    SessionExportFailure.incomplete => 'incomplete',
    SessionExportFailure.offline => 'offline',
    SessionExportFailure.failed => 'failed',
  };
}

/// What the chat export tells telemetry: the span `session_export.fetch`, the
/// event `session_export.failed` and the crumbs `session_export.started`,
/// `.saved` and `.cancelled`. Every value is a fixed name or a bucket: never
/// the chat's id, title, profile, the file's name or any of its content.
/// Nothing here throws.
class SessionExportTelemetry {
  const SessionExportTelemetry([
    this.connection = const ConnectionTelemetry(),
    this.breadcrumbs = Breadcrumbs.none,
  ]);

  final ConnectionTelemetry connection;
  final Breadcrumbs breadcrumbs;

  void started() => _quiet(() => breadcrumbs('session_export.started'));

  void saved() => _quiet(() => breadcrumbs('session_export.saved'));

  void cancelled() => _quiet(() => breadcrumbs('session_export.cancelled'));

  /// The save sheet threw: reported as a `failed` event; its span has ended.
  void saveFailed() => _quiet(
    () => connection.events('session_export.failed', {
      'reason': SessionExportFailure.failed.slug,
    }),
  );

  Span? startFetch() {
    try {
      return connection.tracer?.startSpan(
        'session_export.fetch',
        attributes: connection.serverAttributes,
      );
    } on Object {
      return null;
    }
  }

  /// Ends the span with [outcome] (`ready`, `cancelled` or a failure's slug),
  /// the buckets of what arrived, and logs the failure when there is one.
  void endFetch(
    Span? span, {
    SessionExportFailure? failure,
    bool cancelled = false,
    int bytes = 0,
    int? messages,
  }) => _quiet(() {
    final outcome = cancelled ? 'cancelled' : (failure?.slug ?? 'ready');
    span?.setAttributes({
      'outcome': outcome,
      if (bytes > 0) 'bytes_bucket': sessionExportBytesBucket(bytes),
      if (messages != null)
        'messages_bucket': sessionExportMessagesBucket(messages),
    });
    if (failure != null) span?.setStatus(StatusCode.error);
    span?.end();
    if (failure != null) {
      connection.events('session_export.failed', {'reason': failure.slug});
    }
  });

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}
