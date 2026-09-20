import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hermes_app/src/chat/attachments/attachment_source.dart';
import 'package:hermes_app/src/share/shared_item.dart';

import 'support/fake_attachment_source.dart';
import 'support/pump_chat.dart';

const _report = SharedFile(path: '/tmp/a/report.pdf', name: 'report.pdf');
const _notes = SharedFile(path: '/tmp/a/notes.txt', name: 'notes.txt');
const _shot = SharedFile(
  path: '/tmp/pasted-1.png',
  name: 'pasted-20260920-153012-034.png',
  mimeType: 'image/png',
  isImage: true,
);

final _attachButton = find.byIcon(Icons.attach_file);

String _composerText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

/// Puts [text] on the clipboard the framework reads from; the test binding
/// has no clipboard of its own.
void _putOnClipboard(WidgetTester tester, String text) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => switch (call.method) {
      'Clipboard.getData' => <String, Object?>{'text': text},
      'Clipboard.hasStrings' => <String, Object?>{'value': true},
      _ => null,
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

/// The test binding checks that no override outlives the test body, which
/// rules out `addTearDown`.
Future<void> _on(TargetPlatform platform, Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

/// Pastes with the chord of the platform under test.
Future<void> _paste(WidgetTester tester, LogicalKeyboardKey modifier) async {
  await tester.tap(find.byType(EditableText));
  await tester.pump();
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('attach control', () {
    testWidgets('offers files, the photo library and the camera on a phone', (
      tester,
    ) async {
      await pumpChatScreen(tester, attachmentSource: FakeAttachmentSource());

      await tester.tap(_attachButton);
      await tester.pumpAndSettle();

      expect(find.text('Choose files'), findsOneWidget);
      expect(find.text('Photo library'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
    });

    testWidgets('offers files but not the camera on a desktop', (tester) async {
      await pumpChatScreen(
        tester,
        attachmentSource: FakeAttachmentSource(origins: [AttachOrigin.files]),
      );

      await tester.tap(_attachButton);
      await tester.pumpAndSettle();

      expect(find.text('Choose files'), findsOneWidget);
      expect(find.text('Take a photo'), findsNothing);
      expect(find.text('Photo library'), findsNothing);
    });

    testWidgets('picked files appear as chips with their names', (
      tester,
    ) async {
      final source = FakeAttachmentSource()
        ..picks[AttachOrigin.files] = [_report, _notes];
      await pumpChatScreen(tester, attachmentSource: source);

      await tester.tap(_attachButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();

      expect(source.requested, [AttachOrigin.files]);
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('Choose files'), findsNothing);
    });

    testWidgets('a photo from the library is added to what is pending', (
      tester,
    ) async {
      final source = FakeAttachmentSource()
        ..picks[AttachOrigin.files] = [_report]
        ..picks[AttachOrigin.photos] = [_shot];
      await pumpChatScreen(tester, attachmentSource: source);

      for (final entry in ['Choose files', 'Photo library']) {
        await tester.tap(_attachButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry));
        await tester.pumpAndSettle();
      }

      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text(_shot.name), findsOneWidget);
    });

    testWidgets('cancelling the picker changes nothing', (tester) async {
      final source = FakeAttachmentSource();
      await pumpChatScreen(tester, attachmentSource: source);
      await tester.enterText(find.byType(EditableText), 'draft');

      await tester.tap(_attachButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();

      expect(source.requested, [AttachOrigin.files]);
      expect(find.byType(InputChip), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(_composerText(tester), 'draft');
    });

    testWidgets('a denied camera says so and attaches nothing', (tester) async {
      final source = FakeAttachmentSource()
        ..pickFailure = const AttachmentUnavailable(
          'The camera is not available.',
        );
      await pumpChatScreen(tester, attachmentSource: source);

      await tester.tap(_attachButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take a photo'));
      await tester.pumpAndSettle();

      expect(source.requested, [AttachOrigin.camera]);
      expect(find.text('The camera is not available.'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('a picker that fails unexpectedly is reported, not thrown', (
      tester,
    ) async {
      final source = FakeAttachmentSource()..pickFailure = StateError('boom');
      await pumpChatScreen(tester, attachmentSource: source);

      await tester.tap(_attachButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose files'));
      await tester.pumpAndSettle();

      expect(find.text('Could not attach that.'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('a file that is already attached is not added twice', (
      tester,
    ) async {
      final source = FakeAttachmentSource()
        ..picks[AttachOrigin.files] = [_report];
      await pumpChatScreen(tester, attachmentSource: source);

      for (var i = 0; i < 2; i++) {
        await tester.tap(_attachButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Choose files'));
        await tester.pumpAndSettle();
      }

      expect(find.text('report.pdf'), findsOneWidget);
    });
  });

  group('drag and drop', () {
    testWidgets('a dropped file appears as an attachment', (tester) async {
      final source = FakeAttachmentSource();
      await pumpChatScreen(tester, attachmentSource: source);

      source.drop([_report]);
      await tester.pumpAndSettle();

      expect(find.text('report.pdf'), findsOneWidget);
    });

    testWidgets('dropping only folders changes nothing', (tester) async {
      final source = FakeAttachmentSource();
      await pumpChatScreen(tester, attachmentSource: source);

      source.drop(const []);
      await tester.pumpAndSettle();

      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('the indicator shows while files are over the chat', (
      tester,
    ) async {
      final source = FakeAttachmentSource();
      await pumpChatScreen(tester, attachmentSource: source);
      expect(find.text('Drop files to attach'), findsNothing);

      source.dragOver(true);
      await tester.pump();
      expect(find.text('Drop files to attach'), findsOneWidget);

      source.dragOver(false);
      await tester.pump();
      expect(find.text('Drop files to attach'), findsNothing);
    });

    testWidgets('the indicator goes away when the files are dropped', (
      tester,
    ) async {
      final source = FakeAttachmentSource();
      await pumpChatScreen(tester, attachmentSource: source);

      source.dragOver(true);
      source.drop([_report]);
      await tester.pump();

      expect(find.text('Drop files to attach'), findsNothing);
    });

    testWidgets('a platform without drops gets no drop target', (tester) async {
      final source = FakeAttachmentSource(acceptsDropAndPaste: false);
      await pumpChatScreen(tester, attachmentSource: source);

      expect(source.hasDropTarget, isFalse);
    });
  });

  group('paste', () {
    for (final (platform, modifier) in [
      (TargetPlatform.macOS, LogicalKeyboardKey.meta),
      (TargetPlatform.linux, LogicalKeyboardKey.control),
      (TargetPlatform.windows, LogicalKeyboardKey.control),
    ]) {
      testWidgets(
        'an image on the clipboard is attached on $platform',
        (tester) => _on(platform, () async {
          final source = FakeAttachmentSource()..clipboard = [_shot];
          _putOnClipboard(tester, 'ignored');
          await pumpChatScreen(tester, attachmentSource: source);

          await _paste(tester, modifier);

          expect(find.text(_shot.name), findsOneWidget);
          expect(_composerText(tester), isEmpty);
        }),
      );
    }

    testWidgets(
      'text on the clipboard is pasted as text',
      (tester) => _on(TargetPlatform.macOS, () async {
        final source = FakeAttachmentSource();
        _putOnClipboard(tester, 'hello there');
        await pumpChatScreen(tester, attachmentSource: source);

        await _paste(tester, LogicalKeyboardKey.meta);

        expect(source.pasteReads, 1);
        expect(_composerText(tester), 'hello there');
        expect(find.byType(InputChip), findsNothing);
      }),
    );

    testWidgets(
      'a platform without paste attachments pastes text only',
      (tester) => _on(TargetPlatform.macOS, () async {
        final source = FakeAttachmentSource(acceptsDropAndPaste: false)
          ..clipboard = [_shot];
        _putOnClipboard(tester, 'hello there');
        await pumpChatScreen(tester, attachmentSource: source);

        await _paste(tester, LogicalKeyboardKey.meta);

        expect(source.pasteReads, 0);
        expect(_composerText(tester), 'hello there');
        expect(find.byType(InputChip), findsNothing);
      }),
    );
  });
}
