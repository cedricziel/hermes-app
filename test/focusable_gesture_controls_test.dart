import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/chat_models.dart';
import 'package:hermes_app/src/chat/media/media_store.dart';
import 'package:hermes_app/src/chat/media/media_source.dart';
import 'package:hermes_app/src/chat/widgets/attachment_views.dart';
import 'package:hermes_app/src/chat/widgets/image_viewer.dart';
import 'package:hermes_app/src/macos/mac_source_list.dart';
import 'package:hermes_app/src/macos/mac_toolbar_search_field.dart';
import 'package:hermes_app/src/theme/focus_ring.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/widgets/settings_search_field.dart';
import 'package:provider/provider.dart';

import 'support/attachment_fixtures.dart';
import 'support/fake_hermes_server.dart';
import 'support/fake_quick_look.dart';

/// The gesture-detector controls of F.441 take keyboard focus: Tab reaches
/// them, Enter and Space activate them once, a pointer press shows no ring.
void main() {
  setUp(resetFocusRingInput);

  final ring = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.foregroundPainter is FocusRingPainter,
  );

  /// Whether the primary focus is a node of the control keyed [key] (the
  /// focus node sits above the keyed tap box, or below it).
  bool focusIn(Key key) {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    var found = false;
    context.visitAncestorElements((e) {
      found = e.widget.key == key;
      return !found;
    });
    if (found) return true;
    void walk(Element e) {
      if (found) return;
      if (e.widget.key == key) found = true;
      e.visitChildren(walk);
    }

    (context as Element).visitChildren(walk);
    return found;
  }

  Future<void> tab(WidgetTester tester, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
  }

  group('settings search clear button', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      group(platform.name, () {
        const clear = Key('settings-search-clear');
        late List<String> changes;

        Future<void> pump(WidgetTester tester, {bool keepQuery = false}) async {
          changes = [];
          var query = 'kan';
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHermesLightTheme(platform: platform),
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) => SettingsSearchField(
                    search: SettingsSearch(
                      query: query,
                      onChanged: (q) {
                        changes.add(q);
                        if (!keepQuery) setState(() => query = q);
                      },
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        testWidgets('Tab reaches it, after the field', (tester) async {
          await pump(tester);
          await tab(tester);
          expect(focusIn(const Key('settings-search-field')), isTrue);
          await tab(tester);
          expect(focusIn(clear), isTrue);
          expect(ring, findsOneWidget);
        });

        for (final (name, key) in [
          ('Enter', LogicalKeyboardKey.enter),
          ('Space', LogicalKeyboardKey.space),
        ]) {
          testWidgets('$name clears the search once and refocuses the field', (
            tester,
          ) async {
            await pump(tester);
            await tab(tester, 2);
            await tester.sendKeyEvent(key);
            await tester.pump();
            expect(changes, ['']);
            expect(find.byKey(clear), findsNothing);
            final field = tester.widget<TextField>(
              find.byKey(const Key('settings-search-field')),
            );
            expect(
              field.focusNode!.hasPrimaryFocus,
              isTrue,
              reason: 'the button is gone, so the field takes the focus',
            );
          });
        }

        testWidgets('a pointer press shows no ring, the keyboard does', (
          tester,
        ) async {
          await pump(tester, keepQuery: true);
          await tester.tap(find.byKey(clear));
          await tester.pump();
          expect(changes, ['']);
          expect(ring, findsNothing, reason: 'after a pointer press');
          // The click put the focus in the field.
          await tab(tester);
          expect(focusIn(clear), isTrue);
          expect(ring, findsOneWidget, reason: 'with keyboard focus');
        });
      });
    }
  });

  group('Mac toolbar End search button', () {
    const end = Key('toolbar-search-clear');
    late List<String> events;

    Future<void> pump(WidgetTester tester, {bool keepQuery = false}) async {
      events = [];
      var query = 'backup';
      var active = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: StatefulBuilder(
                builder: (context, setState) => MacToolbarSearchField(
                  query: query,
                  active: active,
                  onChanged: (q) => events.add('changed:$q'),
                  onBegin: () => events.add('begin'),
                  onEnd: () {
                    events.add('end');
                    if (keepQuery) return;
                    setState(() {
                      query = '';
                      active = false;
                    });
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Tab reaches it, after the field', (tester) async {
      await pump(tester);
      await tab(tester);
      expect(focusIn(const Key('toolbar-search-field')), isTrue);
      await tab(tester);
      expect(focusIn(end), isTrue);
      expect(ring, findsOneWidget);
    });

    for (final (name, key) in [
      ('Enter', LogicalKeyboardKey.enter),
      ('Space', LogicalKeyboardKey.space),
    ]) {
      testWidgets('$name ends the search once and does not begin another', (
        tester,
      ) async {
        await pump(tester);
        await tab(tester, 2);
        events.clear();
        await tester.sendKeyEvent(key);
        await tester.pumpAndSettle();
        expect(events, ['end']);
        expect(find.byKey(end), findsNothing);
        final field = tester.widget<TextField>(
          find.byKey(const Key('toolbar-search-field')),
        );
        expect(
          field.focusNode?.hasFocus ?? false,
          isFalse,
          reason: 'the field is not refocused, which would begin a search',
        );
        expect(tester.getSize(find.byType(MacToolbarSearchField)).width, 180);
      });
    }

    testWidgets('Escape still ends the search', (tester) async {
      await pump(tester);
      await tab(tester);
      events.clear();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(events, ['end']);
    });

    testWidgets('a pointer press shows no ring, the keyboard does', (
      tester,
    ) async {
      await pump(tester, keepQuery: true);
      await tester.tap(find.byKey(end));
      await tester.pump();
      expect(events, ['end']);
      expect(ring, findsNothing);
      await tab(tester, 2);
      expect(focusIn(end), isTrue);
      expect(ring, findsOneWidget);
    });
  });

  group('Mac sidebar section header', () {
    late int toggles;

    Future<void> pump(WidgetTester tester, {bool collapsed = false}) async {
      toggles = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesLightTheme(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 260,
                child: Column(
                  children: [
                    MacSidebarSectionHeader(
                      key: const Key('header'),
                      label: 'Today',
                      collapsed: collapsed,
                      onToggle: () => toggles++,
                    ),
                    TextButton(onPressed: () {}, child: const Text('After')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    double chevron(WidgetTester tester) => tester
        .widget<Opacity>(
          find.descendant(
            of: find.byType(MacSidebarSectionHeader),
            matching: find.byType(Opacity),
          ),
        )
        .opacity;

    testWidgets('Tab reaches it', (tester) async {
      await pump(tester);
      await tab(tester);
      expect(focusIn(const Key('header')), isTrue);
      expect(ring, findsOneWidget);
    });

    for (final (name, key) in [
      ('Enter', LogicalKeyboardKey.enter),
      ('Space', LogicalKeyboardKey.space),
    ]) {
      testWidgets('$name folds or opens the section once', (tester) async {
        await pump(tester);
        await tab(tester);
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(toggles, 1);
      });
    }

    testWidgets('the chevron shows with keyboard focus, not at rest', (
      tester,
    ) async {
      await pump(tester, collapsed: true);
      expect(chevron(tester), 0);
      await tab(tester);
      expect(chevron(tester), 1);
      await tab(tester);
      expect(chevron(tester), 0, reason: 'focus left the header');
    });

    testWidgets('a pointer press shows no ring and no chevron once the '
        'pointer leaves, the keyboard shows both', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(MacSidebarSectionHeader));
      await tester.pump();
      expect(toggles, 1);
      expect(ring, findsNothing);
      await tab(tester);
      expect(ring, findsOneWidget);
    });

    testWidgets('keeps its button and expanded semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      expect(
        tester.getSemantics(find.byType(MacSidebarSectionHeader)),
        isSemantics(
          isButton: true,
          isExpanded: true,
          hasTapAction: true,
          label: 'Today',
        ),
      );
      handle.dispose();
    });
  });

  group('image thumbnail', () {
    const thumb = Key('thumb');
    final photo = ChatAttachment(
      name: 'photo.png',
      kind: AttachmentKind.image,
      bytes: kTinyPng,
    );
    late FakeHermesServer server;
    late FakeQuickLook native;
    late Directory cache;
    late MediaStore store;

    setUp(() {
      server = FakeHermesServer();
      native = FakeQuickLook();
      cache = tempDir('f441_thumb');
      store = MediaStore(
        source: HermesMediaSource(() => server.client()),
        cacheDirectory: () async => cache,
        quickLook: native,
      );
      addTearDown(store.dispose);
    });

    Future<void> pump(WidgetTester tester, TargetPlatform platform) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        Provider<MediaStore?>.value(
          value: store,
          child: MaterialApp(
            theme: buildHermesLightTheme(platform: platform),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: AttachmentThumbnail(key: thumb, attachment: photo),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    final detector = find.descendant(
      of: find.byType(AttachmentThumbnail),
      matching: find.byType(FocusableActionDetector),
    );

    testWidgets('Material: Tab reaches it and Enter opens the viewer once', (
      tester,
    ) async {
      await pump(tester, TargetPlatform.android);
      await tab(tester);
      expect(ring, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerPage), findsOneWidget);
    });

    testWidgets('Material: Space opens the viewer, and closing it brings the '
        'focus back to the thumbnail', (tester) async {
      await pump(tester, TargetPlatform.android);
      await tab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(ImageViewerPage))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerPage), findsNothing);
      expect(focusIn(thumb), isTrue);
    });

    testWidgets('iPhone: Enter asks Quick Look once and keeps the focus on '
        'the thumbnail', (tester) async {
      await pump(tester, TargetPlatform.iOS);
      await tab(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      for (var i = 0; i < 100 && native.previewed.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await tester.pump();
      }
      expect(native.previewed, hasLength(1));
      expect(find.byType(ImageViewerPage), findsNothing);
      expect(focusIn(thumb), isTrue, reason: 'the thumbnail keeps the focus');
      expect(ring, findsOneWidget);
    });

    testWidgets('a pointer press opens it and shows no ring', (tester) async {
      await pump(tester, TargetPlatform.android);
      await tester.tap(find.byType(ImageThumbnailView));
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerPage), findsOneWidget);
      expect(ring, findsNothing);
    });

    testWidgets('Mac: no tab stop, a click does not open it', (tester) async {
      await pump(tester, TargetPlatform.macOS);
      expect(detector, findsNothing);
      await tab(tester);
      expect(ring, findsNothing);
      await tester.tap(find.byType(ImageThumbnailView));
      await tester.pumpAndSettle();
      expect(find.byType(ImageViewerPage), findsNothing);
    });
  });
}
