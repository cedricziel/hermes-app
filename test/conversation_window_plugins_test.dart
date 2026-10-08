import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `MainFlutterWindow.swift` registers plugins in a conversation window's
/// engine by hand. A plugin added to the app must be sorted into one of the
/// two lists here, so none is left out of a window by accident or registered
/// in one where it does harm.
const _inConversationWindows = {
  'DesktopDropPlugin',
  'FilePickerPlugin',
  'FileSelectorPlugin',
  'OpenFilePlugin',
  'PasteboardPlugin',
  'SharedPreferencesPlugin',
  'UrlLauncherPlugin',
};

/// Main engine only: notifications take the notification centre's delegate,
/// secure storage holds the tokens a window must never read,
/// macos_window_utils is bound to the main window, record is left out
/// because a conversation window offers no voice input, and the rest is unused
/// in a conversation window.
const _mainEngineOnly = {
  'ConnectivityPlusPlugin',
  'DeviceInfoPlusMacosPlugin',
  'FlutterLocalNotificationsPlugin',
  'FlutterSecureStorageDarwinPlugin',
  'LocalAuthPlugin',
  'MacOSWindowUtilsPlugin',
  'FPPPackageInfoPlusPlugin',
  'FlutterMultiWindowPlugin',
  'RecordMacOsPlugin',
};

Set<String> _registered(String source) => {
  for (final match in RegExp(r'(\w+)\.register\(\s*with:').allMatches(source))
    match.group(1)!,
};

void main() {
  test('every app plugin is sorted for conversation windows', () {
    final generated = _registered(
      File('macos/Flutter/GeneratedPluginRegistrant.swift').readAsStringSync(),
    );

    final unsorted = generated
        .difference(_inConversationWindows)
        .difference(_mainEngineOnly);
    expect(unsorted, isEmpty, reason: 'sort new plugins into a list above');
  });

  test('conversation windows register exactly their list', () {
    final window = File('macos/Runner/MainFlutterWindow.swift')
        .readAsStringSync();
    final start = window.indexOf('func registerPlugins');
    final end = window.indexOf('\n  }', start);

    expect(_registered(window.substring(start, end)), _inConversationWindows);
  });
}
