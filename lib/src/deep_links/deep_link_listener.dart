import 'dart:async';

import 'package:flutter/widgets.dart';

import '../telemetry/breadcrumbs.dart';
import 'deep_link_parser.dart';
import 'deep_link_target.dart';

/// A link the shell has not acted on yet.
class PendingDeepLink {
  const PendingDeepLink(this.target, {required this.cold});

  final DeepLinkTarget target;

  /// Whether the link launched the app, for the breadcrumb.
  final bool cold;
}

/// Receives `hermes://` links and keeps the latest one until the shell takes
/// it.
///
/// It lives above the screens, so a link that arrives on the setup or sign-in
/// screen waits there for [AppShell] to mount. Signing out drops it, so a
/// link does not leak into the next session.
class DeepLinks extends ChangeNotifier {
  /// [links] is where the platform delivers them (`AppLinks().uriLinkStream`
  /// in the app). [firstFrame] completes once the app is on screen; a link
  /// received before then launched it.
  DeepLinks({
    required Stream<Uri> links,
    Stream<void>? signedOut,
    Future<void>? firstFrame,
    this.breadcrumbs = Breadcrumbs.none,
  }) {
    var shown = false;
    unawaited(
      (firstFrame ?? WidgetsBinding.instance.waitUntilFirstFrameRasterized)
          .then((_) => shown = true),
    );
    _shown = () => shown;
    _links = links.listen(
      (uri) => open(uri),
      onError: (Object _) => _ignored('malformed'),
    );
    _signedOut = signedOut?.listen((_) => _drop());
  }

  final Breadcrumbs breadcrumbs;
  late final StreamSubscription<Uri> _links;
  StreamSubscription<void>? _signedOut;
  late final bool Function() _shown;
  var _first = true;
  PendingDeepLink? _pending;

  PendingDeepLink? get pending => _pending;

  /// Takes a link from another source than [links], such as an app icon
  /// quick action, as if the platform had delivered it. Returns what the
  /// shell will act on, or null when the link was ignored.
  PendingDeepLink? open(Uri uri) {
    if (!isHermesLink(uri)) return null;
    final cold = _first && !_shown();
    _first = false;
    final target = parseDeepLink(uri);
    if (target == null) {
      _ignored(deepLinkIgnoredReason(uri));
      return null;
    }
    final link = _pending = PendingDeepLink(target, cold: cold);
    notifyListeners();
    return link;
  }

  void _ignored(String reason) =>
      breadcrumbs('deeplink.ignored', {'reason': reason});

  void _drop() {
    if (_pending == null) return;
    _pending = null;
    notifyListeners();
  }

  /// Hands the waiting link over and forgets it.
  PendingDeepLink? take() {
    final link = _pending;
    _pending = null;
    return link;
  }

  @override
  void dispose() {
    unawaited(_links.cancel());
    unawaited(_signedOut?.cancel());
    super.dispose();
  }
}
