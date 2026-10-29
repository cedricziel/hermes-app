import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/input/screen_gesture_layer.dart';
import 'package:hermes_app/src/bot_screen/widgets/bot_screen_key_bar.dart';
import 'package:hermes_app/src/bot_screen/widgets/takeover_confirmation.dart';
import 'package:hermes_app/src/bot_screen/widgets/trackpad_cursor.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';

Widget _app(Widget child, {TargetPlatform platform = TargetPlatform.android}) =>
    MaterialApp(
      theme: buildHermesDarkTheme(platform: platform),
      home: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: child),
      ),
    );

void main() {
  group('the key bar', () {
    late List<String> taps;

    Widget bar({
      bool ctrl = false,
      bool alt = false,
      bool keyboardOpen = false,
      ScreenGestureMode mode = ScreenGestureMode.touch,
    }) => BotScreenKeyBar(
      mode: mode,
      ctrl: ctrl,
      alt: alt,
      keyboardOpen: keyboardOpen,
      onMode: (mode) => taps.add('mode ${mode.name}'),
      onEscape: () => taps.add('esc'),
      onTab: () => taps.add('tab'),
      onLeft: () => taps.add('left'),
      onRight: () => taps.add('right'),
      onToggleCtrl: () => taps.add('ctrl'),
      onToggleAlt: () => taps.add('alt'),
      onToggleKeyboard: () => taps.add('keyboard'),
      onPaste: () => taps.add('paste'),
    );

    setUp(() => taps = []);

    testWidgets('has Esc, Tab, Ctrl, Alt, the arrows, the keyboard and Paste', (
      tester,
    ) async {
      await tester.pumpWidget(_app(bar()));

      await tester.tap(find.text('Esc'));
      await tester.tap(find.text('Tab'));
      await tester.tap(find.text('Ctrl'));
      await tester.tap(find.text('Alt'));
      await tester.tap(find.byTooltip('Left arrow'));
      await tester.tap(find.byTooltip('Right arrow'));
      await tester.tap(find.byTooltip('Keyboard'));
      await tester.tap(find.byTooltip('Paste'));

      expect(taps, [
        'esc',
        'tab',
        'ctrl',
        'alt',
        'left',
        'right',
        'keyboard',
        'paste',
      ]);
    });

    testWidgets('the mode switch offers the other mode', (tester) async {
      await tester.pumpWidget(_app(bar()));
      await tester.tap(find.byTooltip('Use Trackpad mode'));

      await tester.pumpWidget(_app(bar(mode: ScreenGestureMode.trackpad)));
      await tester.tap(find.byTooltip('Use Touch mode'));

      expect(taps, ['mode trackpad', 'mode touch']);
    });

    testWidgets('latched keys say so to assistive technology', (tester) async {
      await tester.pumpWidget(_app(bar(ctrl: true, keyboardOpen: true)));

      bool toggled(String label) =>
          tester
              .getSemantics(find.text(label))
              .getSemanticsData()
              .flagsCollection
              .isToggled ==
          ui.Tristate.isTrue;

      expect(toggled('Ctrl'), isTrue);
      expect(toggled('Alt'), isFalse);
      expect(
        tester.getSemantics(find.text('Ctrl')),
        matchesSemantics(
          label: 'Ctrl',
          isButton: true,
          isToggled: true,
          hasToggledState: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('scrolls instead of overflowing on a narrow phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
        await tester.pumpWidget(_app(bar(), platform: platform));
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('every key is a comfortable tap target on iOS', (tester) async {
      await tester.pumpWidget(_app(bar(), platform: TargetPlatform.iOS));

      for (final label in ['Esc', 'Tab', 'Ctrl', 'Alt']) {
        final box = tester.getRect(
          find
              .ancestor(of: find.text(label), matching: find.byType(Material))
              .first,
        );
        expect(box.height, greaterThanOrEqualTo(44), reason: label);
      }
    });
  });

  group('the take over question', () {
    testWidgets('says what taking over does', (tester) async {
      await tester.pumpWidget(
        _app(TakeoverConfirmation(onCancel: () {}, onConfirm: (_) {})),
      );

      expect(find.text('Take over the screen?'), findsOne);
      expect(find.textContaining('stops using the screen'), findsOne);
      expect(find.textContaining('tell it to continue'), findsOne);
      expect(find.textContaining('goes to the server'), findsOne);
      expect(find.textContaining('Hermes Desktop'), findsOne);
    });

    testWidgets('Take over answers without asking to stop asking', (
      tester,
    ) async {
      bool? answer;
      await tester.pumpWidget(
        _app(
          TakeoverConfirmation(onCancel: () {}, onConfirm: (v) => answer = v),
        ),
      );

      await tester.tap(find.text('Take over'));

      expect(answer, isFalse);
    });

    testWidgets('Don\'t ask again is carried by the answer', (tester) async {
      bool? answer;
      await tester.pumpWidget(
        _app(
          TakeoverConfirmation(onCancel: () {}, onConfirm: (v) => answer = v),
        ),
      );

      await tester.tap(find.text("Don't ask again"));
      await tester.pump();
      await tester.tap(find.text('Take over'));

      expect(answer, isTrue);
    });

    testWidgets('Cancel cancels', (tester) async {
      var cancelled = 0;
      await tester.pumpWidget(
        _app(
          TakeoverConfirmation(onCancel: () => cancelled++, onConfirm: (_) {}),
        ),
      );

      await tester.tap(find.text('Cancel'));

      expect(cancelled, 1);
    });

    testWidgets('fits a phone on every platform', (tester) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final platform in TargetPlatform.values) {
        await tester.pumpWidget(
          _app(
            SingleChildScrollView(
              child: TakeoverConfirmation(onCancel: () {}, onConfirm: (_) {}),
            ),
            platform: platform,
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull, reason: '$platform');
      }
    });
  });

  group('the trackpad cursor', () {
    testWidgets('sits where the virtual pointer is, in the picture', (
      tester,
    ) async {
      final pointer = ValueNotifier(const Offset(500, 250));
      addTearDown(pointer.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 400,
              height: 200,
              child: TrackpadCursor(
                pointer: pointer,
                framebuffer: const Size(1000, 500),
              ),
            ),
          ),
        ),
      );
      final area = tester.getRect(find.byType(TrackpadCursor));

      expect(
        tester.getTopLeft(find.byKey(const Key('trackpad-cursor'))),
        area.topLeft + const Offset(200, 100),
      );

      pointer.value = const Offset(0, 0);
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const Key('trackpad-cursor'))),
        area.topLeft,
      );
    });

    testWidgets('takes no pointer and says nothing to assistive '
        'technology', (tester) async {
      final pointer = ValueNotifier(const Offset(10, 10));
      addTearDown(pointer.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 200,
            child: TrackpadCursor(
              pointer: pointer,
              framebuffer: const Size(1000, 500),
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(TrackpadCursor),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byType(TrackpadCursor),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
    });
  });
}
