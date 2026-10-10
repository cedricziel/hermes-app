import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/kanban/kanban_models.dart';
import 'package:hermes_app/src/kanban/widgets/task_panel/kanban_task_attachments.dart';
import 'package:provider/provider.dart';

import '../support/attachment_fixtures.dart';
import '../support/fake_hermes_server.dart';
import '../support/fake_quick_look.dart';
import '../support/screenshot_recorder.dart';
import '../support/workflow_app.dart';

/// Attachments on a Mac behave like Finder items. Always runs as macOS, since
/// that is the only place the selection exists.
void main() {
  for (final (name, brightness) in [
    ('light', Brightness.light),
    ('dark', Brightness.dark),
  ]) {
    testWidgets('$name: select, preview and the context menu', (tester) async {
      final shots = ScreenshotRecorder('quick-look-$name');
      final cache = tempDir('quick_look_workflow');
      final quickLook = FakeQuickLook();
      final store = MediaStore(
        source: HermesMediaSource(() => FakeHermesServer().client()),
        cacheDirectory: () async => cache,
        quickLook: quickLook,
      );
      final photo = ChatAttachment(
        name: 'diagram.png',
        kind: AttachmentKind.image,
        bytes: kTinyPng,
      );

      await pumpScreen(
        tester,
        shots,
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Here are the files you asked for'),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 12,
                  children: [
                    AttachmentCard(
                      attachment: ChatAttachment(
                        name: 'quarterly-report.pdf',
                        kind: AttachmentKind.file,
                        size: 482113,
                        remotePath: '/srv/quarterly-report.pdf',
                      ),
                    ),
                    AttachmentCard(
                      attachment: ChatAttachment(
                        name: 'notes.txt',
                        kind: AttachmentKind.file,
                        size: 812,
                        remotePath: '/srv/notes.txt',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AttachmentThumbnail(attachment: photo),
                const SizedBox(height: 24),
                SizedBox(
                  width: 420,
                  child: KanbanTaskAttachments(
                    attachments: const [
                      KanbanAttachment(
                        id: 1,
                        filename: 'layout-review.pdf',
                        size: 245760,
                      ),
                      KanbanAttachment(id: 2, filename: 'notes.txt', size: 812),
                    ],
                    onAttach: () {},
                    onDownload: (_) {},
                    onRemove: (_) {},
                    onOpen: (_) {},
                    onQuickLook: (_) {},
                    onToggleQuickLook: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
        size: desktopSize,
        brightness: brightness,
        platform: TargetPlatform.macOS,
        providers: [Provider<MediaStore?>.value(value: store)],
      );
      // Decoding the picture takes real time.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      await shots.capture(tester, 'idle');

      Future<void> click(Finder finder, {int buttons = kPrimaryMouseButton}) =>
          tester.tap(finder, kind: PointerDeviceKind.mouse, buttons: buttons);

      await click(find.text('quarterly-report.pdf'));
      await tester.pump();
      await shots.capture(tester, 'card-selected');

      await click(find.text('layout-review.pdf'));
      await tester.pump();
      await shots.capture(tester, 'kanban-row-selected');

      await click(find.text('notes.txt').last, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();
      await shots.capture(tester, 'context-menu');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    });
  }
}
