import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _key = 'com.apple.developer.usernotifications.time-sensitive';

/// The entitlement is restricted: a build signed ad hoc and carrying it is
/// killed at launch. The Mac's Release configuration is ad hoc for a local
/// `flutter build macos --release`, so only the fastlane lane, which signs
/// with a distribution profile, adds it.
void main() {
  test('the iOS Runner carries the entitlement', () {
    final entitlements = File('ios/Runner/Runner.entitlements')
        .readAsStringSync();

    expect(entitlements, contains(_key));
  });

  test('no macOS entitlements file in the project carries it', () {
    for (final name in ['Release', 'DebugProfile']) {
      final entitlements = File('macos/Runner/$name.entitlements')
          .readAsStringSync();

      expect(entitlements, isNot(contains(_key)), reason: name);
    }
  });

  test('the fastlane lane adds it to the Mac build it signs', () {
    final fastfile = File('fastlane/Fastfile').readAsStringSync();

    expect(fastfile, contains('set_info_plist_value'));
    expect(fastfile, contains(_key));
  });
}
