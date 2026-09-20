import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' hide MessageStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show Chat;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hermes_app/src/chat/chat_message_kinds.dart';
import 'package:hermes_app/src/chat/chat_message_mapper.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/chat_builders.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

import 'support/attachment_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_media_actions.dart';

void main() {
  late FakeHermesServer server;
  late FakeMediaActions actions;
  late Directory cache;
  late MediaStore store;

  setUp(() {
    server = FakeHermesServer();
    actions = FakeMediaActions();
    cache = tempDir('chat_media');
    store = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () async => cache,
      actions: actions,
    );
  });

  final pdf = Uint8List.fromList('%PDF-1.7 fake'.codeUnits);
  final anyImage = find.byType(Image, skipOffstage: false);

  // Fetches and file writes are real I/O, which the test clock does not run.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // Taps, then lets what the tap started run to its end. The tap has to be
  // inside runAsync too, or the file I/O it starts never finishes.
  Future<void> tap(WidgetTester tester, Finder finder, {int wait = 250}) async {
    await tester.runAsync(() async {
      await tester.tap(finder);
      await Future<void>.delayed(Duration(milliseconds: wait));
    });
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pumpTranscript(
    WidgetTester tester,
    ChatMessage message, {
    MediaStore? withStore,
    bool provideStore = true,
  }) async {
    final controller = InMemoryChatController(
      messages: chatMessageToFlyer(message),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Provider<MediaStore?>.value(
        value: provideStore ? (withStore ?? store) : null,
        child: MaterialApp(
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
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
  }

  ChatMessage reply(String content, {ChatRole role = ChatRole.assistant}) =>
      ChatMessage(
        id: 'm1',
        role: role,
        content: content,
        createdAt: DateTime(2026, 1, 1),
      );

  ChatMessage restored(ChatAttachment attachment) => ChatMessage(
    id: 'm1',
    role: ChatRole.user,
    content: 'look',
    createdAt: DateTime(2026, 1, 1),
    attachments: [attachment],
  );

  group('an image the agent sent', () {
    testWidgets('shows after the text and the tag is not visible', (
      tester,
    ) async {
      server.onMedia('/home/u/.hermes/images/a.png', kTinyPng);

      await pumpTranscript(
        tester,
        reply('Here you go MEDIA:/home/u/.hermes/images/a.png'),
      );
      await settle(tester);

      expect(find.text('Here you go', findRichText: true), findsOneWidget);
      expect(find.textContaining('MEDIA:', findRichText: true), findsNothing);
      final image = tester.widget<Image>(anyImage);
      expect(image.semanticLabel, 'a.png');
      final provider = (image.image as ResizeImage).imageProvider;
      expect((provider as MemoryImage).bytes, kTinyPng);
    });

    testWidgets('shows a placeholder while it loads', (tester) async {
      final gate = Completer<void>();
      server.onRequest('GET', '/api/media', (_) async {
        await gate.future;
        return (status: 200, body: {'data_url': 'data:image/png;base64,AAAA'});
      });

      await pumpTranscript(tester, reply('MEDIA:/srv/a.png'));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(anyImage, findsNothing);
      gate.complete();
      await settle(tester);
    });

    testWidgets('opens full screen with zoom and closes again', (tester) async {
      server.onMedia('/srv/a.png', kTinyPng);
      await pumpTranscript(tester, reply('MEDIA:/srv/a.png'));
      await settle(tester);

      await tester.tap(anyImage);
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.text('a.png'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsNothing);
      expect(anyImage, findsOneWidget);
    });

    testWidgets('can be saved from the full screen view', (tester) async {
      server.onMedia('/srv/a.png', kTinyPng);
      await pumpTranscript(tester, reply('MEDIA:/srv/a.png'));
      await settle(tester);
      await tester.tap(anyImage);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Save'));
      await settle(tester);

      expect(actions.saved.single.name, 'a.png');
      expect(actions.saved.single.bytes, kTinyPng);
    });

    testWidgets('outside the media folders comes from the download route', (
      tester,
    ) async {
      server.on('GET', '/api/media', {'detail': 'outside'}, status: 403);
      server.onDownload('/work/chart.png', kTinyPng);

      await pumpTranscript(tester, reply('MEDIA:/work/chart.png'));
      await settle(tester);

      expect(anyImage, findsOneWidget);
    });

    testWidgets('that is gone shows a card that says so', (tester) async {
      server.on('GET', '/api/media', {'detail': 'gone'}, status: 404);

      await pumpTranscript(tester, reply('MEDIA:/srv/a.png'));
      await settle(tester);

      expect(find.text('a.png'), findsOneWidget);
      expect(find.text('This file is no longer available.'), findsOneWidget);
      expect(anyImage, findsNothing);
    });

    testWidgets('that failed to load is tried again with a tap', (
      tester,
    ) async {
      server.on('GET', '/api/media', {'detail': 'boom'}, status: 500);
      await pumpTranscript(tester, reply('MEDIA:/srv/a.png'));
      await settle(tester);
      expect(
        find.text('Could not download the file. Tap to try again.'),
        findsOneWidget,
      );

      server.onMedia('/srv/a.png', kTinyPng);
      await tester.tap(find.text('a.png'));
      await settle(tester);

      expect(anyImage, findsOneWidget);
    });

    testWidgets('restored from history shows as a thumbnail', (tester) async {
      server.onMedia('/srv/uploads/photo.png', kTinyPng);

      await pumpTranscript(
        tester,
        restored(
          const ChatAttachment(
            name: 'photo.png',
            kind: AttachmentKind.image,
            remotePath: '/srv/uploads/photo.png',
          ),
        ),
      );
      await settle(tester);

      expect(anyImage, findsOneWidget);
    });

    testWidgets('without a session to fetch with shows its name', (
      tester,
    ) async {
      await pumpTranscript(
        tester,
        reply('MEDIA:/srv/a.png'),
        provideStore: false,
      );
      await settle(tester);

      expect(find.text('a.png'), findsOneWidget);
      expect(server.requests, isEmpty);
    });
  });

  group('a file the agent sent', () {
    testWidgets('downloads on tap, shows progress, then opens', (tester) async {
      final gate = Completer<void>();
      server.onRequest('GET', '/api/files/download', (_) async {
        await gate.future;
        return (status: 200, body: pdf);
      });
      await pumpTranscript(tester, reply('MEDIA:/srv/report.pdf'));
      expect(find.text('report.pdf'), findsOneWidget);
      expect(server.requests, isEmpty);

      await tap(tester, find.text('report.pdf'), wait: 50);

      expect(find.text('Downloading…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(actions.opened, isEmpty);

      gate.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Downloading…'), findsNothing);
      expect(actions.opened, hasLength(1));
      final path = actions.opened.single;
      expect(path, startsWith(cache.path));
      expect(File(path).readAsBytesSync(), pdf);
    });

    testWidgets('opens again without downloading again', (tester) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pumpTranscript(tester, reply('MEDIA:/srv/report.pdf'));

      await tap(tester, find.text('report.pdf'));
      await tap(tester, find.text('report.pdf'));

      expect(actions.opened, hasLength(2));
      expect(server.requestsTo('GET', '/api/files/download'), hasLength(1));
    });

    testWidgets('can be saved', (tester) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pumpTranscript(tester, reply('MEDIA:/srv/report.pdf'));

      await tap(tester, find.byTooltip('Save'));

      expect(actions.saved.single.name, 'report.pdf');
      expect(actions.saved.single.bytes, pdf);
      expect(actions.opened, isEmpty);
      expect(find.text('Saved report.pdf'), findsOneWidget);
    });

    testWidgets('says so when no app can open it', (tester) async {
      actions.opens = false;
      server.onDownload('/srv/report.pdf', pdf);
      await pumpTranscript(tester, reply('MEDIA:/srv/report.pdf'));

      await tap(tester, find.text('report.pdf'));

      expect(find.text('No app can open this file.'), findsOneWidget);
    });

    final reasons = {
      404: 'This file is no longer available.',
      403: "This file can't be opened from here.",
      413: 'This file is too large to download.',
      500: 'Could not download the file. Tap to try again.',
    };
    for (final MapEntry(key: status, value: message) in reasons.entries) {
      testWidgets('explains a $status', (tester) async {
        server.onDownloadFailure(status);
        await pumpTranscript(tester, reply('MEDIA:/srv/report.pdf'));

        await tap(tester, find.text('report.pdf'));

        expect(find.text(message), findsOneWidget);
        expect(find.text('report.pdf'), findsOneWidget);
        expect(actions.opened, isEmpty);
      });
    }

    testWidgets('starts the download again when a tap retries', (tester) async {
      server.onDownloadFailure(500);
      await pumpTranscript(tester, reply('MEDIA:/srv/report.pdf'));
      await tap(tester, find.text('report.pdf'));
      expect(find.textContaining('Tap to try again'), findsOneWidget);

      server.onDownload('/srv/report.pdf', pdf);
      await tap(tester, find.text('report.pdf'));

      expect(find.textContaining('Tap to try again'), findsNothing);
      expect(actions.opened, hasLength(1));
      expect(server.requestsTo('GET', '/api/files/download'), hasLength(2));
    });

    testWidgets('with a relative path shows its name and nothing to download', (
      tester,
    ) async {
      await pumpTranscript(
        tester,
        restored(
          const ChatAttachment(
            name: 'report.pdf',
            kind: AttachmentKind.file,
            remotePath: 'attachments/report.pdf',
          ),
        ),
      );

      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.byTooltip('Save'), findsNothing);
      await tap(tester, find.text('report.pdf'));
      expect(server.requests, isEmpty);
      expect(actions.opened, isEmpty);
    });

    testWidgets('restored from history downloads the same way', (tester) async {
      server.onDownload('/srv/uploads/report.pdf', pdf);
      await pumpTranscript(
        tester,
        restored(
          const ChatAttachment(
            name: 'report.pdf',
            kind: AttachmentKind.file,
            remotePath: '/srv/uploads/report.pdf',
          ),
        ),
      );

      await tap(tester, find.text('report.pdf'));

      expect(actions.opened, hasLength(1));
    });

    testWidgets('is gone from disk after the store is cleared', (tester) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pumpTranscript(tester, reply('MEDIA:/srv/report.pdf'));
      await tap(tester, find.text('report.pdf'));
      final path = actions.opened.single;
      expect(File(path).existsSync(), isTrue);

      await tester.runAsync(store.clear);

      expect(File(path).existsSync(), isFalse);
    });
  });
}
