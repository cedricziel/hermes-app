import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Linux title bar showed the Flutter icon because the runner set none.
/// The C++ cannot run in CI's test shards, so these read the sources.
void main() {
  final runner = File('linux/runner/my_application.cc').readAsStringSync();
  final cmake = File('linux/CMakeLists.txt').readAsStringSync();
  final packaging = File('scripts/package-linux.sh').readAsStringSync();

  final appId = RegExp(r'set\(APPLICATION_ID "([^"]+)"\)')
      .firstMatch(cmake)!
      .group(1)!;

  test('the icon is set after both title paths, by the .desktop icon name', () {
    // The call must follow the `}` that closes the header bar / plain title
    // if-else, at function level, so neither branch can skip it.
    final elseAt = runner.indexOf(
      '  } else {\n    gtk_window_set_title(window',
    );
    expect(elseAt, isNonNegative);
    final closeAt = runner.indexOf('\n  }\n', elseAt);
    expect(closeAt, isNonNegative);
    final calls = RegExp(
      r'^  set_window_icon\(window\);$',
      multiLine: true,
    ).allMatches(runner).toList();

    expect(calls, hasLength(1));
    expect(calls.single.start, greaterThan(closeAt));
    expect(runner, isNot(contains('    set_window_icon(window);')));
    expect(
      runner,
      contains('gtk_window_set_icon_name(window, APPLICATION_ID)'),
    );
    expect(runner, contains('gdk_pixbuf_new_from_file_at_size(file, 256, 256'));
  });

  test('the .desktop file and the installed theme icon use the app id', () {
    expect(packaging, contains('APP_ID="$appId"'));
    expect(packaging, contains('Icon=\$APP_ID'));
    expect(packaging, contains('hicolor/512x512/apps/\$APP_ID.png'));
  });

  test('the bundle ships the PNG the fallback loads', () {
    expect(cmake, contains('design/icon-512.png'));
    expect(cmake, contains(r'${INSTALL_BUNDLE_DATA_DIR}/icons'));
    expect(cmake, contains(r'RENAME "${APPLICATION_ID}.png"'));
    expect(runner, contains(r'"data", "icons", APPLICATION_ID ".png"'));
    expect(File('design/icon-512.png').existsSync(), isTrue);
  });
}
