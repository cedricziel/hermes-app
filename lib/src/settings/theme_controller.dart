import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsThemeModeKey = 'hermes.theme_mode';

/// The user's light/dark choice. Follows the system until they pick one, and
/// keeps the pick across launches.
class ThemeController extends ChangeNotifier {
  ThemeController({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    final saved = await _prefs.getString(_prefsThemeModeKey);
    final mode = ThemeMode.values.asNameMap()[saved] ?? ThemeMode.system;
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _prefs.setString(_prefsThemeModeKey, mode.name);
  }
}
