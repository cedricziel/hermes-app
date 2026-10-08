/// Decides which of the frames the app does not show are reported to
/// telemetry, so a new Hermes frame type shows up once without flooding the
/// log. One instance covers one connection.
///
/// Only the type is ever kept: a payload can hold the user's text.
class UnmappedEvents {
  /// The longest type that is reported whole.
  static const maxLength = 64;

  /// How many distinct types one connection reports before the rest are
  /// counted as [overflow].
  static const maxTypes = 20;

  /// What the types past [maxTypes] are reported as.
  static const overflow = 'other';

  final _reported = <String>{};
  var _overflowed = false;

  /// The type to report for a frame of [type], or null when it is expected
  /// noise or its type was reported on this connection already.
  String? admit(String type) {
    if (_expected(type)) return null;
    final cut = type.length > maxLength ? type.substring(0, maxLength) : type;
    if (_reported.contains(cut)) return null;
    if (_reported.length < maxTypes) {
      _reported.add(cut);
      return cut;
    }
    if (_overflowed) return null;
    _overflowed = true;
    return overflow;
  }

  /// Frames Hermes sends to every client, which the app has no use for.
  static bool _expected(String type) =>
      type == 'gateway.ready' ||
      type == 'session.usage' ||
      type.endsWith('.changed') ||
      type.startsWith('notification.');
}
