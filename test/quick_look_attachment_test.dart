import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otel/flutter_otel.dart' show BreadcrumbTrail;
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/api/hermes_repositories.dart';
import 'package:hermes_app/src/chat/attachments/draggable_attachment.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/chat/widgets/quick_look_target.dart';
import 'package:hermes_app/src/drag_out/drag_out_source.dart';
import 'package:hermes_app/src/drag_out/mac_drag_out_source.dart';
import 'package:hermes_app/src/telemetry/breadcrumbs.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:provider/provider.dart';

import 'support/attachment_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_media_actions.dart';
import 'support/fake_quick_look.dart';
import 'support/recorded_events.dart';

void main() {
  late FakeHermesServer server;
  late FakeMediaActions actions;
  late FakeQuickLook quickLook;
  late Directory cache;
  late MediaStore store;
  late BreadcrumbTrail trail;
  late RecordedEvents events;

  setUp(() {
    server = FakeHermesServer();
    actions = FakeMediaActions();
    quickLook = FakeQuickLook();
    cache = tempDir('quick_look_attachment');
    trail = BreadcrumbTrail();
    events = RecordedEvents();
    store = MediaStore(
      source: HermesMediaSource(() => server.client()),
      cacheDirectory: () async => cache,
      actions: actions,
      quickLook: quickLook,
    );
  });

  final pdf = Uint8List.fromList('%PDF-1.7 fake'.codeUnits);
  const remote = ChatAttachment(
    name: 'report.pdf',
    kind: AttachmentKind.file,
    remotePath: '/srv/report.pdf',
    size: 2048,
  );

  int downloads() => server.requestsTo('GET', '/api/files/download').length;

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    TargetPlatform platform = TargetPlatform.macOS,
    DragOutSource? dragOut,
  }) async {
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<MediaStore?>.value(value: store),
          Provider<DragOutSource?>.value(value: dragOut),
          Provider<Breadcrumbs>.value(value: Breadcrumbs.of(trail)),
          Provider<HermesRepositories?>.value(
            value: HermesRepositories(
              server.client(),
              telemetry: events.connection(const {}),
            ),
          ),
        ],
        child: MaterialApp(
          theme: buildHermesLightTheme().copyWith(platform: platform),
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: child),
          ),
        ),
      ),
    );
  }

  // File I/O and the fake server need real time.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> click(
    WidgetTester tester,
    Finder finder, {
    int buttons = kPrimaryMouseButton,
  }) async {
    await tester.runAsync(
      () => tester.tap(finder, kind: PointerDeviceKind.mouse, buttons: buttons),
    );
    await tester.pump();
  }

  Future<void> doubleClick(WidgetTester tester, Finder finder) async {
    await click(tester, finder);
    await tester.pump(const Duration(milliseconds: 60));
    await click(tester, finder);
  }

  Future<void> pressSpace(WidgetTester tester) async {
    await tester.runAsync(() => tester.sendKeyEvent(LogicalKeyboardKey.space));
    await tester.pump();
  }

  Future<void> select(WidgetTester tester) async {
    await click(tester, find.text('report.pdf'));
  }

  bool selected(WidgetTester tester) => tester
      .widget<QuickLookSelectionFrame>(find.byType(QuickLookSelectionFrame))
      .selected;

  group('a file card', () {
    testWidgets('a click selects and fetches nothing', (tester) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pump(tester, const AttachmentCard(attachment: remote));

      await select(tester);
      await settle(tester);

      expect(selected(tester), isTrue);
      expect(downloads(), 0);
      expect(actions.opened, isEmpty);
    });

    testWidgets('a double-click downloads once and opens the file', (
      tester,
    ) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pump(tester, const AttachmentCard(attachment: remote));

      await doubleClick(tester, find.text('report.pdf'));
      await settle(tester);

      expect(downloads(), 1);
      expect(actions.opened.single, endsWith('/report.pdf'));
      expect(quickLook.previewed, isEmpty);
    });

    testWidgets('Space downloads once, previews, and closes on a second Space '
        'without a request', (tester) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pump(tester, const AttachmentCard(attachment: remote));
      await select(tester);

      await pressSpace(tester);
      await settle(tester);
      expect(downloads(), 1);
      expect(quickLook.shown, endsWith('/report.pdf'));
      expect(File(quickLook.shown!).readAsBytesSync(), pdf);

      await pressSpace(tester);
      await settle(tester);
      expect(downloads(), 1);
      expect(quickLook.shown, isNull);
    });

    testWidgets('shows Downloading… until the file is there, and a second '
        'press meanwhile starts no second request', (tester) async {
      final gate = Completer<void>();
      server.onRequest('GET', '/api/files/download', (_) async {
        await gate.future;
        return (status: 200, body: pdf);
      });
      await pump(tester, const AttachmentCard(attachment: remote));
      await select(tester);

      await pressSpace(tester);
      await settle(tester);
      expect(find.text('Downloading…'), findsOneWidget);
      await pressSpace(tester);
      await doubleClick(tester, find.text('Downloading…'));
      gate.complete();
      await settle(tester);

      expect(downloads(), 1);
      expect(quickLook.previewed, hasLength(1));
      expect(find.text('Downloading…'), findsNothing);
      expect(actions.opened, isEmpty);
    });

    testWidgets('a file already downloaded for Open is not fetched again', (
      tester,
    ) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pump(tester, const AttachmentCard(attachment: remote));
      await doubleClick(tester, find.text('report.pdf'));
      await settle(tester);

      await pressSpace(tester);
      await settle(tester);

      expect(downloads(), 1);
      expect(quickLook.shown, actions.opened.single);
    });

    for (final (status, message) in [
      (404, 'This file is no longer available.'),
      (403, "This file can't be opened from here."),
      (413, 'This file is too large to download.'),
    ]) {
      testWidgets('a $status says so and opens nothing', (tester) async {
        server.onDownloadFailure(status);
        await pump(tester, const AttachmentCard(attachment: remote));
        await select(tester);

        await pressSpace(tester);
        await settle(tester);

        expect(find.text(message), findsOneWidget);
        expect(quickLook.previewed, isEmpty);
        expect(selected(tester), isTrue, reason: 'Space can try again');
      });
    }

    testWidgets('a panel that cannot show the file says so', (tester) async {
      server.onDownload('/srv/report.pdf', pdf);
      quickLook.shows = false;
      await pump(tester, const AttachmentCard(attachment: remote));
      await select(tester);

      await pressSpace(tester);
      await settle(tester);

      expect(find.text("Quick Look couldn't preview this file."), findsOne);
    });

    testWidgets('signing out while it downloads opens nothing', (tester) async {
      final gate = Completer<void>();
      server.onRequest('GET', '/api/files/download', (_) async {
        await gate.future;
        return (status: 200, body: pdf);
      });
      await pump(tester, const AttachmentCard(attachment: remote));
      await select(tester);
      await pressSpace(tester);
      await settle(tester);

      await tester.runAsync(store.clear);
      gate.complete();
      await settle(tester);

      expect(quickLook.previewed, isEmpty);
      expect(
        cache.existsSync()
            ? cache.listSync(recursive: true).whereType<File>()
            : <File>[],
        isEmpty,
      );
    });

    testWidgets('the menu selects, then previews without toggling', (
      tester,
    ) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pump(tester, const AttachmentCard(attachment: remote));

      await click(
        tester,
        find.text('report.pdf'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      expect(selected(tester), isTrue);
      await tester.runAsync(() => tester.tap(find.text('Quick Look')));
      await settle(tester);
      expect(quickLook.previewed, hasLength(1));

      await click(
        tester,
        find.text('report.pdf'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Quick Look')));
      await settle(tester);

      expect(quickLook.previewed, hasLength(2));
      expect(quickLook.shown, isNotNull);
      expect(downloads(), 1);
    });

    testWidgets('the menu saves', (tester) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pump(tester, const AttachmentCard(attachment: remote));
      await click(
        tester,
        find.text('report.pdf'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() => tester.tap(find.text('Save…')));
      await settle(tester);

      expect(actions.saved.single.name, 'report.pdf');
      expect(actions.saved.single.bytes, pdf);
    });

    testWidgets('with nothing to fetch the menu is disabled', (tester) async {
      await pump(
        tester,
        const AttachmentCard(
          attachment: ChatAttachment(
            name: 'report.pdf',
            kind: AttachmentKind.file,
            remotePath: 'attachments/report.pdf',
          ),
        ),
      );
      await click(
        tester,
        find.text('report.pdf'),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quick Look'));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(downloads(), 0);
      expect(quickLook.previewed, isEmpty);
      expect(actions.opened, isEmpty);
    });

    testWidgets('bytes the history embedded are written and previewed', (
      tester,
    ) async {
      await pump(
        tester,
        AttachmentCard(
          attachment: ChatAttachment(
            name: 'notes.txt',
            kind: AttachmentKind.file,
            bytes: Uint8List.fromList([104, 105]),
          ),
        ),
      );
      await click(tester, find.text('notes.txt'));

      await pressSpace(tester);
      await settle(tester);

      expect(downloads(), 0);
      expect(quickLook.shown, startsWith(cache.path));
      expect(File(quickLook.shown!).readAsBytesSync(), [104, 105]);
    });

    testWidgets('a file the user picked is copied into the cache', (
      tester,
    ) async {
      final picked = writeTemp(tempDir('picked'), 'notes.txt', [1, 2, 3]);
      await pump(
        tester,
        AttachmentCard(
          attachment: ChatAttachment(
            name: 'notes.txt',
            kind: AttachmentKind.file,
            path: picked.path,
          ),
        ),
      );
      await click(tester, find.text('notes.txt'));

      await pressSpace(tester);
      await settle(tester);

      expect(quickLook.shown, startsWith(cache.path));
      expect(quickLook.shown, isNot(picked.path));
      expect(File(quickLook.shown!).readAsBytesSync(), [1, 2, 3]);
    });

    testWidgets('elsewhere a click opens and nothing is selectable', (
      tester,
    ) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pump(
        tester,
        const AttachmentCard(attachment: remote),
        platform: TargetPlatform.iOS,
      );

      await tester.runAsync(
        () =>
            tester.tap(find.text('report.pdf'), kind: PointerDeviceKind.mouse),
      );
      await settle(tester);
      await pressSpace(tester);
      await settle(tester);

      expect(find.byType(QuickLookSelectionFrame), findsNothing);
      expect(actions.opened, hasLength(1));
      expect(quickLook.previewed, isEmpty);
    });
  });

  group('the button and the menu agree', () {
    final embedded = ChatAttachment(
      name: 'notes.txt',
      kind: AttachmentKind.file,
      bytes: Uint8List.fromList([104, 105]),
    );

    testWidgets('on a Mac a file of the message has the Save button too', (
      tester,
    ) async {
      await pump(tester, AttachmentCard(attachment: embedded));

      await tester.runAsync(() => tester.tap(find.byTooltip('Save')));
      await settle(tester);

      expect(actions.saved.single.name, 'notes.txt');
      expect(actions.saved.single.bytes, [104, 105]);
    });

    testWidgets('elsewhere it has neither, as before Quick Look', (
      tester,
    ) async {
      await pump(
        tester,
        AttachmentCard(attachment: embedded),
        platform: TargetPlatform.iOS,
      );

      expect(find.byTooltip('Save'), findsNothing);
    });

    testWidgets('elsewhere a file with a server path comes from the server', (
      tester,
    ) async {
      server.onDownload('/srv/notes.txt', [1, 2, 3]);
      await pump(
        tester,
        AttachmentCard(
          attachment: ChatAttachment(
            name: 'notes.txt',
            kind: AttachmentKind.file,
            remotePath: '/srv/notes.txt',
            bytes: Uint8List.fromList([104, 105]),
          ),
        ),
        platform: TargetPlatform.iOS,
      );

      await tester.runAsync(() => tester.tap(find.byTooltip('Save')));
      await settle(tester);

      expect(downloads(), 1);
      expect(actions.saved.single.bytes, [1, 2, 3]);
    });
  });

  group('a picture that cannot be drawn', () {
    testWidgets('is one target, not two nested', (tester) async {
      await pump(
        tester,
        AttachmentThumbnail(
          attachment: ChatAttachment(
            name: 'broken.png',
            kind: AttachmentKind.image,
            bytes: Uint8List.fromList([1, 2, 3]),
          ),
        ),
      );
      await settle(tester);

      expect(find.byType(QuickLookTarget), findsOneWidget);
      expect(find.text('broken.png'), findsOneWidget);
    });
  });

  group('with drag-out', () {
    const channel = MethodChannel('test/quick_look_drag_out');
    late List<MethodCall> drags;
    late MacDragOutSource source;

    setUp(() {
      drags = [];
      source = MacDragOutSource(channel: channel);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            drags.add(call);
            return true;
          });
    });

    tearDown(() {
      source.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    testWidgets('a drag selects the card but never opens it', (tester) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pump(
        tester,
        const DraggableAttachment(
          attachment: remote,
          child: AttachmentCard(attachment: remote),
        ),
        dragOut: source,
      );

      // The press moves past the slop, the drag starts, and the release comes
      // from the synthetic mouse up, wherever the drop was.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('report.pdf')),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(20, 0));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 60));
      await click(tester, find.text('report.pdf'));
      await settle(tester);

      expect(drags.single.method, 'startDrag');
      expect(selected(tester), isTrue);
      expect(downloads(), 0);
      expect(actions.opened, isEmpty);
    });

    testWidgets('a click and a double-click still work around it', (
      tester,
    ) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pump(
        tester,
        const DraggableAttachment(
          attachment: remote,
          child: AttachmentCard(attachment: remote),
        ),
        dragOut: source,
      );

      await select(tester);
      expect(selected(tester), isTrue);
      expect(actions.opened, isEmpty);
      await pressSpace(tester);
      await settle(tester);
      expect(quickLook.shown, isNotNull);
      await tester.pump(const Duration(seconds: 1));
      await doubleClick(tester, find.text('report.pdf'));
      await settle(tester);

      expect(drags, isEmpty);
      expect(actions.opened, hasLength(1));
      expect(downloads(), 1);
    });
  });

  group('telemetry', () {
    testWidgets('a shown panel leaves a crumb with the source and trigger', (
      tester,
    ) async {
      server.onDownload('/srv/report.pdf', pdf);
      await pump(tester, const AttachmentCard(attachment: remote));
      await select(tester);

      await pressSpace(tester);
      await settle(tester);
      await pressSpace(tester);
      await settle(tester);

      expect(
        [for (final c in trail.recent) '${c.name} ${c.attributes}'],
        ['quick_look.opened {source: chat, trigger: key}'],
      );
    });

    testWidgets('a failure logs the stage and reason, and nothing else', (
      tester,
    ) async {
      server.onDownloadFailure(404);
      await pump(tester, const AttachmentCard(attachment: remote));
      await select(tester);

      await pressSpace(tester);
      await settle(tester);

      expect(events.named('quick_look.failed'), [
        {'stage': 'download', 'reason': 'missing'},
      ]);
      expect(
        [for (final c in trail.recent) '${c.name} ${c.attributes}'],
        ['quick_look.failed {source: chat, trigger: key}'],
      );
    });

    testWidgets('a panel that does not show logs the native stage', (
      tester,
    ) async {
      server.onDownload('/srv/report.pdf', pdf);
      quickLook.shows = false;
      await pump(tester, const AttachmentCard(attachment: remote));
      await select(tester);

      await pressSpace(tester);
      await settle(tester);

      expect(events.named('quick_look.failed'), [
        {'stage': 'native', 'reason': 'unavailable'},
      ]);
    });

    testWidgets('names, paths and ids never reach telemetry', (tester) async {
      server.onDownloadFailure(404);
      await pump(tester, const AttachmentCard(attachment: remote));
      await select(tester);

      await pressSpace(tester);
      await settle(tester);

      final everything = [
        for (final c in trail.recent) '${c.name} ${c.attributes}',
        ...events.named('quick_look.failed').map((a) => '$a'),
      ].join(' ');
      expect(everything, isNot(contains('report')));
      expect(everything, isNot(contains('pdf')));
      expect(everything, isNot(contains('/srv')));
    });
  });

  group('an image thumbnail', () {
    final image = ChatAttachment(
      name: 'photo.png',
      kind: AttachmentKind.image,
      bytes: kTinyPng,
    );

    // The test image is one pixel; aim at its middle, not its corner.
    Future<void> clickImage(WidgetTester tester) async {
      final at = tester.getTopLeft(find.byType(Image)) + const Offset(.5, .5);
      await tester.runAsync(
        () => tester.tapAt(at, kind: PointerDeviceKind.mouse),
      );
      await tester.pump();
    }

    Future<void> pumpImage(WidgetTester tester) async {
      await pump(tester, AttachmentThumbnail(attachment: image));
      // Decoding the picture takes real time.
      await settle(tester);
    }

    testWidgets('a click selects without opening it full screen', (
      tester,
    ) async {
      await pumpImage(tester);

      await clickImage(tester);
      await tester.pumpAndSettle();

      expect(selected(tester), isTrue);
      expect(find.byType(InteractiveViewer), findsNothing);
    });

    testWidgets('a double-click opens it full screen', (tester) async {
      await pumpImage(tester);

      await clickImage(tester);
      await tester.pump(const Duration(milliseconds: 60));
      await clickImage(tester);
      await tester.pumpAndSettle();

      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('Space previews it', (tester) async {
      await pumpImage(tester);
      await clickImage(tester);

      await pressSpace(tester);
      await settle(tester);

      expect(File(quickLook.shown!).readAsBytesSync(), kTinyPng);
    });
  });
}
