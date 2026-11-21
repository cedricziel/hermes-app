import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `flutter build linux` must install into the bundle directory of the build
/// tree and nowhere else. Flutter's template only redirects the prefix while it
/// is CMake's default, so a failed first configure left
/// `CMAKE_INSTALL_PREFIX=/usr/local` in the cache and the next build installed
/// the app into `/usr/local`. The build file has no test shard of its own, so
/// this scans it.
void main() {
  final cmake = File('linux/CMakeLists.txt')
      .readAsLinesSync()
      .where((line) => !line.trimLeft().startsWith('#'))
      .join('\n');

  test('the install prefix is forced to the bundle directory', () {
    final forced = RegExp(
      r'^set\(CMAKE_INSTALL_PREFIX\s+"\$\{BUILD_BUNDLE_DIR\}"\s+CACHE\s+PATH\s+"[^"]*"\s+FORCE\)',
      multiLine: true,
    );
    expect(forced.hasMatch(cmake), isTrue);
  });

  test('the prefix is not set only while it is still the default', () {
    expect(
      cmake,
      isNot(contains('CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT')),
    );
  });

  test('the bundle directory lives in the build tree', () {
    expect(
      cmake,
      contains('set(BUILD_BUNDLE_DIR "\${PROJECT_BINARY_DIR}/bundle")'),
    );
  });

  test('no other line assigns the install prefix', () {
    final sets = RegExp(r'set\(\s*CMAKE_INSTALL_PREFIX\b').allMatches(cmake);
    expect(sets, hasLength(1));
  });
}
