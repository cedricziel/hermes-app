import 'package:flutter_otel/flutter_otel.dart' show Span, StatusCode;

import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';

/// Where the user opened the Personality page from, as `profile_soul.opened`
/// reports it.
enum SoulOpenedFrom {
  sidebar('sidebar'),
  profilesPage('profiles_page');

  const SoulOpenedFrom(this.slug);

  final String slug;
}

/// How a save ended, as the span and the `profile_soul.saved` event say it.
enum SoulSaveOutcome {
  saved('saved', 'saved'),
  conflict('conflict', null),
  conflictKept('conflict', 'conflict_kept'),
  conflictReplaced('saved', 'conflict_replaced'),
  failed('failed', 'failed'),
  unconfirmed('unconfirmed', 'unconfirmed'),
  checkFailed('check_failed', null),
  discarded('discarded', null);

  const SoulSaveOutcome(this.spanSlug, this.eventSlug);

  final String spanSlug;

  /// Null for an outcome that is not logged as an event.
  final String? eventSlug;
}

/// The bucket of a text's length, as `profile_soul.save` carries it.
String soulLengthBucket(int length) => switch (length) {
  < 1000 => 'lt_1k',
  < 5000 => 'lt_5k',
  < 20000 => 'lt_20k',
  _ => 'gte_20k',
};

/// What the Personality controller tells telemetry: spans
/// `profile_soul.fetch` and `profile_soul.save`, the log event
/// `profile_soul.saved` and the crumbs `profile_soul.opened` and
/// `profile_soul.save.confirmed`.
///
/// Every value is a fixed name, a bucket or a flag: never the text, the
/// profile name or a response body. Nothing here throws.
class SoulTelemetry {
  SoulTelemetry([
    this.connection = const ConnectionTelemetry(),
    this.breadcrumbs = Breadcrumbs.none,
  ]);

  final ConnectionTelemetry connection;
  final Breadcrumbs breadcrumbs;

  void opened(SoulOpenedFrom from) =>
      _quiet(() => breadcrumbs('profile_soul.opened', {'source': from.slug}));

  void saveConfirmed() =>
      _quiet(() => breadcrumbs('profile_soul.save.confirmed'));

  Span? startFetch() => _start('profile_soul.fetch');

  /// [outcome] is a fixed slug (`ok`, `failed`, `offline`, `unsupported`,
  /// `profile_gone`, `discarded`); [exists] is known only for `ok`.
  void endFetch(Span? span, String outcome, {bool? exists}) => _quiet(() {
    span?.setAttributes({'outcome': outcome, 'exists': ?exists});
    _finish(span, failed: outcome != 'ok' && outcome != 'discarded');
  });

  Span? startSave() => _start('profile_soul.save');

  void endSave(
    Span? span,
    SoulSaveOutcome outcome, {
    required bool empty,
    required int length,
  }) => _quiet(() {
    span?.setAttributes({
      'outcome': outcome.spanSlug,
      'empty': empty,
      'length_bucket': soulLengthBucket(length),
    });
    _finish(
      span,
      failed:
          outcome == SoulSaveOutcome.failed ||
          outcome == SoulSaveOutcome.unconfirmed ||
          outcome == SoulSaveOutcome.checkFailed,
    );
  });

  /// The event `profile_soul.saved`; none for an outcome without an event.
  void saved(SoulSaveOutcome outcome, {required bool empty}) {
    final slug = outcome.eventSlug;
    if (slug == null) return;
    _quiet(
      () => connection.events('profile_soul.saved', {
        'outcome': slug,
        'empty': empty,
      }),
    );
  }

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
