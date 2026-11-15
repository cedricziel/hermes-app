import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'hermes.portable_calls';

/// What the switch is before the user touches it.
const kPortableCallsDefault = false;

/// Whether the user turned voice calls on for this device, on the platforms
/// whose call audio is new (Android, macOS, Windows, Linux). iOS has always
/// had calls and never reads this. A plain device preference: kept across
/// launches, and changed by the user alone, never by sign-out, a server
/// change or a profile switch.
class PortableCallSettings extends ChangeNotifier {
  PortableCallSettings({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  /// Whether [platform] has the switch: every one but iOS (CallKit, shipped)
  /// and the web (no calls).
  static bool offeredOn(TargetPlatform platform) =>
      !kIsWeb &&
      platform != TargetPlatform.iOS &&
      platform != TargetPlatform.fuchsia;

  final SharedPreferencesAsync _prefs;
  var _enabled = kPortableCallsDefault;
  var _loaded = false;
  var _edits = 0;

  /// False until [load] read the saved choice. Calls stay off until then.
  bool get loaded => _loaded;
  bool get enabled => _loaded && _enabled;

  Future<void> load() async {
    final editsBefore = _edits;
    final saved = await _prefs.getBool(_prefsKey);
    if (_edits == editsBefore) _enabled = saved ?? kPortableCallsDefault;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _edits++;
    if (value != _enabled || !_loaded) {
      _enabled = value;
      _loaded = true;
      notifyListeners();
    }
    await _prefs.setBool(_prefsKey, value);
  }
}

/// Whether calls may start on [platform]: always on iOS, never on the web,
/// and elsewhere only when the user turned them on. [settings] is null where
/// none is provided, which counts as off.
bool callsAvailable(TargetPlatform platform, PortableCallSettings? settings) {
  if (kIsWeb) return false;
  if (platform == TargetPlatform.iOS) return true;
  return PortableCallSettings.offeredOn(platform) &&
      (settings?.enabled ?? false);
}
