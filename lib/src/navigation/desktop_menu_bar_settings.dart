import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../settings/report_unreadable_prefs.dart';
import 'keyboard_shortcuts.dart';

const _prefsEnabledKey = 'desktopMenuBar.enabled';

/// Whether the menu bar of Windows and Linux is shown, kept across launches.
/// Off by default: without it the chat keeps its height, and F1 lists the
/// commands.
class DesktopMenuBarSettings extends ChangeNotifier {
  DesktopMenuBarSettings({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  /// Whether [platform] has a menu bar to switch: the platforms that bind the
  /// desktop chords, which have no native menu bar of their own.
  static bool offeredOn(TargetPlatform platform) =>
      !kIsWeb && bindsDesktopChords(platform);

  final SharedPreferencesAsync _prefs;
  var _enabled = false;
  var _edits = 0;

  bool get enabled => _enabled;

  Future<void> load() async {
    final editsBefore = _edits;
    final saved = await readSaved(
      () => _prefs.getBool(_prefsEnabledKey),
      'the saved menu bar choice',
    );
    if (_edits != editsBefore) return;
    final value = saved ?? false;
    if (value == _enabled) return;
    _enabled = value;
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
