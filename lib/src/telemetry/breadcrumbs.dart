import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;

/// Notes what the user was doing, so a crash report shows the trail that led
/// to it.
///
/// A crumb is kept in memory and exported only inside a crash record; unlike
/// an app event it is never a log record of its own. Callers pass a fixed name
/// and coarse values (a destination, a count, an outcome), never message text,
/// a title, a profile name, a server address or an id: the same rule as for
/// `AppEventLogger`.
///
/// Recording never throws, and does nothing when telemetry is off.
class Breadcrumbs {
  const Breadcrumbs._(this._trail);

  /// Records into [trail].
  const Breadcrumbs.of(BreadcrumbTrail trail) : this._(trail);

  /// Records nothing: telemetry is off, or there is no provider above.
  static const none = Breadcrumbs._(null);

  final BreadcrumbTrail? _trail;

  void call(String name, [Map<String, Object> attributes = const {}]) {
    try {
      _trail?.record(name, attributes);
    } on Object {
      // A crumb must not take the app down with it.
    }
  }
}
