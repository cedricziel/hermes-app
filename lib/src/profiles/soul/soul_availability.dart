import 'package:flutter/foundation.dart';

import '../../core/safe_notifier.dart';

/// Whether the connected server has the Personality routes, kept for the
/// connection.
///
/// Unlike Files there is no probe: the entry points are shown until a read
/// answers with a missing route (a 404 that does not name the profile, or a
/// 405), and are hidden for the rest of the connection after that. A new API
/// client is a new connection and starts shown again (see
/// `soulAvailabilityProvider`). A failed read of any other kind never hides
/// them.
class SoulAvailability extends ChangeNotifier with SafeNotifier {
  SoulAvailability({this.connection});

  /// What this answer is for: the API client of the connection.
  final Object? connection;

  var _unsupported = false;

  /// Whether the Personality row and section show.
  bool get shown => !_unsupported;

  /// The server answered a Personality route with a missing-route status.
  void markUnsupported() {
    if (_unsupported || disposed) return;
    _unsupported = true;
    notifyListeners();
  }
}
