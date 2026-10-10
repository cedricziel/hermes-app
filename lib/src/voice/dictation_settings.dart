import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'on_device_speech.dart';

const _prefsEngineKey = 'hermes.dictation_engine';

/// Who turns dictated speech into text.
enum DictationEngine {
  /// The chat profile's speech-to-text provider on the Hermes server.
  hermes,

  /// The operating system's recognizer; speech never leaves the device.
  device,
}

/// The user's dictation engine, for every profile and server: on the device
/// where the platform has a recognizer (iOS, macOS), else Hermes, until they
/// pick another; kept across launches.
class DictationSettings extends ChangeNotifier {
  DictationSettings({SharedPreferencesAsync? prefs})
    : _prefs = prefs ?? SharedPreferencesAsync();

  /// Whether this platform has an on-device engine to offer (iOS, macOS).
  static bool get offered =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static DictationEngine get _default =>
      offered ? DictationEngine.device : DictationEngine.hermes;

  final SharedPreferencesAsync _prefs;

  var _engine = _default;
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
    _engine = DictationEngine.values.asNameMap()[saved] ?? _default;
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

/// The engine that dictates when the user chose [chosen] and the device's
/// model for their language is [model]: Hermes where the device cannot
/// recognize it.
DictationEngine effectiveDictationEngine(
  DictationEngine chosen,
  OnDeviceModel? model,
) => model == OnDeviceModel.unsupported ? DictationEngine.hermes : chosen;
