import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/files/widgets/file_size.dart';

import 'files_widget_harness.dart';

void main() {
  final en = l10nFor('en');
  final de = l10nFor('de');

  group('formatByteSize', () {
    test('writes bytes below one kilobyte, with a plural', () {
      expect(formatByteSize(en, 0), '0 bytes');
      expect(formatByteSize(en, 1), '1 byte');
      expect(formatByteSize(en, 512), '512 bytes');
      expect(formatByteSize(en, 1023), '1,023 bytes');
    });

    test('writes one decimal below ten and none from there', () {
      expect(formatByteSize(en, 1024), '1 KB');
      expect(formatByteSize(en, 1834), '1.8 KB');
      expect(formatByteSize(en, 512 * 1024), '512 KB');
      expect(formatByteSize(en, 3355443), '3.2 MB');
      expect(formatByteSize(en, 2516582), '2.4 MB');
      expect(formatByteSize(en, 14 * 1024 * 1024), '14 MB');
      expect(formatByteSize(en, 222298112), '212 MB');
      expect(formatByteSize(en, 3 * 1024 * 1024 * 1024), '3 GB');
    });

    test('counts in steps of 1,024 and never writes 1024 KB', () {
      expect(formatByteSize(en, 1024 * 1024 - 1), '1 MB');
      expect(formatByteSize(en, 1000 * 1024), '1,000 KB');
      expect(formatByteSize(en, 1048000), '1,023 KB');
    });

    test('follows the locale for separators and words', () {
      expect(formatByteSize(de, 1834), '1,8 KB');
      expect(formatByteSize(de, 1), '1 Byte');
      expect(formatByteSize(de, 512), '512 Byte');
      expect(formatByteSize(de, 1023), '1.023 Byte');
      expect(formatByteSize(de, 3355443), '3,2 MB');
    });

    test('treats a negative size as zero', () {
      expect(formatByteSize(en, -5), '0 bytes');
    });
  });

  group('byteUnitFor', () {
    test('picks the largest unit that is at least one', () {
      expect(byteUnitFor(1023), ByteUnit.bytes);
      expect(byteUnitFor(1024), ByteUnit.kilobytes);
      expect(byteUnitFor(5 * 1024 * 1024), ByteUnit.megabytes);
      expect(byteUnitFor(2 * 1024 * 1024 * 1024), ByteUnit.gigabytes);
    });
  });

  group('formatDownloadProgress', () {
    test('writes the unit once, in the total unit', () {
      expect(
        formatDownloadProgress(en, 14 * 1024 * 1024, 30 * 1024 * 1024),
        'Downloading… 14 of 30 MB',
      );
      expect(
        formatDownloadProgress(de, 1024 * 1024, 30 * 1024 * 1024),
        'Wird heruntergeladen … 1 von 30 MB',
      );
    });

    test('keeps a decimal for a small total', () {
      expect(
        formatDownloadProgress(en, 512 * 1024, 3355443),
        'Downloading… 0.5 of 3.2 MB',
      );
    });
  });
}
