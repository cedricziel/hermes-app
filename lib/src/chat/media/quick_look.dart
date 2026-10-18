import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The channel the macOS Quick Look panel and iOS photo preview listen on.
const quickLookChannelName = 'hermes_app/quick_look';

/// What [QuickLook.toggle] did.
enum QuickLookToggle {
  /// The panel is showing the file now.
  shown,

  /// The panel was showing this file and is closed.
  closed,

  /// The panel could not show the file.
  failed,
}

/// The system's Quick Look panel, behind an interface so tests need no
/// platform.
abstract interface class QuickLook {
  /// Shows the file at [path], replacing what the panel shows if it is open.
  /// False when it could not be shown, for instance because the file is gone.
  Future<bool> preview(String path);

  /// Closes the panel when it shows the file at [path], and shows it
  /// otherwise.
  Future<QuickLookToggle> toggle(String path);

  /// Closes the panel. Safe when it is not open.
  Future<void> close();

  /// The time the system allows between the two presses of a double-click, or
  /// null when it cannot say.
  Future<Duration?> doubleClickInterval();
}

/// How long may pass between the two presses of a double-click. The system's
/// setting on macOS (see [readDoubleClickInterval]), half a second until that
/// is known or where it is not.
Duration doubleClickInterval = const Duration(milliseconds: 500);

/// Asks [quickLook] for the system's double-click interval and keeps it in
/// [doubleClickInterval]. Keeps the default when it cannot say.
Future<void> readDoubleClickInterval(QuickLook quickLook) async {
  final interval = await quickLook.doubleClickInterval();
  if (interval != null && interval > Duration.zero) {
    doubleClickInterval = interval;
  }
}

/// The Quick Look of platforms that have none, and of tests that do not care.
class NoQuickLook implements QuickLook {
  const NoQuickLook();

  @override
  Future<bool> preview(String path) async => false;

  @override
  Future<QuickLookToggle> toggle(String path) async => QuickLookToggle.failed;

  @override
  Future<void> close() async {}

  @override
  Future<Duration?> doubleClickInterval() async => null;
}

/// Drives the macOS Quick Look panel over [quickLookChannelName]. Every
/// engine that shows attachments gets one; they all reach the same panel.
class MethodChannelQuickLook implements QuickLook {
  const MethodChannelQuickLook([
    this._channel = const MethodChannel(quickLookChannelName),
  ]);

  final MethodChannel _channel;

  /// Whether this platform has native Quick Look: a panel on macOS or a
  /// dismissible preview with system sharing on iOS.
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// What the panel answered, or null when it could not (a platform error, or
  /// an engine that never installed the channel).
  Future<Object?> _call(String method, [Map<String, String>? arguments]) async {
    try {
      return await _channel.invokeMethod<Object>(method, arguments);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> preview(String path) async =>
      await _call('preview', {'path': path}) == true;

  @override
  Future<QuickLookToggle> toggle(String path) async =>
      switch (await _call('toggle', {'path': path})) {
        'shown' => QuickLookToggle.shown,
        'closed' => QuickLookToggle.closed,
        _ => QuickLookToggle.failed,
      };

  @override
  Future<void> close() async {
    await _call('close');
  }

  @override
  Future<Duration?> doubleClickInterval() async {
    final seconds = await _call('doubleClickInterval');
    return seconds is num
        ? Duration(microseconds: (seconds * 1e6).round())
        : null;
  }
}

/// The Quick Look of this platform: a Mac panel or iOS preview sheet.
///
/// A Mac engine also reads the system's double-click interval once.
QuickLook platformQuickLook() {
  if (!MethodChannelQuickLook.supported) return const NoQuickLook();
  const quickLook = MethodChannelQuickLook();
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    unawaited(readDoubleClickInterval(quickLook));
  }
  return quickLook;
}
