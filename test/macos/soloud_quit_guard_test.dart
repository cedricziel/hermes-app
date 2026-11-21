import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// flutter_soloud's macOS plugin calls a symbol of a library that is not
/// loaded until Dart uses SoLoud when the app quits, and crashes. Every engine
/// that registers the plugin must have its quit observer removed.
void main() {
  final window = File('macos/Runner/MainFlutterWindow.swift')
      .readAsStringSync();
  final registrant = File('macos/Flutter/GeneratedPluginRegistrant.swift')
      .readAsStringSync();

  test(
    'the Runner disarms the plugin right after every generated registration',
    () {
      final calls = RegExp(
        r'RegisterGeneratedPlugins\(registry: (\w+)\)\n\s*SoloudTerminationGuard\.disarm\(in: \1\)',
      ).allMatches(window).length;
      final all = RegExp(r'RegisterGeneratedPlugins\(')
          .allMatches(window)
          .length;
      expect(all, greaterThan(0));
      expect(
        calls,
        all,
        reason: 'every RegisterGeneratedPlugins is followed by the guard',
      );
      for (final file in Directory(
        'macos/Runner',
      ).listSync().whereType<File>()) {
        if (!file.path.endsWith('.swift') ||
            file.path.endsWith('MainFlutterWindow.swift')) {
          continue;
        }
        final text = file.readAsStringSync();
        expect(
          text,
          isNot(contains('RegisterGeneratedPlugins(')),
          reason: file.path,
        );
        expect(
          text,
          isNot(contains('"FlutterSoloudPlugin"')),
          reason: file.path,
        );
      }
    },
  );

  test('the guard looks up the plugin by the key the registrant uses', () {
    expect(registrant, contains('registrar(forPlugin: "FlutterSoloudPlugin")'));
    expect(window, contains('static let pluginKey = "FlutterSoloudPlugin"'));
    expect(window, contains('registry.valuePublished(byPlugin: pluginKey)'));
    expect(
      window,
      contains(
        'removeObserver(\n      instance, name: NSApplication.willTerminateNotification, object: nil)',
      ),
    );
  });

  test('the conversation windows do not register the plugin by hand', () {
    expect(window, isNot(contains('forPlugin: "FlutterSoloudPlugin")\n')));
    final custom = RegExp(r'registrar\(forPlugin: "FlutterSoloudPlugin"\)')
        .allMatches(window);
    expect(custom, isEmpty);
  });

  test('AppDelegate does not call a FlutterAppDelegate method it lacks', () {
    final delegate = File('macos/Runner/AppDelegate.swift').readAsStringSync();
    expect(delegate, isNot(contains('super.applicationDidFinishLaunching')));
  });
}
