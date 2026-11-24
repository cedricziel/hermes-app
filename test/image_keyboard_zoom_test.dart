import 'dart:io';

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/chat/widgets/image_viewer.dart';
import 'package:hermes_app/src/files/widgets/file_previews.dart';
import 'package:hermes_app/src/macos/menu_layout.dart';

import 'support/attachment_fixtures.dart';

/// Both image viewers outside iOS Quick Look answer the same keys through one
/// building block (`ZoomKeyboardShortcuts`), so each case runs against both.
class _Viewer {
  const _Viewer(this.name, this.pump);

  final String name;
  final Future<void> Function(WidgetTester, TargetPlatform) pump;
}

/// Keys that reached a widget above the viewer, so were not consumed by it.
final _bubbled = <LogicalKeyboardKey>[];

Future<void> _app(WidgetTester tester, TargetPlatform platform, Widget home) {
  tester.view
    ..physicalSize = const Size(800, 600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(platform: platform),
      home: Focus(
        canRequestFocus: false,
        onKeyEvent: (_, event) {
          if (event is KeyDownEvent) _bubbled.add(event.logicalKey);
          return KeyEventResult.ignored;
        },
        child: home,
      ),
    ),
  );
}

final _viewers = [
  _Viewer('ImageViewerPage', (tester, platform) async {
    await _app(
      tester,
      platform,
      ImageViewerPage(image: MemoryImage(kTinyPng), name: 'cat.png'),
    );
    await tester.pump();
  }),
  _Viewer('ImagePreview', (tester, platform) async {
    final image = MemoryImage(kTinyPng);
    await _app(
      tester,
      platform,
      Scaffold(
        body: ImagePreview(image: image, label: 'cat.png'),
      ),
    );
    await tester.runAsync(
      () => precacheImage(image, tester.element(find.byType(ImagePreview))),
    );
    await tester.pump();
  }),
];

InteractiveViewer _viewer(WidgetTester tester) =>
    tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));

double _scale(WidgetTester tester) =>
    _viewer(tester).transformationController!.value.getMaxScaleOnAxis();

Offset _shift(WidgetTester tester) {
  final t = _viewer(tester).transformationController!.value.getTranslation();
  return Offset(t.x, t.y);
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  LogicalKeyboardKey? modifier = LogicalKeyboardKey.controlLeft,
  List<LogicalKeyboardKey> also = const [],
}) async {
  final held = [?modifier, ...also];
  for (final k in held) {
    await tester.sendKeyDownEvent(k);
  }
  await tester.sendKeyEvent(key);
  for (final k in held.reversed) {
    await tester.sendKeyUpEvent(k);
  }
  await tester.pump();
}

