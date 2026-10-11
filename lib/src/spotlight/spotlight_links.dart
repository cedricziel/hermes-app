import 'dart:async';

import 'package:flutter_otel/flutter_otel.dart'
    show AppEventLogger, noopAppEventLogger;

import '../deep_links/deep_link_parser.dart';
import '../deep_links/deep_link_target.dart';
import 'spotlight_index.dart';

/// [links], the `hermes://` links the system delivers, together with the
/// links of Spotlight results: the one that launched the app and every one
/// tapped while it runs. A tapped result opens like a tapped link, wherever
/// the app is.
///
/// Anything that is not a `hermes` link is dropped. An opened result is
/// logged with its kind (`spotlight.domain`) only.
Stream<Uri> linksWithSpotlight(
  Stream<Uri> links,
  SpotlightIndex index, {
  AppEventLogger events = noopAppEventLogger,
}) {
  late final StreamController<Uri> merged;
  final subscriptions = <StreamSubscription<Uri>>[];

  void result(Uri uri) {
    if (!isHermesLink(uri)) return;
    try {
      events('spotlight.opened', {
        'spotlight.domain': parseDeepLink(uri)?.kind ?? 'unknown',
      });
    } on Object {
      // Telemetry must not break the app.
    }
    merged.add(uri);
  }

  merged = StreamController<Uri>(
    sync: true,
    onListen: () {
      subscriptions
        ..add(links.listen(merged.add, onError: merged.addError))
        ..add(index.opened.listen(result));
      unawaited(
        index.takeLaunch().then((launch) {
          if (launch != null && !merged.isClosed) result(launch);
        }),
      );
    },
    onCancel: () async {
      await Future.wait([for (final s in subscriptions) s.cancel()]);
      await merged.close();
    },
  );
  return merged.stream;
}
