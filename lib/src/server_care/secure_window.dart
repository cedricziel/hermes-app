import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Marks the Android window secure (`FLAG_SECURE`: no screenshots, no
/// recents thumbnail) while a page that shows server logs is on screen.
///
/// Pages [hold] it and call the returned function when they leave; the flag
/// stays set until every holder has let go. Other platforms have no such
/// flag (iOS and Android also blank the page while the app is inactive, see
/// `PrivateSurface`), so there it does nothing. It never throws.
class SecureWindow {
  SecureWindow({MethodChannel? channel, this.platform})
    : _channel = channel ?? const MethodChannel('hermes_app/secure_window');

  final MethodChannel _channel;

  /// The platform to act for; the running one when null.
  final TargetPlatform? platform;
  int _holders = 0;

  /// The window process-wide: one Activity, so one set of holders.
  static final SecureWindow instance = SecureWindow();

  bool get _supported =>
      !kIsWeb && (platform ?? defaultTargetPlatform) == TargetPlatform.android;

  /// Sets the flag; the returned function lets go of it, once.
  VoidCallback hold() {
    var held = true;
    if (++_holders == 1) _send(true);
    return () {
      if (!held) return;
      held = false;
      if (--_holders == 0) _send(false);
    };
  }

  Future<void> _send(bool secure) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on Object {
      // A window that cannot be marked is no reason to break the page.
    }
  }
}