void main() {
  setUp(_bubbled.clear);

  for (final viewer in _viewers) {
    group('${viewer.name} keyboard zoom', () {
      testWidgets('Ctrl+= zooms in, Ctrl+- zooms out, with no click first', (
        tester,
      ) async {
        await viewer.pump(tester, TargetPlatform.windows);
        expect(_scale(tester), 1);

        await _chord(tester, LogicalKeyboardKey.equal);
        final once = _scale(tester);
        expect(once, greaterThan(1));
        await _chord(tester, LogicalKeyboardKey.equal);
        expect(_scale(tester), greaterThan(once));

        await _chord(tester, LogicalKeyboardKey.minus);
        expect(_scale(tester), closeTo(once, 1e-9));
      });

      testWidgets('Ctrl+Shift+= (the plus key) and the keypad zoom', (
        tester,
      ) async {
        await viewer.pump(tester, TargetPlatform.linux);

        await _chord(
          tester,
          LogicalKeyboardKey.equal,
          also: [LogicalKeyboardKey.shiftLeft],
        );
        final first = _scale(tester);
        expect(first, greaterThan(1));
        await _chord(tester, LogicalKeyboardKey.numpadAdd);
        expect(_scale(tester), greaterThan(first));
        await _chord(tester, LogicalKeyboardKey.numpadSubtract);
        expect(_scale(tester), closeTo(first, 1e-9));
      });

      testWidgets('zooms about the middle of the viewport', (tester) async {
        await viewer.pump(tester, TargetPlatform.linux);
        final box = tester.getSize(find.byType(InteractiveViewer));

        await _chord(tester, LogicalKeyboardKey.equal);

        final s = _scale(tester);
        final shift = _shift(tester);
        expect(shift.dx, closeTo(box.width / 2 * (1 - s), 1e-6));
        expect(shift.dy, closeTo(box.height / 2 * (1 - s), 1e-6));
      });

      testWidgets('Ctrl+0 resets to fit', (tester) async {
        await viewer.pump(tester, TargetPlatform.windows);
        await _chord(tester, LogicalKeyboardKey.equal);
        await _chord(tester, LogicalKeyboardKey.equal);
        await _chord(tester, LogicalKeyboardKey.arrowRight, modifier: null);
        expect(_scale(tester), greaterThan(1));

        await _chord(tester, LogicalKeyboardKey.digit0);

        expect(
          _viewer(tester).transformationController!.value,
          Matrix4.identity(),
        );
      });

      testWidgets('zoom stops at the viewer maximum and at fit', (
        tester,
      ) async {
        await viewer.pump(tester, TargetPlatform.linux);
        final max = _viewer(tester).maxScale;

        await _chord(tester, LogicalKeyboardKey.minus);
        expect(_scale(tester), 1);
        expect(_shift(tester), Offset.zero);

        for (var i = 0; i < 12; i++) {
          await _chord(tester, LogicalKeyboardKey.equal);
        }
        expect(_scale(tester), closeTo(max, 1e-9));
        for (var i = 0; i < 12; i++) {
          await _chord(tester, LogicalKeyboardKey.minus);
        }
        expect(_scale(tester), closeTo(1, 1e-9));
        expect(_shift(tester).dx, closeTo(0, 1e-6));
        expect(_shift(tester).dy, closeTo(0, 1e-6));
      });

      testWidgets('arrows pan a zoomed picture and stay inside its edge', (
        tester,
      ) async {
        await viewer.pump(tester, TargetPlatform.linux);
        final box = tester.getSize(find.byType(InteractiveViewer));
        await _chord(tester, LogicalKeyboardKey.equal);
        await _chord(tester, LogicalKeyboardKey.equal);
        final s = _scale(tester);
        final start = _shift(tester);

        await _chord(tester, LogicalKeyboardKey.arrowRight, modifier: null);
        final right = _shift(tester);
        expect(right.dx, lessThan(start.dx));
        expect(right.dy, start.dy);

        await _chord(tester, LogicalKeyboardKey.arrowDown, modifier: null);
        expect(_shift(tester).dy, lessThan(start.dy));

        for (var i = 0; i < 40; i++) {
          await _chord(tester, LogicalKeyboardKey.arrowRight, modifier: null);
          await _chord(tester, LogicalKeyboardKey.arrowDown, modifier: null);
        }
        expect(_shift(tester).dx, closeTo(box.width * (1 - s), 1e-6));
        expect(_shift(tester).dy, closeTo(box.height * (1 - s), 1e-6));

        for (var i = 0; i < 80; i++) {
          await _chord(tester, LogicalKeyboardKey.arrowLeft, modifier: null);
          await _chord(tester, LogicalKeyboardKey.arrowUp, modifier: null);
        }
        expect(_shift(tester).dx, closeTo(0, 1e-6));
        expect(_shift(tester).dy, closeTo(0, 1e-6));
        expect(_scale(tester), closeTo(s, 1e-9));
      });

      testWidgets('arrows do nothing at fit and are not consumed', (
        tester,
      ) async {
        await viewer.pump(tester, TargetPlatform.linux);
        _bubbled.clear();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();

        expect(_scale(tester), 1);
        expect(_shift(tester), Offset.zero);
        expect(_bubbled, [LogicalKeyboardKey.arrowLeft]);
      });

      testWidgets('arrows are consumed while zoomed', (tester) async {
        await viewer.pump(tester, TargetPlatform.linux);
        await _chord(tester, LogicalKeyboardKey.equal);
        _bubbled.clear();

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();

        expect(_bubbled, isEmpty);
      });

      testWidgets('the viewer has keyboard focus when it opens', (
        tester,
      ) async {
        await viewer.pump(tester, TargetPlatform.linux);

        final focused = FocusManager.instance.primaryFocus!.context!;
        expect(
          find.descendant(
            of: find.byElementPredicate((e) => e == focused),
            matching: find.byType(InteractiveViewer),
          ),
          findsOneWidget,
        );
      });

      testWidgets('a tap on the picture gives it focus back', (tester) async {
        await viewer.pump(tester, TargetPlatform.linux);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();

        await tester.tap(find.byType(InteractiveViewer));
        await tester.pump(kDoubleTapTimeout);
        await _chord(tester, LogicalKeyboardKey.equal);

        expect(_scale(tester), greaterThan(1));
      });

      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        testWidgets('on $platform Cmd does nothing', (tester) async {
          await viewer.pump(tester, platform);

          await _chord(
            tester,
            LogicalKeyboardKey.equal,
            modifier: LogicalKeyboardKey.metaLeft,
          );

          expect(_scale(tester), 1);
        });
      }

      for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
        testWidgets('on $platform Cmd zooms and Ctrl does nothing', (
          tester,
        ) async {
          await viewer.pump(tester, platform);

          await _chord(tester, LogicalKeyboardKey.equal);
          expect(_scale(tester), 1);

          await _chord(
            tester,
            LogicalKeyboardKey.equal,
            modifier: LogicalKeyboardKey.metaLeft,
          );
          expect(_scale(tester), greaterThan(1));
        });
      }

      testWidgets('on macOS reset is Cmd+Option+0, as Cmd+0 is the menu\'s', (
        tester,
      ) async {
        await viewer.pump(tester, TargetPlatform.macOS);
        await _chord(
          tester,
          LogicalKeyboardKey.equal,
          modifier: LogicalKeyboardKey.metaLeft,
        );

        await _chord(
          tester,
          LogicalKeyboardKey.digit0,
          modifier: LogicalKeyboardKey.metaLeft,
        );
        expect(_scale(tester), greaterThan(1));

        await _chord(
          tester,
          LogicalKeyboardKey.digit0,
          modifier: LogicalKeyboardKey.metaLeft,
          also: [LogicalKeyboardKey.altLeft],
        );
        expect(_scale(tester), 1);
      });

      testWidgets('on iPadOS Cmd+0 resets', (tester) async {
        await viewer.pump(tester, TargetPlatform.iOS);
        await _chord(
          tester,
          LogicalKeyboardKey.equal,
          modifier: LogicalKeyboardKey.metaLeft,
        );

        await _chord(
          tester,
          LogicalKeyboardKey.digit0,
          modifier: LogicalKeyboardKey.metaLeft,
        );

        expect(_scale(tester), 1);
      });
    });
  }

  group('menu chords', () {
    String describe(SingleActivator a) =>
        '${a.meta ? 'meta+' : ''}${a.control ? 'ctrl+' : ''}'
        '${a.alt ? 'alt+' : ''}${a.shift ? 'shift+' : ''}${a.trigger.keyLabel}';

    SingleActivator cmd(LogicalKeyboardKey k, {bool alt = false}) =>
        SingleActivator(k, meta: true, alt: alt);
    SingleActivator ctrl(LogicalKeyboardKey k) =>
        SingleActivator(k, control: true);

    // What the viewer binds per platform; the first two keys are shared.
    final byPlatform = {
      MenuPlatform.mac: [
        cmd(LogicalKeyboardKey.equal),
        cmd(LogicalKeyboardKey.minus),
        cmd(LogicalKeyboardKey.digit0, alt: true),
      ],
      MenuPlatform.ipad: [
        cmd(LogicalKeyboardKey.equal),
        cmd(LogicalKeyboardKey.minus),
        cmd(LogicalKeyboardKey.digit0),
      ],
      MenuPlatform.desktop: [
        ctrl(LogicalKeyboardKey.equal),
        ctrl(LogicalKeyboardKey.minus),
        ctrl(LogicalKeyboardKey.digit0),
      ],
    };

    test('no menu entry owns a chord the viewers bind', () {
      for (final MapEntry(key: platform, value: chords) in byPlatform.entries) {
        final owned = {
          for (final section in menuLayout)
            for (final group in section.groups)
              for (final entry in group)
                for (final chord in entry.shortcutsOn(platform))
                  describe(chord),
        };
        expect(
          chords.map(describe).toSet().intersection(owned),
          isEmpty,
          reason: '$platform',
        );
      }
    });

    test('the Mac bar\'s own chords leave the viewer chords alone', () {
      final source = File('lib/src/macos/mac_menu_bar.dart').readAsStringSync();
      final owned = {
        for (final m in RegExp(
          r'metaActivator\(\s*LogicalKeyboardKey\.(\w+)((?:,\s*\w+: true)*)',
        ).allMatches(source))
          '${m[1]}|${m[2]!.contains('alt') ? 'alt' : ''}',
      };
      // Cmd+0 is the Window menu's "Hermes", the reason macOS resets on
      // Cmd+Option+0.
      expect(owned, contains('digit0|'));
      expect(owned, isNot(contains('equal|')));
      expect(owned, isNot(contains('minus|')));
      expect(owned, isNot(contains('digit0|alt')));
    });
  });
}
