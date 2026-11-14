import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/l10n/l10n.dart';

/// The language tags in a plist's top-level `CFBundleLocalizations` array.
List<String> _bundleLocalizations(String plistPath) {
  final xml = File(plistPath).readAsStringSync();
  final match = RegExp(
    r'<key>CFBundleLocalizations</key>\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(xml);
  if (match == null) return const [];
  return RegExp(r'<string>([^<]*)</string>')
      .allMatches(match.group(1)!)
      .map((m) => m.group(1)!)
      .toList();
}

void main() {
  final released = kReleasedLocales.map((l) => l.toLanguageTag()).toList();

  for (final plist in ['ios/Runner/Info.plist', 'macos/Runner/Info.plist']) {
    test('$plist CFBundleLocalizations follows kReleasedLocales', () {
      expect(_bundleLocalizations(plist), released);
    });
  }
}
