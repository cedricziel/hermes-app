import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide MessageStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/attachment_fixtures.dart';

void main() {
  group('formatFileSize', () {
    test('counts small files in bytes', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(512), '512 B');
    });

    test('counts files under a megabyte in whole kilobytes', () {
      expect(formatFileSize(120 * 1024), '120 KB');
      expect(formatFileSize(1536), '2 KB');
    });

    test('counts larger files in megabytes with one decimal', () {
      expect(formatFileSize((3.5 * 1024 * 1024).round()), '3.5 MB');
      expect(formatFileSize(25 * 1024 * 1024), '25 MB');
    });
  });

  // The transcript keeps a message it has not laid out yet offstage.
  final anyImage = find.byType(Image, skipOffstage: false);

  Future<void> pumpTranscript(
    WidgetTester tester,
    List<ChatAttachment> attachments,
  ) async {
    final controller = InMemoryChatController(
      messages: chatMessageToFlyer(
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          content: '',
          createdAt: DateTime(2026, 1, 1),
          attachments: attachments,
        ),
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Scaffold(
          body: Chat(
            currentUserId: kUserAuthorId,
            resolveUser: (id) async => User(id: id),
            chatController: controller,
            builders: buildChatBuilders(onPickPrompt: (_) {})
                .copyWith(composerBuilder: (_) => const SizedBox.shrink()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a file shows as a card with its name and size', (tester) async {
    await pumpTranscript(tester, const [
      ChatAttachment(
        name: 'report.pdf',
        kind: AttachmentKind.file,
        path: '/tmp/report.pdf',
        size: 120 * 1024,
      ),
    ]);

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.text('120 KB'), findsOneWidget);
    expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
  });

  testWidgets('a file of unknown size shows only its name', (tester) async {
    await pumpTranscript(tester, const [
      ChatAttachment(
        name: 'report.pdf',
        kind: AttachmentKind.file,
        remotePath: 'docs/report.pdf',
      ),
    ]);

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.textContaining(' B'), findsNothing);
    expect(find.textContaining('KB'), findsNothing);
  });

  testWidgets('an image on this device shows as a thumbnail', (tester) async {
    final file = writeTemp(tempDir('attachment_views'), 'photo.png', kTinyPng);
    await pumpTranscript(tester, [
      ChatAttachment(
        name: 'photo.png',
        kind: AttachmentKind.image,
        path: file.path,
      ),
    ]);

    final image = tester.widget<Image>(anyImage);
    expect((image.image as ResizeImage).imageProvider, isA<FileImage>());
    expect(image.semanticLabel, 'photo.png');
  });

  testWidgets('an image the history embedded shows from its data', (
    tester,
  ) async {
    await pumpTranscript(tester, [
      ChatAttachment(
        name: 'a.png',
        kind: AttachmentKind.image,
        remotePath: '/srv/a.png',
        bytes: kTinyPng,
      ),
    ]);

    expect(
      (tester.widget<Image>(anyImage).image as ResizeImage).imageProvider,
      isA<MemoryImage>(),
    );
  });

  testWidgets('an image that is not on this device shows its name', (
    tester,
  ) async {
    await pumpTranscript(tester, const [
      ChatAttachment(
        name: 'a.png',
        kind: AttachmentKind.image,
        remotePath: '/srv/a.png',
      ),
    ]);

    expect(anyImage, findsNothing);
    expect(find.text('a.png'), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('an image that cannot be decoded falls back to its name', (
    tester,
  ) async {
    await pumpTranscript(tester, [
      ChatAttachment(
        name: 'broken.png',
        kind: AttachmentKind.image,
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    ]);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('broken.png'), findsOneWidget);
  });
}
