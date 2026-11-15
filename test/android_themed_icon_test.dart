import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Without a `<monochrome>` layer, Android 13+ themed icons fall back to the
/// untinted launcher icon.
void main() {
  const res = 'android/app/src/main/res';

  test('the adaptive launcher icon has a monochrome layer', () {
    final xml = File('$res/mipmap-anydpi-v26/ic_launcher.xml')
        .readAsStringSync();

    expect(
      xml,
      contains(
        '<monochrome android:drawable="@drawable/ic_launcher_monochrome"/>',
      ),
    );
  });

  test('the monochrome layer is a 108dp white vector', () {
    final xml = File('$res/drawable/ic_launcher_monochrome.xml')
        .readAsStringSync();

    expect(xml, contains('android:width="108dp"'));
    expect(xml, contains('android:viewportWidth="108"'));
    expect(xml, contains('#FFFFFFFF'));
  });
}
