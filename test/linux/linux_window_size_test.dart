import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Linux window opens at 1280 x 720, clamped to 90 percent of the work
/// area, centred, and cannot shrink below 360 x 480. The C++ lives in
/// `linux/runner/` and has no test shard, so the first group pins the source
/// and the second compiles the pure function when a C++ compiler exists.
void main() {
  final header = File('linux/runner/window_size.h').readAsStringSync();
  final runner = File('linux/runner/my_application.cc').readAsStringSync();

  group('source', () {
    test('the constants are the design brief\'s', () {
      expect(header, contains('kMinWindowWidth = 360'));
      expect(header, contains('kMinWindowHeight = 480'));
      expect(header, contains('kDefaultWindowWidth = 1280'));
      expect(header, contains('kDefaultWindowHeight = 720'));
      expect(header, contains('kMaxWorkAreaFraction = 0.9'));
    });

    test('the runner sets the minimum hint, the clamped size and centres', () {
      expect(runner, contains('GDK_HINT_MIN_SIZE'));
      expect(runner, contains('gtk_window_set_geometry_hints'));
      expect(runner, contains('min_size.min_width = kMinWindowWidth'));
      expect(runner, contains('min_size.min_height = kMinWindowHeight'));
      expect(runner, contains('gdk_monitor_get_workarea'));
      expect(runner, contains('default_window_size(work_area.width'));
      expect(runner, contains('gtk_window_set_default_size(window, size'));
      expect(runner, contains('GTK_WIN_POS_CENTER'));
      expect(runner, isNot(contains('set_default_size(window, 1280, 720)')));
    });
  });

  group('default_window_size', () {
    late Directory dir;
    late String binary;

    setUpAll(() {
      final probe = Process.runSync('which', ['g++']);
      if (probe.exitCode != 0) return;
      dir = Directory.systemTemp.createTempSync('window_size_test');
      final source = File('${dir.path}/main.cc')
        ..writeAsStringSync('''
#include <cstdio>
#include <cstdlib>
#include "window_size.h"
int main(int argc, char** argv) {
  WindowSize s = default_window_size(atoi(argv[1]), atoi(argv[2]));
  std::printf("%d x %d", s.width, s.height);
}
''');
      binary = '${dir.path}/probe';
      final build = Process.runSync('g++', [
        '-std=c++17',
        '-Ilinux/runner',
        source.path,
        '-o',
        binary,
      ]);
      expect(build.exitCode, 0, reason: '${build.stderr}');
    });

    tearDownAll(() {
      if (Process.runSync('which', ['g++']).exitCode == 0) {
        dir.deleteSync(recursive: true);
      }
    });

    String size(int w, int h) =>
        Process.runSync(binary, ['$w', '$h']).stdout as String;

    test('a large work area keeps 1280 x 720', () {
      expect(size(2560, 1400), '1280 x 720');
    });

    test('a 1366 x 768 laptop (work area 1366 x 728) opens at 1229 x 655', () {
      expect(size(1366, 728), '1229 x 655');
    });

    test('a tiny work area never goes below 360 x 480', () {
      expect(size(300, 400), '360 x 480');
    });
  }, skip: Process.runSync('which', ['g++']).exitCode == 0 ? null : 'no g++');
}
