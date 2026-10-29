import 'package:shared_preferences/shared_preferences.dart';

/// Whether the user chose not to be asked before taking over the screen, kept
/// per account (`accountKeyFor`, a hash of the server and the user, never the
/// server's address) as one boolean in shared preferences.
class TakeoverSetting {
  TakeoverSetting({required this.accountKey, SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final String accountKey;
  final SharedPreferencesAsync _prefs;

  String get _key => 'bot_screen.takeover.skip_confirm.$accountKey';

  /// Whether to take over without asking. Storage that cannot be read means
  /// asking.
  Future<bool> skipsConfirmation() async {
    try {
      return await _prefs.getBool(_key) ?? false;
    } on Object {
      return false;
    }
  }

  /// Remembers not to ask again. A write that fails only means being asked
  /// again.
  Future<void> skipConfirmation() async {
    try {
      await _prefs.setBool(_key, true);
    } on Object {
      return;
    }
  }
}
