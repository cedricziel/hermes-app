import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A second `hermes-app hermes://...` must reach the running window, which
/// needs a unique GApplication, and the desktop must hand it links, which
/// needs the scheme in the .desktop file. The C++ cannot run in the test
/// shards, so these read the sources (the Xvfb run is in the PR).
void main() {
  final runner = File('linux/runner/my_application.cc').readAsStringSync();
  final packaging = File('scripts/package-linux.sh').readAsStringSync();

  test('the application is unique and handles its command line', () {
    expect(runner, isNot(contains('G_APPLICATION_NON_UNIQUE')));
    expect(runner, contains('G_APPLICATION_HANDLES_COMMAND_LINE'));
    expect(runner, contains('->command_line ='));
  });

  test('a later launch presents the existing window', () {
    expect(runner, contains('gtk_window_present'));
  });

  test('the .desktop file takes hermes:// links as an argument', () {
    expect(packaging, contains('MimeType=x-scheme-handler/hermes;'));
    expect(packaging, contains('Exec=hermes-app %u'));
  });
}
