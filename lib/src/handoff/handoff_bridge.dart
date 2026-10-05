import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'handoff_activity.dart';

class HandoffBridge {
  HandoffBridge({bool? enabled})
    : enabled =
          enabled ??
          (!kIsWeb &&
              {
                TargetPlatform.iOS,
                TargetPlatform.macOS,
              }.contains(defaultTargetPlatform)) {
    if (this.enabled) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'incoming') onIncoming?.call(await take());
        if (call.method == 'failed') onIncoming?.call(const {'error': true});
      });
    }
  }
  final bool enabled;
  static const _channel = MethodChannel('hermes_app/handoff');
  void Function(Object?)? onIncoming;

  Future<Object?> take() async {
    if (!enabled) return null;
    try {
      return await _channel.invokeMethod<Object?>('take');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<void> publish(HandoffActivity? activity) async {
    if (!enabled) return;
    try {
      await _channel.invokeMethod<void>(
        activity == null ? 'clear' : 'publish',
        activity?.payload,
      );
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }

  void dispose() {
    onIncoming = null;
    if (enabled) _channel.setMethodCallHandler(null);
  }
}
