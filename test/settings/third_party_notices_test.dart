import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/settings/third_party_notices.dart';

void main() {
  test(
    'the call audio code that Flutter does not collect is registered',
    () async {
      registerCallAudioNotices();
      final entries = <LicenseEntry>[];
      await for (final entry in LicenseRegistry.licenses) {
        entries.add(entry);
      }
      String text(String package) => entries
          .where((e) => e.packages.any((p) => p.startsWith(package)))
          .expand((e) => e.paragraphs)
          .map((p) => p.text)
          .join('\n');

      expect(text('SoLoud'), contains('zlib/libpng'));
      expect(text('SoLoud'), contains('Jari Komppa'));
      expect(
        text('signalsmith-stretch'),
        contains('Permission is hereby granted'),
      );
      expect(text('signalsmith-stretch'), contains('Geraint Luff'));
      expect(text('signalsmith-linear'), contains('Signalsmith Audio'));
      expect(text('pffft'), contains('Julien Pommier'));
      expect(text('pffft'), contains('Redistributions in binary form'));
    },
  );

  test('each notice is a whole text, not a stub', () {
    expect(callAudioNotices, hasLength(4));
    for (final (names, text) in callAudioNotices) {
      expect(names, hasLength(1));
      expect(text.length, greaterThan(500), reason: names.single);
    }
  });
}
