import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_authenticator.dart';

const _prefsEnabledKey = 'hermes.app_lock_enabled';

/// The optional app lock: whether the user turned it on, and whether the app
/// is locked right now. Locks at launch and whenever the app leaves the
/// screen, and unlocks once the device confirms the person.
///
/// On phones the app is also covered as soon as it goes inactive: the system
/// snapshots the screen for the app switcher after Flutter has stopped
/// drawing, so a lock drawn only on leaving the screen would come too late.
///
/// The lock only hides the UI. Tokens stay in secure storage as before.
class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  AppLockController({
    DeviceAuthenticator? authenticator,
    SharedPreferencesAsync? prefs,
    bool? coverWhenInactive,
  }) : _authenticator = authenticator ?? LocalDeviceAuthenticator(),
       _prefs = prefs ?? SharedPreferencesAsync(),
       _coverWhenInactive =
           coverWhenInactive ??
           (defaultTargetPlatform == TargetPlatform.iOS ||
               defaultTargetPlatform == TargetPlatform.android) {
    WidgetsBinding.instance.addObserver(this);
  }

  final DeviceAuthenticator _authenticator;
  final SharedPreferencesAsync _prefs;
  final bool _coverWhenInactive;

  bool _enabled = false;
  bool _available = false;
  bool _loaded = false;
  bool _locked = false;
  bool _authenticating = false;
  bool _inactive = false;

  /// False until [load] has read the saved choice. The app stays covered
  /// until then so a locked app never shows its content for a moment.
  bool get loaded => _loaded;
  bool get enabled => _enabled;

  /// Whether the device can confirm the person at all. Without that the lock
  /// cannot be turned on, and a saved "on" is not enforced, so nobody is
  /// locked out of their own app.
  bool get available => _available;
  bool get locked => _locked;

  /// Whether the content is out of sight: locked, or inactive on a phone.
  bool get covered => !_loaded || _locked || _inactive;

  bool get _enforced => _enabled && _available;

  /// Whether App Lock is on, read from the saved setting, for an isolate that
  /// has no controller, such as the one that answers notification buttons.
  /// Unreadable counts as on.
  static Future<bool> savedEnabled([SharedPreferencesAsync? prefs]) async {
    try {
      return await (prefs ?? SharedPreferencesAsync()).getBool(
            _prefsEnabledKey,
          ) ??
          false;
    } on Object {
      return true;
    }
  }

  Future<void> load() async {
    final (enabled, available) = await (
      _prefs.getBool(_prefsEnabledKey),
      _authenticator.isAvailable(),
    ).wait;
    _enabled = enabled ?? false;
    _available = available;
    _loaded = true;
    _locked = _enforced;
    notifyListeners();
    if (_locked) await unlock();
  }

  /// Turning the lock on asks the device to confirm first, so a failing
  /// biometric never leaves the user locked out. Returns whether the setting
  /// now holds [value].
  Future<bool> setEnabled(bool value) async {
    if (value == _enabled) return true;
    if (value) {
      if (!_available || _authenticating) return false;
      if (!await _confirm('Confirm to turn on app lock')) return false;
    }
    _enabled = value;
    _locked = false;
    notifyListeners();
    await _prefs.setBool(_prefsEnabledKey, value);
    return true;
  }

  Future<void> unlock() async {
    if (!_locked || _authenticating) return;
    if (!await _confirm('Unlock Hermes')) return;
    _locked = false;
    notifyListeners();
  }

  Future<bool> _confirm(String reason) async {
    _authenticating = true;
    try {
      return await _authenticator.authenticate(reason);
    } finally {
      _authenticating = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_enforced && !_locked) {
          _locked = true;
          notifyListeners();
        }
      case AppLifecycleState.resumed:
        if (_inactive) {
          _inactive = false;
          notifyListeners();
        }
        unawaited(unlock());
      case AppLifecycleState.inactive:
        // The device prompt makes the app inactive too.
        if (_coverWhenInactive && _enforced && !_authenticating && !_inactive) {
          _inactive = true;
          notifyListeners();
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
