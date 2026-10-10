import 'package:flutter/widgets.dart';
import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;
import 'package:provider/provider.dart';

import '../../api/hermes_repositories.dart';
import '../../telemetry/breadcrumbs.dart';

/// Where a preview was asked for.
enum QuickLookSource { chat, kanban }

/// How it was asked for: Space, or the context menu.
enum QuickLookTrigger { key, menu }

/// What went wrong before the panel showed the file.
enum QuickLookStage {
  /// The file could not be fetched from the server.
  download,

  /// A file on this device or in the message could not be put in the cache.
  stageLocal,

  /// The panel could not show the file.
  native,
}

/// What a Quick Look tells telemetry: a breadcrumb when the panel was shown
/// or could not be, and a log event for a failure.
///
/// Every value comes from the enums above and [MediaFailure] names, so no
/// file name, extension, path, size, id or content can reach it. Nothing here
/// throws.
class QuickLookTelemetry {
  const QuickLookTelemetry({
    this.breadcrumbs = Breadcrumbs.none,
    this.events = noopAppEventLogger,
  });

  /// The telemetry of the connection above [context], if any.
  factory QuickLookTelemetry.of(BuildContext context) {
    Breadcrumbs crumbs = Breadcrumbs.none;
    try {
      crumbs = Provider.of<Breadcrumbs>(context, listen: false);
    } on ProviderNotFoundException {
      // Telemetry is off, or there is no provider above.
    }
    return QuickLookTelemetry(
      breadcrumbs: crumbs,
      events:
          HermesRepositories.maybeOf(context)?.telemetry.events ??
          noopAppEventLogger,
    );
  }

  final Breadcrumbs breadcrumbs;
  final AppEventLogger events;

  /// The panel is showing the file.
  void opened(QuickLookSource source, QuickLookTrigger trigger) => breadcrumbs(
    'quick_look.opened',
    {'source': source.name, 'trigger': trigger.name},
  );

  /// No panel opened. [reason] is a `MediaFailure` name or `unavailable`.
  void failed(
    QuickLookSource source,
    QuickLookTrigger trigger, {
    required QuickLookStage stage,
    required String reason,
  }) {
    breadcrumbs('quick_look.failed', {
      'source': source.name,
      'trigger': trigger.name,
    });
    try {
      events('quick_look.failed', {'stage': stage.name, 'reason': reason});
    } on Object {
      // A broken exporter must not break a preview.
    }
  }
}
