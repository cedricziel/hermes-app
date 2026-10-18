import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/chat/widgets/image_viewer.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

import 'support/attachment_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_quick_look.dart';
import 'support/wait_until.dart';

void main() {
  late FakeHermesServer server;
  late FakeQuickLook native;
  late Directory cache;
  late MediaStore store;
  setUp(() {
    server = FakeHermesServer();
    native = FakeQuickLook();
    cache = tempDir('ios_photo');
    store = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () async => cache,
      quickLook: native,
    );
    addTearDown(store.dispose);
  });
  Future<void> pump(
    WidgetTester tester,
    ChatAttachment photo, {
    MediaStore? media,
    Widget? before,
  }) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      Provider<MediaStore?>.value(
        value: media ?? store,
        child: MaterialApp(
          theme: buildHermesLightTheme().copyWith(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ?before,
                AttachmentThumbnail(attachment: photo),
              ],
            ),
          ),
        ),
      ),
    );
    await waitUntil(
      tester,
      () => tester
          .widgetList<RawImage>(find.byType(RawImage))
          .any((image) => image.image != null),
    );
  }

  Future<void> open(WidgetTester tester) async {
    // The tiny fixture is one pixel, so tap its centre.
    final point =
        tester.getTopLeft(find.byType(Image).first) + const Offset(.5, .5);
    await tester.runAsync(() => tester.tapAt(point));
    await tester.pump();
    await waitUntil(
      tester,
      () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
    );
  }

  void expectStagedPhoto() {
    expect(native.previewed, hasLength(1));
    final file = File(native.previewed.single);
    expect(file.path, startsWith('${cache.path}/hermes_media/'));
    expect(file.readAsBytesSync(), kTinyPng);
  }

  testWidgets(
    'a received photo previews cached bytes natively without another download',
    (tester) async {
      server.onMedia('/srv/photo.png', kTinyPng);
      await pump(
        tester,
        const ChatAttachment(
          name: 'photo.png',
          kind: AttachmentKind.image,
          remotePath: '/srv/photo.png',
        ),
      );
      await open(tester);
      expectStagedPhoto();
      expect(server.requestsTo('GET', '/api/media'), hasLength(1));
      expect(server.requestsTo('GET', '/api/files/download'), isEmpty);
      expect(find.byType(ImageViewerPage), findsNothing);
    },
  );
  testWidgets('embedded history photos work without a remote path', (
    tester,
  ) async {
    await pump(
      tester,
      ChatAttachment(
        name: 'history.png',
        kind: AttachmentKind.image,
        bytes: kTinyPng,
      ),
    );
    await open(tester);
    expectStagedPhoto();
    expect(server.requests, isEmpty);
  });
  testWidgets('a picked photo is copied into the cache before native sharing', (
    tester,
  ) async {
    final source = writeTemp(cache, 'picked.png', kTinyPng);
    await pump(
      tester,
      ChatAttachment(
        name: 'picked.png',
        kind: AttachmentKind.image,
        path: source.path,
      ),
    );
    await open(tester);
    expectStagedPhoto();
    expect(native.previewed.single, isNot(source.path));
    expect(server.requests, isEmpty);
  });
  testWidgets(
    'a native failure is actionable and never pushes a Material viewer',
    (tester) async {
      native.shows = false;
      await pump(
        tester,
        ChatAttachment(
          name: 'photo.png',
          kind: AttachmentKind.image,
          bytes: kTinyPng,
        ),
      );
      await open(tester);
      expect(
        find.text('Could not open this photo. Try again.'),
        findsOneWidget,
      );
      expect(find.byType(ImageViewerPage), findsNothing);
      native.shows = true;
      await open(tester);
      expectStagedPhoto();
    },
  );
  testWidgets('sign-out clears the native preview and cached file', (
    tester,
  ) async {
    await pump(
      tester,
      ChatAttachment(
        name: 'photo.png',
        kind: AttachmentKind.image,
        bytes: kTinyPng,
      ),
    );
    await open(tester);
    final path = native.shown!;
    await tester.runAsync(store.clear);
    expect(native.shown, isNull);
    expect(File(path).existsSync(), isFalse);
  });
  testWidgets('a photo finishing staging after sign-out is not presented', (
    tester,
  ) async {
    final directory = Completer<Directory>();
    final held = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () => directory.future,
      quickLook: native,
    );
    addTearDown(held.dispose);
    await pump(
      tester,
      ChatAttachment(
        name: 'photo.png',
        kind: AttachmentKind.image,
        bytes: kTinyPng,
      ),
      media: held,
    );
    final point = tester.getTopLeft(find.byType(Image)) + const Offset(.5, .5);
    await tester.runAsync(() => tester.tapAt(point));
    var cleared = false;
    unawaited(held.clear().then((_) => cleared = true));
    directory.complete(cache);
    await tester.pump();
    await waitUntil(
      tester,
      () => cleared && find.byType(LinearProgressIndicator).evaluate().isEmpty,
    );
    expect(cleared, isTrue);
    expect(native.previewed, isEmpty);
  });
  testWidgets(
    'removing the thumbnail while preparing a photo cancels presentation',
    (tester) async {
      final directory = Completer<Directory>();
      final held = MediaStore(
        source: HermesMediaSource(() => server.client()),
        cacheDirectory: () => directory.future,
        quickLook: native,
      );
      addTearDown(held.dispose);
      await pump(
        tester,
        ChatAttachment(
          name: 'photo.png',
          kind: AttachmentKind.image,
          bytes: kTinyPng,
        ),
        media: held,
      );
      final point =
          tester.getTopLeft(find.byType(Image)) + const Offset(.5, .5);
      await tester.runAsync(() => tester.tapAt(point));
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        directory.complete(cache);
        await held.stageBytes(
          'embedded:${sha256.convert(kTinyPng)}',
          'photo.png',
          kTinyPng,
        );
        await pumpEventQueue();
      });
      expect(native.previewed, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('the photo thumbnail exposes a named button to VoiceOver', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await pump(
        tester,
        ChatAttachment(
          name: 'photo.png',
          kind: AttachmentKind.image,
          bytes: kTinyPng,
        ),
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel('photo.png').first,
      );
      expect(
        node,
        isSemantics(
          label: 'photo.png',
          isButton: true,
          isImage: true,
          hasTapAction: true,
        ),
      );
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('opening a photo dismisses the composer keyboard', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await pump(
      tester,
      ChatAttachment(
        name: 'photo.png',
        kind: AttachmentKind.image,
        bytes: kTinyPng,
      ),
      before: TextField(focusNode: focus),
    );
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await open(tester);
    expect(focus.hasFocus, isFalse);
    expectStagedPhoto();
  });
  for (final background in [false, true]) {
    testWidgets(
      'a delayed preview is cancelled after ${background ? 'backgrounding' : 'navigating away'}',
      (tester) async {
        final directory = Completer<Directory>();
        final held = MediaStore(
          source: HermesMediaSource(() => server.client()),
          cacheDirectory: () => directory.future,
          quickLook: native,
        );
        addTearDown(held.dispose);
        await pump(
          tester,
          ChatAttachment(
            name: 'photo.png',
            kind: AttachmentKind.image,
            bytes: kTinyPng,
          ),
          media: held,
        );
        final point =
            tester.getTopLeft(find.byType(Image)) + const Offset(.5, .5);
        await tester.runAsync(() => tester.tapAt(point));
        if (background) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
        } else {
          unawaited(
            Navigator.of(tester.element(find.byType(AttachmentThumbnail)))
                .push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const Scaffold(body: Text('Another screen')),
                  ),
                ),
          );
        }
        directory.complete(cache);
        await tester.pump();
        await tester.runAsync(() async {
          await held.stageBytes(
            'embedded:${sha256.convert(kTinyPng)}',
            'photo.png',
            kTinyPng,
          );
          await pumpEventQueue();
        });
        await tester.pump();
        expect(native.previewed, isEmpty);
        if (background) {
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
        }
      },
    );
  }
}
