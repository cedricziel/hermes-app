import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/report_unreadable_prefs.dart';
import '../telemetry/breadcrumbs.dart';

const _prefsEnabledKey = 'hermes.spotlight';

/// Whether recent chats appear in Spotlight. Saved choices survive launches.
class SpotlightSettings extends ChangeNotifier {
  SpotlightSettings({
    SharedPreferencesAsync? prefs,
    this.breadcrumbs = Breadcrumbs.none,
  }) : _prefs = prefs ?? SharedPreferencesAsync();

  /// Platforms with native Spotlight indexing.
  static bool get offered =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  final SharedPreferencesAsync _prefs;
  final Breadcrumbs breadcrumbs;

  var _enabled = false;
  var _loaded = false;
  var _edits = 0;
  Future<void> _lastWrite = Future.value();

  /// False until [load] has read the saved choice; [enabled] is the default
  /// until then.
  bool get loaded => _loaded;
  bool get enabled => _enabled;

  Future<void> load() async {
    final editsBefore = _edits;
    // Chat titles go into the system index only when the user's choice is
    // known: an unreadable store means off.
    final saved = await readSaved(
      () => _prefs.getBool(_prefsEnabledKey),
      'the saved Spotlight choice',
      ifUnreadable: false,
    );
    if (_edits == editsBefore) _enabled = saved ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) {
    if (value == _enabled && _loaded) return _lastWrite;
    _edits++;
    _enabled = value;
    _loaded = true;
    breadcrumbs('spotlight.toggled', {'enabled': value});
    notifyListeners();
    return _lastWrite = _lastWrite
        .catchError((_) {})
        .then((_) => _prefs.setBool(_prefsEnabledKey, value));
  }
}
