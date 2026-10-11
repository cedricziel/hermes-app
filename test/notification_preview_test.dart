import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/notifications/notification_preview.dart';

void main() {
  test('keeps paragraphs and text inside simple formatting', () {
    expect(
      notificationPreview(
        '# Update\n\n**Done** with *care*, _italics_, ~~old~~ and `x_y`.',
      ),
      'Update\n\nDone with care, italics, old and x_y.',
    );
  });

  test('keeps link labels and lists without destinations', () {
    expect(
      notificationPreview(
        '- [**Docs**](https://example.com)\n- Next\n\n3. Third\n4. Fourth',
      ),
      '• Docs\n• Next\n\n3. Third\n4. Fourth',
    );
  });

  test('keeps code contents and escaped punctuation literally', () {
    expect(
      notificationPreview(
        '```dart\n**literal**\nx_y\n```\n\n\\*literal\\* &amp; safe',
      ),
      '**literal**\nx_y\n\n*literal* & safe',
    );
  });

  test('resolves reference links and preserves ordinary punctuation', () {
    expect(
      notificationPreview(
        'See [guide][docs]. Costs \$5; file_name.\n\n[docs]: https://example.com',
      ),
      'See guide. Costs \$5; file_name.',
    );
  });
}
