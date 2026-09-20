import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/extract_media.dart';

void main() {
  group('extractMedia', () {
    test('turns an image tag into an attachment and hides the tag', () {
      final out = extractMedia(
        'Here you go MEDIA:/home/u/.hermes/images/a.png',
      );

      expect(out.text, 'Here you go');
      expect(out.attachments, hasLength(1));
      final a = out.attachments.single;
      expect(a.name, 'a.png');
      expect(a.kind, AttachmentKind.image);
      expect(a.remotePath, '/home/u/.hermes/images/a.png');
      expect(a.path, isNull);
    });

    test('keeps the order of two tags', () {
      final out = extractMedia(
        'Two files:\nMEDIA:/tmp/report.pdf\nMEDIA:/tmp/chart.jpg\nDone.',
      );

      expect(out.attachments.map((a) => a.name), ['report.pdf', 'chart.jpg']);
      expect(out.attachments.map((a) => a.kind), [
        AttachmentKind.file,
        AttachmentKind.image,
      ]);
      expect(out.text, 'Two files:\nDone.');
    });

    test('a message of only tags has no text', () {
      final out = extractMedia('MEDIA:/tmp/a.png\n\nMEDIA:/tmp/b.png');

      expect(out.text, isEmpty);
      expect(out.attachments, hasLength(2));
    });

    test('leaves text without a tag exactly as written', () {
      const text = '  Some text\n\n\n\nwith spacing  ';
      final out = extractMedia(text);

      expect(out.text, text);
      expect(out.attachments, isEmpty);
    });

    test('a relative path stays text', () {
      final out = extractMedia('See MEDIA:notes.txt and MEDIA:./b.png');

      expect(out.text, 'See MEDIA:notes.txt and MEDIA:./b.png');
      expect(out.attachments, isEmpty);
    });

    test('reads a Windows path', () {
      final out = extractMedia(r'MEDIA:C:\Users\u\out\shot.png');

      expect(out.attachments.single.name, 'shot.png');
      expect(out.attachments.single.remotePath, r'C:\Users\u\out\shot.png');
    });

    test('reads a quoted path with spaces', () {
      final out = extractMedia('Saved MEDIA:"/tmp/my report.pdf" for you');

      expect(out.attachments.single.name, 'my report.pdf');
      expect(out.attachments.single.remotePath, '/tmp/my report.pdf');
      expect(out.text, 'Saved for you');
    });

    test('drops the punctuation that ends a sentence from the path', () {
      final out = extractMedia('Made it: MEDIA:/tmp/a.png.');

      expect(out.attachments.single.remotePath, '/tmp/a.png');
      expect(out.text, 'Made it:');
    });

    test('shows one attachment for a path named twice', () {
      final out = extractMedia('MEDIA:/tmp/a.png then again MEDIA:/tmp/a.png');

      expect(out.attachments, hasLength(1));
      expect(out.text, 'then again');
    });

    test('does not read a tag inside code', () {
      const text =
          'Write `MEDIA:/tmp/a.png` like this:\n```\nMEDIA:/tmp/b.png\n```';
      final out = extractMedia(text);

      expect(out.attachments, isEmpty);
      expect(out.text, text);
    });

    test('does not read a tag that is part of another word', () {
      final out = extractMedia('NOMEDIA:/tmp/a.png');

      expect(out.attachments, isEmpty);
    });

    test('treats an extension other than an image as a file', () {
      final out = extractMedia(
        'MEDIA:/tmp/a.svg MEDIA:/tmp/b.mp3 MEDIA:/tmp/c.webp MEDIA:/tmp/d',
      );

      expect(out.attachments.map((a) => a.kind), [
        AttachmentKind.file,
        AttachmentKind.file,
        AttachmentKind.image,
        AttachmentKind.file,
      ]);
    });

    group('while the reply is still arriving', () {
      test('holds back a tag that has not finished', () {
        final out = extractMedia('see MEDIA:/ho', complete: false);

        expect(out.text, 'see');
        expect(out.attachments, isEmpty);
      });

      test('holds back a partial tag word', () {
        for (final tail in ['M', 'ME', 'MEDIA', 'MEDIA:']) {
          final out = extractMedia('see $tail', complete: false);
          expect(out.text, 'see', reason: tail);
          expect(out.attachments, isEmpty, reason: tail);
        }
      });

      test('shows a tag once a space follows it', () {
        final out = extractMedia('see MEDIA:/tmp/a.png and', complete: false);

        expect(out.attachments.single.name, 'a.png');
        expect(out.text, 'see and');
      });

      test('holds back a quoted path that has not closed', () {
        final out = extractMedia('see MEDIA:"/tmp/my rep', complete: false);

        expect(out.text, 'see');
        expect(out.attachments, isEmpty);
      });

      test('leaves other text alone', () {
        final out = extractMedia('Made of media: yes', complete: false);

        expect(out.text, 'Made of media: yes');
      });

      test('a finished reply reads a tag at its very end', () {
        final out = extractMedia('see MEDIA:/tmp/a.png');

        expect(out.attachments.single.name, 'a.png');
      });
    });
  });
}
