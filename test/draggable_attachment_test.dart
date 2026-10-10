import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide MessageStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/attachments/draggable_attachment.dart';
import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/drag_out/drag_out_item.dart';
import 'package:hermes_app/src/drag_out/drag_out_source.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

import 'support/attachment_fixtures.dart';
import 'support/fake_drag_out_source.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_media_actions.dart';

void main() {
  late FakeHermesServer server;
  late FakeDragOutSource source;
  late MediaStore store;

  setUp(() {
    server = FakeHermesServer();
    source = FakeDragOutSource();
    final cache = tempDir('draggable_attachment');
    store = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () async => cache,
      actions: FakeMediaActions(),
    );
  });

  // The read touches real files, which fake async never completes.
  Future<Uint8List> readLast(WidgetTester tester) async {
    final file = source.lastFile;
    final result = await tester.runAsync(() async {
      try {
        return await file.read();
      } on Object catch (e) {
        return e;
      }
    });
    if (result is Uint8List) return result;
    Error.throwWithStackTrace(result!, StackTrace.current);
  }

  Future<void> pumpAttachment(
    WidgetTester tester,
    ChatAttachment attachment, {
    Widget? child,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Provider<MediaStore?>.value(
        value: store,
        child: Provider<DragOutSource?>.value(
          value: source,
          child: Scaffold(
            body: DraggableAttachment(
              attachment: attachment,
              child: child ?? AttachmentCard(attachment: attachment),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('drags the bytes the message already holds', (tester) async {
    await pumpAttachment(
      tester,
      ChatAttachment(
        name: 'chart.png',
        kind: AttachmentKind.image,
        remotePath: '/srv/chart.png',
        bytes: kTinyPng,
      ),
    );

    expect(source.wraps.single.kind, DragOutKind.attachment);
    expect(source.lastFile.name, 'chart.png');
    expect(await readLast(tester), kTinyPng);
    expect(server.requests, isEmpty);
  });

  testWidgets('drags the file the user picked', (tester) async {
    final file = writeTemp(tempDir('picked'), 'notes.txt', [1, 2, 3]);
    await pumpAttachment(
      tester,
      ChatAttachment(
        name: 'notes.txt',
        kind: AttachmentKind.file,
        path: file.path,
      ),
    );

    expect(await readLast(tester), [1, 2, 3]);
    expect(server.requests, isEmpty);
  });

  testWidgets('fetches a file only the server has, when the drop asks', (
    tester,
  ) async {
    server.onDownload('/srv/report.pdf', [37, 80, 68, 70]);
    await pumpAttachment(
      tester,
      const ChatAttachment(
        name: 'report.pdf',
        kind: AttachmentKind.file,
        remotePath: '/srv/report.pdf',
      ),
    );

    expect(source.lastFile.name, 'report.pdf');
    expect(
      server.requestsTo('GET', '/api/files/download'),
      isEmpty,
      reason: 'nothing is fetched when the drag starts',
    );

    expect(await readLast(tester), [37, 80, 68, 70]);
    expect(server.requestsTo('GET', '/api/files/download'), hasLength(1));
  });

  testWidgets('a file the server no longer has fails the read', (tester) async {
    server.onDownloadFailure(404);
    await pumpAttachment(
      tester,
      const ChatAttachment(
        name: 'gone.pdf',
        kind: AttachmentKind.file,
        remotePath: '/srv/gone.pdf',
      ),
    );

    await expectLater(
      readLast(tester),
      throwsA(
        isA<MediaFetchException>().having(
          (e) => e.reason,
          'reason',
          MediaFailure.missing,
        ),
      ),
    );
  });

  testWidgets('falls back to the server when the picked file is gone', (
    tester,
  ) async {
    server.onDownload('/srv/a.txt', [7]);
    await pumpAttachment(
      tester,
      const ChatAttachment(
        name: 'a.txt',
        kind: AttachmentKind.file,
        path: '/no/such/dir/a.txt',
        remotePath: '/srv/a.txt',
      ),
    );

    expect(await readLast(tester), [7]);
  });

  testWidgets('a path relative to the workspace starts no drag', (
    tester,
  ) async {
    await pumpAttachment(
      tester,
      const ChatAttachment(
        name: 'report.pdf',
        kind: AttachmentKind.file,
        remotePath: 'attachments/report.pdf',
      ),
    );

    expect(source.lastItem, isNull);
  });

  testWidgets('a hostile name is made safe', (tester) async {
    await pumpAttachment(
      tester,
      ChatAttachment(
        name: '../../x/y: z.pdf',
        kind: AttachmentKind.file,
        bytes: Uint8List(1),
      ),
    );

    final name = source.lastFile.name;
    expect(name, isNot(anyOf(contains('/'), contains(':'), startsWith('.'))));
    expect(name, endsWith('.pdf'));
  });

  testWidgets('a server path as the name drags out as its file name', (
    tester,
  ) async {
    await pumpAttachment(
      tester,
      ChatAttachment(
        name: '/home/u/out/report.pdf',
        kind: AttachmentKind.file,
        bytes: Uint8List(1),
      ),
    );

    expect(source.lastFile.name, 'report.pdf');
  });

  testWidgets('tapping the card still downloads and opens it', (tester) async {
    final actions = FakeMediaActions();
    final cache = tempDir('tap');
    store = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () async => cache,
      actions: actions,
    );
    server.onDownload('/srv/report.pdf', [1, 2]);
    await pumpAttachment(
      tester,
      const ChatAttachment(
        name: 'report.pdf',
        kind: AttachmentKind.file,
        remotePath: '/srv/report.pdf',
      ),
    );

    await tester.runAsync(() => tester.tap(find.text('report.pdf')));
    // The download writes a real file, so wait for it in real time.
    for (var i = 0; i < 20 && actions.opened.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    expect(server.requestsTo('GET', '/api/files/download'), hasLength(1));
    expect(actions.opened, hasLength(1));
  });

  testWidgets('without a source the card is not wrapped', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DraggableAttachment(
            attachment: const ChatAttachment(
              name: 'a.txt',
              kind: AttachmentKind.file,
            ),
            child: const Text('card'),
          ),
        ),
      ),
    );

    expect(find.text('card'), findsOneWidget);
  });

  testWidgets('the message transcript wraps its attachment cards', (
    tester,
  ) async {
    final controller = InMemoryChatController(
      messages: chatMessageToFlyer(
        ChatMessage(
          id: 'm1',
          role: ChatRole.user,
          content: '',
          createdAt: DateTime(2026, 1, 1),
          attachments: [
            ChatAttachment(
              name: 'a.pdf',
              kind: AttachmentKind.file,
              bytes: Uint8List(2),
            ),
          ],
        ),
      ),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesLightTheme(),
        home: Provider<DragOutSource?>.value(
          value: source,
          child: Scaffold(
            body: Chat(
              currentUserId: kUserAuthorId,
              resolveUser: (id) async => User(id: id),
              chatController: controller,
              builders: buildChatBuilders(onPickPrompt: (_) {})
                  .copyWith(composerBuilder: (_) => const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(source.wraps, isNotEmpty);
    expect(source.lastFile.name, 'a.pdf');
  });
}
