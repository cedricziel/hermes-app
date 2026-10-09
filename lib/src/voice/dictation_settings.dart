import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsEngineKey = 'hermes.dictation_engine';

/// Who turns dictated speech into text.
enum DictationEngine {
  /// The chat profile's speech-to-text provider on the Hermes server.
  hermes,

  /// The operating system's recognizer; speech never leaves the device.
  device,
}

/// The user's dictation engine, for every profile and server. Hermes until
/// they pick another; kept across launches.
class DictationSettings extends ChangeNotifier {
  DictationSettings({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _prefs;

  var _engine = DictationEngine.hermes;
  var _loaded = false;
  var _picks = 0;
  Future<void> _lastWrite = Future.value();

  DictationEngine get engine => _engine;

  /// False until [load] read the saved engine or the user picked one;
  /// [engine] is only the default before that.
  bool get loaded => _loaded;

  Future<void> load() async {
    final picksBefore = _picks;
    final saved = await _prefs.getString(_prefsEngineKey);
    if (_picks != picksBefore) return;
    _engine =
        DictationEngine.values.asNameMap()[saved] ?? DictationEngine.hermes;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setEngine(DictationEngine engine) {
    _picks++;
    if (engine != _engine || !_loaded) {
      _engine = engine;
      _loaded = true;
      notifyListeners();
    }
    return _lastWrite = _lastWrite
        .catchError((_) {})
        .then((_) => _prefs.setString(_prefsEngineKey, engine.name));
  }
}
