import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/notifications/local_notification_service.dart';

/// The adaptive launcher icon is opaque, so as a notification's small icon it
/// shows as a white square in the status bar.
void main() {
  test('the status bar icon is a drawable, not the launcher mipmap', () {
    expect(kAndroidStatusIcon, '@drawable/ic_stat_hermes');
  });

  test('the drawable exists and is white on transparent', () {
    final file = File('android/app/src/main/res/drawable/ic_stat_hermes.xml');

    expect(file.existsSync(), isTrue);
    final xml = file.readAsStringSync();
    expect(xml, contains('<vector'));
    expect(xml, contains('#FFFFFFFF'));
  });

  test('resource shrinking keeps it', () {
    final keep = File('android/app/src/main/res/raw/keep.xml')
        .readAsStringSync();

    expect(keep, contains('@drawable/ic_stat_hermes'));
  });
}
