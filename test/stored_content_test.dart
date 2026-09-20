import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/stored_content.dart';

import 'support/attachment_fixtures.dart';

void main() {
  final pngUrl = 'data:image/png;base64,${base64Encode(kTinyPng)}';

  group('text content', () {
    test('plain text has no attachments', () {
      final parsed = parseStoredContent('just words')!;

      expect(parsed.text, 'just words');
      expect(parsed.attachments, isEmpty);
    });

    test('null content is an empty message', () {
      final parsed = parseStoredContent(null)!;

      expect(parsed.text, '');
      expect(parsed.attachments, isEmpty);
    });

    test('a value that is neither text nor parts cannot be read', () {
      expect(parseStoredContent(42), isNull);
      expect(parseStoredContent({'type': 'text'}), isNull);
    });

    test('reads an @image line back as an image attachment', () {
      final parsed = parseStoredContent(
        'look\n@image:/home/u/.hermes/images/a.png',
      )!;

      expect(parsed.text, 'look');
      final image = parsed.attachments.single;
      expect(image.name, 'a.png');
      expect(image.kind, AttachmentKind.image);
      expect(image.remotePath, '/home/u/.hermes/images/a.png');
      expect(image.path, isNull);
    });

    test('an image with no caption leaves no text', () {
      final parsed = parseStoredContent('@image:/x/a.png')!;

      expect(parsed.text, '');
      expect(parsed.attachments.single.name, 'a.png');
    });

    test('reads an @file line back as a file attachment', () {
      final parsed = parseStoredContent('@file:docs/report.pdf')!;

      expect(parsed.text, '');
      final file = parsed.attachments.single;
      expect(file.name, 'report.pdf');
      expect(file.kind, AttachmentKind.file);
      expect(file.remotePath, 'docs/report.pdf');
    });

    test('reads a "[User attached file: ...]" line', () {
      final parsed = parseStoredContent(
        '[User attached file: /srv/in/notes.txt]\nsummarise it',
      )!;

      expect(parsed.text, 'summarise it');
      expect(parsed.attachments.single.name, 'notes.txt');
      expect(parsed.attachments.single.remotePath, '/srv/in/notes.txt');
      expect(parsed.attachments.single.kind, AttachmentKind.file);
    });

    test('reads quoted paths whole', () {
      final parsed = parseStoredContent(
        '@image:`/tmp/my photos/a b.png`\n'
        '@file:"docs/q3 report.pdf"\n'
        "@file:'it''s.txt'",
      )!;

      expect(parsed.attachments.map((a) => a.name), [
        'a b.png',
        'q3 report.pdf',
        "it''s.txt",
      ]);
      expect(parsed.attachments.first.remotePath, '/tmp/my photos/a b.png');
    });

    test('takes the name from a Windows path', () {
      final parsed = parseStoredContent(r'@file:C:\Users\me\a.pdf')!;

      expect(parsed.attachments.single.name, 'a.pdf');
    });

    test('keeps several attachments in order and the text before them', () {
      final parsed = parseStoredContent(
        'first\n@image:/x/1.png\n@image:/x/2.png\n@file:notes.md',
      )!;

      expect(parsed.text, 'first');
      expect(parsed.attachments.map((a) => a.name), [
        '1.png',
        '2.png',
        'notes.md',
      ]);
    });

    test('leaves a reference inside a sentence as text', () {
      const text = 'compare @file:a.txt with the other one';

      final parsed = parseStoredContent(text)!;

      expect(parsed.text, text);
      expect(parsed.attachments, isEmpty);
    });

    test('leaves text that merely mentions the reference syntax alone', () {
      final parsed = parseStoredContent('use @image: to attach')!;

      expect(parsed.text, 'use @image: to attach');
      expect(parsed.attachments, isEmpty);
    });

    test('keeps blank lines inside the text', () {
      final parsed = parseStoredContent('a\n\nb\n@file:x.txt')!;

      expect(parsed.text, 'a\n\nb');
    });
  });

  group('list content', () {
    test('joins the text parts in order', () {
      final parsed = parseStoredContent([
        {'type': 'text', 'text': 'one'},
        {'type': 'text', 'text': 'two'},
      ])!;

      expect(parsed.text, 'one\ntwo');
      expect(parsed.attachments, isEmpty);
    });

    test('loads a text part with an image part and does not fail', () {
      final parsed = parseStoredContent([
        {'type': 'text', 'text': 'what is this?\n@image:/x/pic.png'},
        {
          'type': 'image_url',
          'image_url': {'url': pngUrl},
        },
      ])!;

      expect(parsed.text, 'what is this?');
      final image = parsed.attachments.single;
      expect(image.name, 'pic.png');
      expect(image.kind, AttachmentKind.image);
      expect(image.remotePath, '/x/pic.png');
      expect(image.bytes, kTinyPng);
      expect(image.size, kTinyPng.length);
    });

    test('shows an embedded image that has no reference in the text', () {
      final parsed = parseStoredContent([
        {'type': 'text', 'text': 'hi'},
        {
          'type': 'image_url',
          'image_url': {'url': pngUrl},
        },
      ])!;

      expect(parsed.text, 'hi');
      final image = parsed.attachments.single;
      expect(image.name, 'image.png');
      expect(image.bytes, isNotNull);
    });

    test('accepts the other part spellings', () {
      final parsed = parseStoredContent([
        'plain',
        {'type': 'input_text', 'text': 'more'},
        {'type': 'input_image', 'image_url': pngUrl},
      ])!;

      expect(parsed.text, 'plain\nmore');
      expect(parsed.attachments.single.bytes, isNotNull);
    });

    test('ignores an image it cannot decode and parts it does not know', () {
      final parsed = parseStoredContent([
        {'type': 'text', 'text': 'hi'},
        {
          'type': 'image_url',
          'image_url': {'url': 'https://example.com/a.png'},
        },
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/png;base64,@@@'},
        },
        {'type': 'audio', 'data': 'x'},
        7,
      ])!;

      expect(parsed.text, 'hi');
      expect(parsed.attachments, isEmpty);
    });

    test('an empty list is an empty message', () {
      final parsed = parseStoredContent(const [])!;

      expect(parsed.text, '');
      expect(parsed.attachments, isEmpty);
    });
  });
}
