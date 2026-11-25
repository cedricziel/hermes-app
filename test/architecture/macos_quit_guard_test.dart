import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// flutter_soloud's macOS plugin observes NSApplicationWillTerminate and calls
/// a symbol of a library that is not loaded until Dart uses SoLoud, so every
/// quit crashed (F.381). The Runner replaces that observer after each
/// `RegisterGeneratedPlugins`; the line lives in a tracked Runner file, not in
/// the regenerated registrant, so these scans keep it there. The launch-and-
/// quit step of the macOS job in ci.yml is the behavioural check.
void main() {
  String read(String path) => File(path).readAsStringSync();

  final window = read('macos/Runner/MainFlutterWindow.swift');

  test(
    'every RegisterGeneratedPlugins in the Runner is followed by the guard',
    () {
      final registrations = RegExp(
        r'RegisterGeneratedPlugins\(registry: (\w+)\)',
      ).allMatches(window).toList();
      expect(registrations, isNotEmpty);
      final guarded = RegExp(
        r'RegisterGeneratedPlugins\(registry: (\w+)\)\n\s*SoloudTerminationGuard\.disarm\(in: \1\)',
      ).allMatches(window).length;
      expect(
        guarded,
        registrations.length,
        reason:
            'put SoloudTerminationGuard.disarm(in: <controller>) right after '
            'each RegisterGeneratedPlugins call in MainFlutterWindow.swift',
      );
      for (final file in Directory(
        'macos/Runner',
      ).listSync().whereType<File>()) {
        if (!file.path.endsWith('.swift') ||
            file.path.endsWith('MainFlutterWindow.swift')) {
          continue;
        }
        expect(
          read(file.path),
          isNot(contains('RegisterGeneratedPlugins(')),
          reason: '${file.path} registers plugins without the guard',
        );
      }
    },
  );

  test('the guard finds the plugin by the key the registrant uses', () {
    final registrant = read('macos/Flutter/GeneratedPluginRegistrant.swift');
    expect(
      registrant,
      contains('registrar(forPlugin: "FlutterSoloudPlugin")'),
      reason: 'the plugin is gone or renamed: drop or update the guard',
    );
    expect(window, contains('static let pluginKey = "FlutterSoloudPlugin"'));
    expect(window, contains('registry.valuePublished(byPlugin: pluginKey)'));
  });

  test('the guard calls the plugin handler only once the library resolved', () {
    expect(
      window,
      matches(
        RegExp(
          r'removeObserver\(\s*instance,\s*name:\s*NSApplication\.willTerminateNotification,\s*object:\s*nil\s*\)',
        ),
      ),
      reason: "the plugin's own observer must be removed",
    );
    expect(
      window,
      contains(
        '!(instance is NSNull), instance.responds(to: terminateSelector)',
      ),
      reason: 'NSNull (a plugin that published nothing) is not the plugin',
    );
    expect(
      window,
      contains('static let librarySymbol = "soloud_vst3HostUnloadAll"'),
    );
    expect(window, contains('guard libraryLoaded() else { return }'));
  });

  test('nothing registers the plugin by hand outside the registrant', () {
    for (final file in Directory('macos/Runner').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.swift')) continue;
      expect(
        read(file.path),
        isNot(contains('FlutterSoloudPlugin.register')),
        reason: '${file.path} registers the plugin by hand',
      );
    }
  });

  test(
    'the app delegate does not call a FlutterAppDelegate method it lacks',
    () {
      expect(
        read('macos/Runner/AppDelegate.swift'),
        isNot(contains('super.applicationDidFinishLaunching')),
      );
    },
  );

  test('the macOS job launches and quits the built app', () {
    final ci = read('.github/workflows/ci.yml');
    expect(ci, contains('name: Launch the app and quit it normally'));
    expect(ci, contains('HERMES_QUIT_AFTER_LAUNCH=1'));
    expect(
      read('macos/Runner/AppDelegate.swift'),
      contains('"HERMES_QUIT_AFTER_LAUNCH"'),
    );
  });
}
