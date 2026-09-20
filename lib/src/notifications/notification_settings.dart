import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsEnabledKey = 'hermes.notifications_enabled';
const _prefsAskedKey = 'hermes.notifications_permission_asked';
const _prefsDeniedKey = 'hermes.notifications_permission_denied';
const _prefsSchedulesKey = 'hermes.notifications_schedules';
const _prefsMutedKey = 'hermes.notifications_muted_jobs';

/// Whether the user wants notifications, and what the system said when the
/// app asked for permission. Kept across launches.
class NotificationSettings extends ChangeNotifier {
  NotificationSettings({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  bool _enabled = true;
  bool _asked = false;
  bool _denied = false;
  bool _loaded = false;
  bool _scheduleAlerts = true;
  Set<String> _muted = {};
  int _scheduleEdits = 0;
  int _mutedEdits = 0;
  int _enabledEdits = 0;
  int _permissionEdits = 0;
  Future<void> _lastWrite = Future.value();

  /// False until [load] has read the saved values; [enabled] and the
  /// permission flags are only defaults before that.
  bool get loaded => _loaded;
  bool get enabled => _enabled;
  bool get permissionAsked => _asked;
  bool get permissionDenied => _denied;

  /// Whether a scheduled task that ran is announced.
  bool get scheduleAlerts => _scheduleAlerts;

  /// Whether the job [key] (`profile/id`) is muted.
  bool isMuted(String key) => _muted.contains(key);

  Future<void> load() async {
    // Every counter is read before the first await, so an edit made while
    // any of the values is being read wins over what was stored.
    final enabledEditsBefore = _enabledEdits;
    final permissionEditsBefore = _permissionEdits;
    final scheduleEditsBefore = _scheduleEdits;
    final mutedEditsBefore = _mutedEdits;
    final enabled = await _prefs.getBool(_prefsEnabledKey);
    final asked = await _prefs.getBool(_prefsAskedKey);
    final denied = await _prefs.getBool(_prefsDeniedKey);
    final schedules = await _prefs.getBool(_prefsSchedulesKey);
    final muted = await _prefs.getStringList(_prefsMutedKey);
    if (_enabledEdits == enabledEditsBefore) _enabled = enabled ?? true;
    if (_permissionEdits == permissionEditsBefore) {
      _asked = asked ?? false;
      _denied = denied ?? false;
    }
    if (_scheduleEdits == scheduleEditsBefore) {
      _scheduleAlerts = schedules ?? true;
    }
    if (_mutedEdits == mutedEditsBefore) _muted = {...?muted};
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) => _change(() {
    _enabledEdits++;
    _enabled = value;
  }, {_prefsEnabledKey: value});

  Future<void> setScheduleAlerts(bool value) => _change(() {
    _scheduleEdits++;
    _scheduleAlerts = value;
  }, {_prefsSchedulesKey: value});

  Future<void> setMuted(String key, bool muted) {
    if (isMuted(key) == muted) return _lastWrite;
    return _change(() {
      _mutedEdits++;
      muted ? _muted.add(key) : _muted.remove(key);
    }, {_prefsMutedKey: null});
  }

  /// Drops the mutes of jobs that no longer exist. [existing] is the keys of
  /// every job the server has.
  Future<void> forgetMutes(Set<String> existing) {
    if (_muted.every(existing.contains)) return _lastWrite;
    return _change(() {
      _mutedEdits++;
      _muted.retainAll(existing);
    }, {_prefsMutedKey: null});
  }

  Future<void> recordPermission({required bool granted}) => _change(() {
    _permissionEdits++;
    _asked = true;
    _denied = !granted;
  }, {_prefsAskedKey: true, _prefsDeniedKey: !granted});

  /// Applies [apply], tells listeners, and saves [values] after the earlier
  /// writes. A `null` value stands for the muted set, saved as it is now.
  Future<void> _change(void Function() apply, Map<String, Object?> values) {
    apply();
    notifyListeners();
    return _lastWrite = _lastWrite.catchError((_) {}).then((_) async {
      for (final entry in values.entries) {
        final value = entry.value;
        if (value is bool) {
          await _prefs.setBool(entry.key, value);
        } else {
          await _prefs.setStringList(entry.key, _muted.toList()..sort());
        }
      }
    });
  }
}
