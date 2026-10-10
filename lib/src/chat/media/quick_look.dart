import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The channel `macos/Runner/QuickLookPanel.swift` listens on.
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
  /// Whether this platform has a panel to show. When false, nothing in the
  /// app offers a preview.
  bool get available;

  /// Shows the file at [path], replacing what the panel shows if it is open.
  /// False when it could not be shown, for instance because the file is gone.
  Future<bool> preview(String path);

  /// Closes the panel when it shows the file at [path], and shows it
  /// otherwise.
  Future<QuickLookToggle> toggle(String path);

  /// Closes the panel. Safe when it is not open.
  Future<void> close();
}

/// The Quick Look of platforms that have none, and of tests that do not care.
class NoQuickLook implements QuickLook {
  const NoQuickLook();

  @override
  bool get available => false;

  @override
  Future<bool> preview(String path) async => false;

  @override
  Future<QuickLookToggle> toggle(String path) async => QuickLookToggle.failed;

  @override
  Future<void> close() async {}
}

/// Drives the macOS Quick Look panel over [quickLookChannelName]. Every
/// engine that shows attachments gets one; they all reach the same panel.
class MethodChannelQuickLook implements QuickLook {
  const MethodChannelQuickLook([
    this._channel = const MethodChannel(quickLookChannelName),
  ]);

  final MethodChannel _channel;

  /// Whether this platform has the panel: macOS only.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  bool get available => supported;

  @override
  Future<bool> preview(String path) async {
    try {
      return await _channel.invokeMethod<bool>('preview', {'path': path}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<QuickLookToggle> toggle(String path) async {
    try {
      final answer = await _channel.invokeMethod<Object>('toggle', {
        'path': path,
      });
      return switch (answer) {
        'shown' => QuickLookToggle.shown,
        'closed' => QuickLookToggle.closed,
        _ => QuickLookToggle.failed,
      };
    } on PlatformException {
      return QuickLookToggle.failed;
    } on MissingPluginException {
      return QuickLookToggle.failed;
    }
  }

  @override
  Future<void> close() async {
    try {
      await _channel.invokeMethod<void>('close');
    } on PlatformException {
      // Nothing to close.
    } on MissingPluginException {
      // Nothing to close.
    }
  }
}

/// The Quick Look of this platform: the panel on macOS, none elsewhere.
QuickLook platformQuickLook() => MethodChannelQuickLook.supported
    ? const MethodChannelQuickLook()
    : const NoQuickLook();
