import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsEnabledKey = 'hermes.notifications_enabled';
const _prefsAskedKey = 'hermes.notifications_permission_asked';
const _prefsDeniedKey = 'hermes.notifications_permission_denied';

/// Whether the user wants notifications, and what the system said when the
/// app asked for permission. Kept across launches.
class NotificationSettings extends ChangeNotifier {
  NotificationSettings({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  bool _enabled = true;
  bool _asked = false;
  bool _denied = false;
  int _edits = 0;
  Future<void> _lastWrite = Future.value();

  bool get enabled => _enabled;
  bool get permissionAsked => _asked;
  bool get permissionDenied => _denied;

  Future<void> load() async {
    final editsBefore = _edits;
    final enabled = await _prefs.getBool(_prefsEnabledKey);
    final asked = await _prefs.getBool(_prefsAskedKey);
    final denied = await _prefs.getBool(_prefsDeniedKey);
    if (_edits != editsBefore) return;
    _enabled = enabled ?? true;
    _asked = asked ?? false;
    _denied = denied ?? false;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) =>
      _change(() => _enabled = value, {_prefsEnabledKey: value});

  Future<void> recordPermission({required bool granted}) => _change(() {
    _asked = true;
    _denied = !granted;
  }, {_prefsAskedKey: true, _prefsDeniedKey: !granted});

  Future<void> _change(void Function() apply, Map<String, bool> values) {
    _edits++;
    apply();
    notifyListeners();
    return _lastWrite = _lastWrite.catchError((_) {}).then((_) async {
      for (final entry in values.entries) {
        await _prefs.setBool(entry.key, entry.value);
      }
    });
  }
}
