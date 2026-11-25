import 'package:flutter_otel/flutter_otel.dart' show Span, StatusCode;

import '../../telemetry/breadcrumbs.dart';
import '../../telemetry/telemetry.dart';

/// How a start ended, as the `whatsapp.pair.start` span says it.
enum WhatsAppStartOutcome {
  started('started'),
  alreadyLinked('already_linked'),
  lostAnswer('lost_answer'),
  unsupported('unsupported'),
  profileGone('profile_gone'),
  refused('refused'),
  failed('failed'),

  /// The screen was left (or the connection ended) before the answer came.
  discarded('discarded');

  const WhatsAppStartOutcome(this.slug);

  final String slug;

  bool get isFailure =>
      this == lostAnswer ||
      this == unsupported ||
      this == profileGone ||
      this == refused ||
      this == failed;
}

/// How an apply ended, as the `whatsapp.pair.apply` span says it.
enum WhatsAppApplyOutcome {
  saved('saved'),

  /// A 200 without `ok`: the save is not known.
  unconfirmed('unconfirmed'),
  lostAnswer('lost_answer'),
  refused('refused'),
  recordGone('record_gone'),
  profileGone('profile_gone'),
  failed('failed'),
  discarded('discarded');

  const WhatsAppApplyOutcome(this.slug);

  final String slug;

  bool get isFailure => this != saved && this != discarded;
}

/// How a pairing ended, as `whatsapp.pair.ended` says it.
enum WhatsAppEndStatus {
  connected('connected'),
  error('error'),
  expired('expired'),
  cancelled('cancelled'),
  superseded('superseded');

  const WhatsAppEndStatus(this.slug);

  final String slug;
}

/// What the WhatsApp pairing controller tells telemetry: spans
/// `whatsapp.pair.start` (`outcome`) and `whatsapp.pair.apply` (`outcome`,
/// `restart`), the log events `whatsapp.pair.ended` (`status`) and
/// `whatsapp.pair.unavailable` (once per instance, so one per connection when
/// the shell builds one for it), and the crumbs `whatsapp.pair.opened`,
/// `whatsapp.pair.qr_shown` and `whatsapp.pair.applied`.
///
/// Every value is a fixed word: never the code, the pairing id, a number, a
/// name, the server's text or the profile. Nothing here throws.
class WhatsAppPairingTelemetry {
  WhatsAppPairingTelemetry([
    this.connection = const ConnectionTelemetry(),
    this.breadcrumbs = Breadcrumbs.none,
  ]);

  final ConnectionTelemetry connection;
  final Breadcrumbs breadcrumbs;

  var _toldUnavailable = false;

  void opened() => _quiet(() => breadcrumbs('whatsapp.pair.opened'));

  void qrShown() => _quiet(() => breadcrumbs('whatsapp.pair.qr_shown'));

  /// [restartRequested]: a restart of the messaging gateway was asked for and
  /// the server did not say it still has to be done by hand.
  void applied({required bool restartRequested}) => _quiet(
    () => breadcrumbs('whatsapp.pair.applied', {
      'restart': _restart(restartRequested),
    }),
  );

  Span? startStart() => _start('whatsapp.pair.start');

  void endStart(Span? span, WhatsAppStartOutcome outcome) => _quiet(() {
    span?.setAttributes({'outcome': outcome.slug});
    _finish(span, failed: outcome.isFailure);
  });

  Span? startApply() => _start('whatsapp.pair.apply');

  void endApply(
    Span? span,
    WhatsAppApplyOutcome outcome, {
    bool restartRequested = false,
  }) => _quiet(() {
    span?.setAttributes({
      'outcome': outcome.slug,
      'restart': _restart(restartRequested),
    });
    _finish(span, failed: outcome.isFailure);
  });

  void ended(WhatsAppEndStatus status) => _quiet(
    () => connection.events('whatsapp.pair.ended', {'status': status.slug}),
  );

  /// The server has no such route; logged once.
  void unavailable() {
    if (_toldUnavailable) return;
    _toldUnavailable = true;
    _quiet(() => connection.events('whatsapp.pair.unavailable'));
  }

  static String _restart(bool requested) =>
      requested ? 'requested' : 'not_requested';

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
