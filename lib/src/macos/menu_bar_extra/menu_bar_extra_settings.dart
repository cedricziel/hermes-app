import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/report_unreadable_prefs.dart';

const _prefsEnabledKey = 'menuBarExtra.enabled';

/// Whether the menu bar item is shown (macOS), kept across launches. On by
/// default. The app runs on without a window either way.
class MenuBarExtraSettings extends ChangeNotifier {
  MenuBarExtraSettings({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  /// Whether this platform has a menu bar item to switch.
  static bool get offered =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  final SharedPreferencesAsync _prefs;
  var _enabled = true;
  var _loaded = false;
  var _edits = 0;

  /// False until [load] has read the saved choice. The item stays hidden
  /// until then, so a saved "off" never shows it for a moment.
  bool get loaded => _loaded;
  bool get enabled => _enabled;

  Future<void> load() async {
    final editsBefore = _edits;
    final saved = await readSaved(
      () => _prefs.getBool(_prefsEnabledKey),
      'the saved menu bar item choice',
    );
    if (_edits == editsBefore) _enabled = saved ?? true;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _edits++;
    if (value != _enabled) {
      _enabled = value;
      notifyListeners();
    }
    await _prefs.setBool(_prefsEnabledKey, value);
  }
}
