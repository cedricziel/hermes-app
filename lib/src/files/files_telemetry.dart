import 'package:flutter_otel/flutter_otel.dart' show Span, StatusCode;

import '../telemetry/telemetry.dart';
import 'files_failure.dart';

/// How many entries a listing held, in the buckets `files.list` carries.
String filesEntriesBucket(int count) => switch (count) {
  0 => '0',
  <= 50 => '1-50',
  <= 500 => '51-500',
  _ => '>500',
};

/// A file's size in the buckets `files.download` carries.
String filesSizeBucket(int bytes) => switch (bytes) {
  < 100 * 1024 => '<100KB',
  < 5 * 1024 * 1024 => '<5MB',
  < 50 * 1024 * 1024 => '<50MB',
  _ => '>=50MB',
};

/// How a download ended, as `files.download` reports it.
enum FilesDownloadOutcome { done, cancelled, failed, tooLarge }

/// What the Files data layer tells telemetry: spans `files.list` and
/// `files.download`, and log events `files.unsupported`, `files.list_failed`
/// and `files.download_failed`.
///
/// Every value is a fixed name, a bucket or a flag, so no path, file or folder
/// name, profile, folder or server address, nor any content can reach it.
/// Nothing here throws, so a broken exporter never breaks the page.
///
/// Keep one per connection: `files.unsupported` is logged once for it.
class FilesTelemetry {
  FilesTelemetry([this.connection = const ConnectionTelemetry()]);

  final ConnectionTelemetry connection;
  var _reportedUnsupported = false;

  /// The server has no `/api/fs` routes. Logged once.
  void unsupported() {
    if (_reportedUnsupported) return;
    _reportedUnsupported = true;
    _quiet(() => connection.events('files.unsupported'));
  }

  void listFailed(FilesFailure kind) =>
      _quiet(() => connection.events('files.list_failed', {'kind': kind.slug}));

  void downloadFailed(FilesFailure kind) => _quiet(
    () => connection.events('files.download_failed', {'kind': kind.slug}),
  );

  Span? startList() => _start('files.list');

  /// Ends the `files.list` span: `ok` with the [entries] bucket, `cancelled`
  /// or `failed`.
  void endList(Span? span, FilesFailure? failure, {int? entries}) => _quiet(() {
    span?.setAttribute('outcome', switch (failure) {
      null => 'ok',
      FilesFailure.cancelled => 'cancelled',
      _ => 'failed',
    });
    if (entries != null) {
      span?.setAttribute('entries', filesEntriesBucket(entries));
    }
    _finish(span, failed: failure != null && failure != FilesFailure.cancelled);
  });

  Span? startDownload() => _start('files.download');

  /// Ends the `files.download` span with the size bucket of [bytes] (the
  /// announced length when there is one) and whether the length was known.
  void endDownload(
    Span? span,
    FilesDownloadOutcome outcome, {
    required int bytes,
    required bool lengthKnown,
  }) => _quiet(() {
    span?.setAttributes({
      'outcome': switch (outcome) {
        FilesDownloadOutcome.done => 'done',
        FilesDownloadOutcome.cancelled => 'cancelled',
        FilesDownloadOutcome.failed => 'failed',
        FilesDownloadOutcome.tooLarge => 'too_large',
      },
      'size': filesSizeBucket(bytes),
      'length_known': lengthKnown,
    });
    _finish(span, failed: outcome == FilesDownloadOutcome.failed);
  });

  Span? _start(String name) {
    try {
      return connection.tracer?.startSpan(
        name,
        attributes: connection.serverAttributes,
      );
    } on Object {
      return null;
    }
  }

  static void _finish(Span? span, {required bool failed}) {
    if (failed) span?.setStatus(StatusCode.error);
    span?.end();
  }

  static void _quiet(void Function() action) {
    try {
      action();
    } on Object {
      return;
    }
  }
}
