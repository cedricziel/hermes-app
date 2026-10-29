import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/input/screen_gesture_layer.dart';
import 'package:hermes_app/src/bot_screen/rfb/rfb_input_sink.dart';

/// Records what the layer sends as short strings: `p x y mask` and
/// `s x y dx dy`.
class RecordingSink implements RfbInputSink {
  final calls = <String>[];

  Iterable<String> get scrolls => calls.where((c) => c.startsWith('s'));

  @override
  void pointer(int x, int y, int buttonMask) =>
      calls.add('p $x $y $buttonMask');

  @override
  void scroll(int x, int y, {int dx = 0, int dy = 0}) =>
      calls.add('s $x $y $dx $dy');

  @override
  void key(int keysym, {required bool down}) => fail('the layer sends no keys');

  @override
  void cutText(String text) => fail('the layer sends no clipboard');
}

// A 1000 x 500 screen in a 400 x 400 layer: the picture is 400 x 200 at y 100,
// so a position (x, y) in the layer is screen pixel (2.5 x, 2.5 (y - 100)).
const _screen = Size(1000, 500);

/// A 2x zoom, panned 200 left and 100 up.
Matrix4 zoomed() => Matrix4.identity()
  ..translateByDouble(-200, -100, 0, 1)
  ..scaleByDouble(2, 2, 1, 1);

void expectViewerStill(Rig rig) {
  final t = rig.transformation.value.getTranslation();
  expect((t.x, t.y), (-200.0, -100.0));
  expect(rig.transformation.value.getMaxScaleOnAxis(), 2);
}

class Rig {
  final sink = RecordingSink();
  final transformation = TransformationController();
  final pointer = ValueNotifier<Offset>(const Offset(500, 250));
}

Future<Offset> pumpLayer(
  WidgetTester tester,
  Rig rig, {
  bool enabled = true,
  ScreenGestureMode mode = ScreenGestureMode.touch,
  bool viewer = false,
  Size framebuffer = _screen,
  RfbInputSink? sink,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 400,
          height: 400,
          child: Stack(
            children: [
              if (viewer)
                InteractiveViewer(
                  transformationController: rig.transformation,
                  child: const SizedBox(width: 400, height: 400),
                ),
              ScreenGestureLayer(
                sink: sink ?? rig.sink,
                framebuffer: framebuffer,
                transformation: rig.transformation,
                virtualPointer: rig.pointer,
                enabled: enabled,
                mode: mode,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return tester.getTopLeft(find.byType(ScreenGestureLayer));
}

void main() {
  group('touch', () {
    testWidgets('a tap moves, presses and releases the primary button', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);

      await tester.tapAt(origin + const Offset(200, 200));

      expect(rig.sink.calls, ['p 500 250 0', 'p 500 250 1', 'p 500 250 0']);
    });

    testWidgets('maps through the current zoom', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);
      rig.transformation.value = Matrix4.identity()..scaleByDouble(2, 2, 1, 1);

      await tester.tapAt(origin + const Offset(100, 250));

      expect(rig.sink.calls.first, 'p 125 62 0');
    });

    testWidgets('a long press is a click of the secondary button', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);

      await tester.longPressAt(origin + const Offset(200, 200));

      expect(rig.sink.calls, ['p 500 250 0', 'p 500 250 4', 'p 500 250 0']);
    });

    testWidgets('a drag holds the primary button while it moves', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);

      final finger = await tester.startGesture(origin + const Offset(100, 150));
      expect(rig.sink.calls, isEmpty);
      await finger.moveBy(const Offset(30, 0));
      expect(rig.sink.calls, ['p 250 125 0', 'p 250 125 1', 'p 325 125 1']);
      await finger.moveBy(const Offset(20, 0));
      await finger.up();

      expect(rig.sink.calls.skip(3), ['p 375 125 1', 'p 375 125 0']);
    });

    testWidgets('a finger that stays put and lifts is a tap, not a drag', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);

      final finger = await tester.startGesture(origin + const Offset(100, 150));
      await finger.moveBy(const Offset(3, 2));
      await finger.up();

      expect(rig.sink.calls, ['p 250 125 0', 'p 250 125 1', 'p 250 125 0']);
    });

    testWidgets('a pinch reaches the viewer and sends nothing', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig, viewer: true);

      final a = await tester.startGesture(origin + const Offset(150, 200));
      final b = await tester.startGesture(origin + const Offset(250, 200));
      await a.moveBy(const Offset(-40, 0));
      await b.moveBy(const Offset(40, 0));
      await a.up();
      await b.up();

      expect(rig.transformation.value.getMaxScaleOnAxis(), greaterThan(1));
      expect(rig.sink.calls, isEmpty);
    });

    testWidgets('a second finger releases a drag in progress', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);

      final a = await tester.startGesture(origin + const Offset(100, 150));
      await a.moveBy(const Offset(30, 0));
      final b = await tester.startGesture(origin + const Offset(300, 300));
      expect(rig.sink.calls.last, 'p 325 125 0');
      final sent = rig.sink.calls.length;
      await a.moveBy(const Offset(30, 0));
      await b.moveBy(const Offset(0, 30));
      await a.up();
      await b.up();

      expect(rig.sink.calls, hasLength(sent));
    });

    testWidgets('a cancelled touch releases a drag in progress', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);

      final finger = await tester.startGesture(origin + const Offset(100, 150));
      await finger.moveBy(const Offset(30, 0));
      await finger.cancel();

      expect(rig.sink.calls.last, 'p 325 125 0');
    });
  });

  group('trackpad mode', () {
    testWidgets('a pan moves the virtual pointer and sends where it is', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(
        tester,
        rig,
        mode: ScreenGestureMode.trackpad,
      );

      final finger = await tester.startGesture(origin + const Offset(100, 100));
      await finger.moveBy(const Offset(30, 0));
      expect(rig.pointer.value, const Offset(575, 250));
      await finger.moveBy(const Offset(20, 0));
      await finger.up();

      expect(rig.pointer.value, const Offset(625, 250));
      expect(rig.sink.calls, ['p 575 250 0', 'p 625 250 0']);
    });

    testWidgets('moves less when zoomed in', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(
        tester,
        rig,
        mode: ScreenGestureMode.trackpad,
      );
      rig.transformation.value = Matrix4.identity()..scaleByDouble(2, 2, 1, 1);

      final finger = await tester.startGesture(origin + const Offset(100, 100));
      await finger.moveBy(const Offset(40, 0));
      await finger.up();

      expect(rig.pointer.value, const Offset(550, 250));
    });

    testWidgets('a tap clicks where the virtual pointer is', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(
        tester,
        rig,
        mode: ScreenGestureMode.trackpad,
      );

      await tester.tapAt(origin + const Offset(20, 20));

      expect(rig.sink.calls, ['p 500 250 0', 'p 500 250 1', 'p 500 250 0']);
    });

    testWidgets('a long press clicks the secondary button there', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(
        tester,
        rig,
        mode: ScreenGestureMode.trackpad,
      );

      await tester.longPressAt(origin + const Offset(20, 20));

      expect(rig.sink.calls, ['p 500 250 0', 'p 500 250 4', 'p 500 250 0']);
    });

    testWidgets('keeps the pointer on the screen', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(
        tester,
        rig,
        mode: ScreenGestureMode.trackpad,
      );

      final finger = await tester.startGesture(origin + const Offset(100, 100));
      await finger.moveBy(const Offset(300, 0));
      await finger.moveBy(const Offset(300, 0));
      await finger.up();

      expect(rig.pointer.value.dx, 999);
    });
  });

  group('mouse', () {
    testWidgets('hover moves the pointer with no button', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: origin + const Offset(200, 200));
      await mouse.moveTo(origin + const Offset(100, 150));

      expect(rig.sink.calls.last, 'p 250 125 0');
    });

    testWidgets('buttons are sent as the mask while pressed', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);
      final spot = origin + const Offset(100, 150);

      for (final (flutter, rfb) in [
        (kPrimaryMouseButton, 1),
        (kMiddleMouseButton, 2),
        (kSecondaryMouseButton, 4),
      ]) {
        rig.sink.calls.clear();
        final mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: flutter,
        );
        await mouse.down(spot);
        await mouse.moveTo(spot + const Offset(20, 0));
        await mouse.up();

        expect(rig.sink.calls, [
          'p 250 125 $rfb',
          'p 300 125 $rfb',
          'p 300 125 0',
        ], reason: 'button $flutter');
      }
    });

    testWidgets('a discrete wheel click is at least one notch', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      final spot = origin + const Offset(100, 150);

      await tester.sendEventToBinding(mouse.hover(spot));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 53)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -120)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(240, 0)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(-53, 0)));

      expect(rig.sink.scrolls, [
        's 250 125 0 1',
        's 250 125 0 -1',
        's 250 125 2 0',
        's 250 125 -1 0',
      ]);
    });

    testWidgets('small wheel deltas gather before they scroll', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);

      await tester.sendEventToBinding(
        mouse.hover(origin + const Offset(100, 150)),
      );
      for (var i = 0; i < 11; i++) {
        await tester.sendEventToBinding(mouse.scroll(const Offset(0, 10)));
      }
      expect(rig.sink.scrolls, isEmpty);
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 10)));

      expect(rig.sink.scrolls, ['s 250 125 0 1']);
    });

    testWidgets('a trackpad scroll event goes through the accumulator', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);
      final pad = TestPointer(2, PointerDeviceKind.trackpad);
      final spot = origin + const Offset(100, 150);

      await tester.sendEventToBinding(pad.hover(spot));
      await tester.sendEventToBinding(pad.scroll(const Offset(0, 30)));
      expect(rig.sink.scrolls, isEmpty);
      await tester.sendEventToBinding(pad.scroll(const Offset(0, 30)));

      expect(rig.sink.scrolls, ['s 250 125 0 1']);
    });

    testWidgets('a mouse drag on a zoomed viewer drags remotely', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig, viewer: true);
      rig.transformation.value = zoomed();

      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await mouse.down(origin + const Offset(100, 150));
      for (var i = 0; i < 5; i++) {
        await mouse.moveBy(const Offset(20, 0));
      }
      await mouse.up();

      expect(rig.sink.calls.first, 'p 375 62 1');
      expect(rig.sink.calls.last, 'p 500 62 0');
      expectViewerStill(rig);
    });

    testWidgets('the same pixel and buttons are sent once', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: origin + const Offset(100, 150));
      await mouse.moveTo(origin + const Offset(100, 150));
      await mouse.moveTo(origin + const Offset(100.2, 150.1));
      await mouse.moveTo(origin + const Offset(101, 150));

      expect(rig.sink.calls, ['p 250 125 0', 'p 252 125 0']);
    });

    testWidgets('a mouse button held across a cancel is released', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);

      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await mouse.down(origin + const Offset(100, 150));
      await mouse.cancel();

      expect(rig.sink.calls, ['p 250 125 1', 'p 250 125 0']);
    });

    testWidgets('trackpad scrolling gathers into notches of 40 pixels', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);
      final pad = TestPointer(2, PointerDeviceKind.trackpad);
      final spot = origin + const Offset(100, 150);

      await tester.sendEventToBinding(pad.panZoomStart(spot));
      // Fingers moving up scroll down.
      await tester.sendEventToBinding(
        pad.panZoomUpdate(spot, pan: const Offset(0, -30)),
      );
      expect(rig.sink.scrolls, isEmpty);
      await tester.sendEventToBinding(
        pad.panZoomUpdate(spot, pan: const Offset(-45, -60)),
      );
      await tester.sendEventToBinding(pad.panZoomEnd());

      expect(rig.sink.scrolls, ['s 250 125 1 1']);
    });
  });

  group('on a zoomed viewer', () {
    testWidgets('a one-finger drag drags remotely, not the viewer', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig, viewer: true);
      rig.transformation.value = zoomed();

      final finger = await tester.startGesture(origin + const Offset(100, 150));
      for (var i = 0; i < 5; i++) {
        await finger.moveBy(const Offset(20, 0));
      }
      await finger.up();

      expect(rig.sink.calls.last, 'p 500 62 0');
      expect(rig.sink.calls, contains('p 425 62 1'));
      expectViewerStill(rig);
    });

    testWidgets('a one-finger pan in trackpad mode does not pan the viewer', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(
        tester,
        rig,
        viewer: true,
        mode: ScreenGestureMode.trackpad,
      );
      rig.transformation.value = zoomed();

      final finger = await tester.startGesture(origin + const Offset(100, 150));
      for (var i = 0; i < 5; i++) {
        await finger.moveBy(const Offset(20, 0));
      }
      await finger.up();

      // 100 px at 2x is 125 screen pixels.
      expect(rig.pointer.value, const Offset(625, 250));
      expectViewerStill(rig);
    });

    testWidgets('two fingers still pinch the viewer', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig, viewer: true);

      final a = await tester.startGesture(origin + const Offset(150, 200));
      final b = await tester.startGesture(origin + const Offset(250, 200));
      for (var i = 0; i < 4; i++) {
        await a.moveBy(const Offset(-15, 0));
        await b.moveBy(const Offset(15, 0));
      }
      await a.up();
      await b.up();

      expect(rig.transformation.value.getMaxScaleOnAxis(), greaterThan(1));
      expect(rig.sink.calls, isEmpty);
    });

    testWidgets('a trackpad scroll is a remote scroll, not a viewer pan', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig, viewer: true);
      rig.transformation.value = zoomed();
      final pad = TestPointer(2, PointerDeviceKind.trackpad);
      final spot = origin + const Offset(100, 150);

      await tester.sendEventToBinding(pad.panZoomStart(spot));
      for (var i = 1; i <= 4; i++) {
        await tester.sendEventToBinding(
          pad.panZoomUpdate(spot, pan: Offset(0, -20.0 * i)),
        );
      }
      await tester.sendEventToBinding(pad.panZoomEnd());

      expect(rig.sink.scrolls, ['s 375 62 0 1', 's 375 62 0 1']);
      expectViewerStill(rig);
    });

    testWidgets('a trackpad pinch zooms the viewer and scrolls nothing', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig, viewer: true);
      final pad = TestPointer(2, PointerDeviceKind.trackpad);
      final spot = origin + const Offset(100, 150);

      await tester.sendEventToBinding(pad.panZoomStart(spot));
      for (final scale in [1.1, 1.3, 1.6]) {
        await tester.sendEventToBinding(
          pad.panZoomUpdate(spot, scale: scale, pan: const Offset(0, -45)),
        );
      }
      await tester.sendEventToBinding(pad.panZoomEnd());

      expect(rig.transformation.value.getMaxScaleOnAxis(), greaterThan(1));
      expect(rig.sink.scrolls, isEmpty);
    });

    testWidgets('once a trackpad gesture is a pinch it stays one', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);
      final pad = TestPointer(2, PointerDeviceKind.trackpad);
      final spot = origin + const Offset(100, 150);

      await tester.sendEventToBinding(pad.panZoomStart(spot));
      await tester.sendEventToBinding(
        pad.panZoomUpdate(spot, scale: 1.4, pan: Offset.zero),
      );
      await tester.sendEventToBinding(
        pad.panZoomUpdate(spot, pan: const Offset(0, -200)),
      );
      await tester.sendEventToBinding(pad.panZoomEnd());

      expect(rig.sink.scrolls, isEmpty);
    });
  });

  group('second finger', () {
    for (final mode in ScreenGestureMode.values) {
      testWidgets('after the first crossed the slop sends no click ($mode)', (
        tester,
      ) async {
        final rig = Rig();
        final origin = await pumpLayer(tester, rig, mode: mode);

        final a = await tester.startGesture(origin + const Offset(100, 150));
        await a.moveBy(const Offset(30, 0));
        final b = await tester.startGesture(origin + const Offset(300, 300));
        final sent = rig.sink.calls.length;
        await a.up();
        await b.up();
        await tester.pump(const Duration(seconds: 1));

        expect(rig.sink.calls, hasLength(sent));
        // Touch mode ended its drag; a click would be a second press.
        expect(
          rig.sink.calls.where((c) => c.endsWith(' 1')),
          hasLength(mode == ScreenGestureMode.touch ? 2 : 0),
        );
      });
    }

    testWidgets('before any movement sends no click', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);

      final a = await tester.startGesture(origin + const Offset(100, 150));
      final b = await tester.startGesture(origin + const Offset(300, 300));
      await a.up();
      await b.up();
      await tester.pump(const Duration(seconds: 1));

      expect(rig.sink.calls, isEmpty);
    });
  });

  group('release', () {
    testWidgets('a mode change mid-drag releases the button', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);
      final finger = await tester.startGesture(origin + const Offset(100, 150));
      await finger.moveBy(const Offset(30, 0));

      await pumpLayer(tester, rig, mode: ScreenGestureMode.trackpad);

      expect(rig.sink.calls.last, 'p 325 125 0');
      await finger.up();
    });

    testWidgets('a sink change mid-drag releases on the old sink', (
      tester,
    ) async {
      final rig = Rig();
      final next = RecordingSink();
      final origin = await pumpLayer(tester, rig);
      final finger = await tester.startGesture(origin + const Offset(100, 150));
      await finger.moveBy(const Offset(30, 0));

      await pumpLayer(tester, rig, sink: next);

      expect(rig.sink.calls.last, 'p 325 125 0');
      expect(next.calls, isEmpty);
      await finger.up();
    });

    for (final change in <String, Future<void> Function(WidgetTester, Rig)>{
      'disabling': (t, r) => pumpLayer(t, r, enabled: false),
      'disposing': (t, r) => t.pumpWidget(const SizedBox()),
      'a sink change': (t, r) => pumpLayer(t, r, sink: RecordingSink()),
    }.entries) {
      testWidgets('${change.key} releases a held mouse button', (tester) async {
        final rig = Rig();
        final origin = await pumpLayer(tester, rig);
        final mouse = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kPrimaryMouseButton | kSecondaryMouseButton,
        );
        await mouse.down(origin + const Offset(100, 150));
        await mouse.moveBy(const Offset(20, 0));

        await change.value(tester, rig);

        expect(rig.sink.calls.last, 'p 300 125 0');
        await mouse.up();
      });
    }

    testWidgets('nothing is released when nothing is held', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);
      await tester.tapAt(origin + const Offset(100, 150));
      final sent = rig.sink.calls.length;

      await pumpLayer(tester, rig, enabled: false);

      expect(rig.sink.calls, hasLength(sent));
    });
  });

  group('trackpad mode pointer', () {
    testWidgets('the first move after the slop counts the slop travel', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(
        tester,
        rig,
        mode: ScreenGestureMode.trackpad,
      );

      final finger = await tester.startGesture(origin + const Offset(100, 100));
      await finger.moveBy(const Offset(10, 0));
      expect(rig.sink.calls, isEmpty);
      await finger.moveBy(const Offset(15, 0));
      await finger.up();

      // 25 px of travel is 62.5 screen pixels.
      expect(rig.pointer.value, const Offset(562.5, 250));
    });

    testWidgets('a mouse sets the virtual pointer where it points', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(
        tester,
        rig,
        mode: ScreenGestureMode.trackpad,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: origin + const Offset(100, 150));
      await mouse.moveTo(origin + const Offset(100, 150));

      expect(rig.pointer.value, const Offset(250, 125));
    });

    testWidgets('scrolling happens at the virtual pointer', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(
        tester,
        rig,
        mode: ScreenGestureMode.trackpad,
      );
      rig.pointer.value = const Offset(100, 50);
      final pad = TestPointer(2, PointerDeviceKind.trackpad);
      final spot = origin + const Offset(300, 300);

      await tester.sendEventToBinding(pad.panZoomStart(spot));
      await tester.sendEventToBinding(
        pad.panZoomUpdate(spot, pan: const Offset(0, -60)),
      );
      await tester.sendEventToBinding(pad.panZoomEnd());

      expect(rig.sink.scrolls, ['s 100 50 0 1']);
    });

    testWidgets('a smaller screen pulls the pointer back onto it', (
      tester,
    ) async {
      final rig = Rig();
      await pumpLayer(tester, rig, mode: ScreenGestureMode.trackpad);
      rig.pointer.value = const Offset(900, 450);

      await pumpLayer(
        tester,
        rig,
        mode: ScreenGestureMode.trackpad,
        framebuffer: const Size(800, 400),
      );
      await tester.pump();

      expect(rig.pointer.value, const Offset(799, 399));
    });

    testWidgets('a layer with its own pointer starts at the centre', (
      tester,
    ) async {
      final sink = RecordingSink();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 400,
            child: ScreenGestureLayer(
              sink: sink,
              framebuffer: _screen,
              enabled: true,
              mode: ScreenGestureMode.trackpad,
            ),
          ),
        ),
      );

      await tester.tapAt(const Offset(20, 20));

      expect(sink.calls, ['p 500 250 0', 'p 500 250 1', 'p 500 250 0']);
    });
  });

  group('trackpad tap and drag', () {
    Future<Offset> pumpTrackpad(WidgetTester tester, Rig rig) =>
        pumpLayer(tester, rig, mode: ScreenGestureMode.trackpad);

    testWidgets('a tap followed at once by a press that moves holds the '
        'primary button for the drag', (tester) async {
      final rig = Rig();
      final origin = await pumpTrackpad(tester, rig);
      await tester.tapAt(origin + const Offset(100, 100));
      rig.sink.calls.clear();

      final finger = await tester.startGesture(origin + const Offset(100, 100));
      await finger.moveBy(const Offset(30, 0));
      await finger.moveBy(const Offset(20, 0));
      await finger.up();

      // 30 px of travel is 75 screen pixels, then 50 more.
      expect(rig.sink.calls, [
        'p 500 250 1',
        'p 575 250 1',
        'p 625 250 1',
        'p 625 250 0',
      ]);
      expect(rig.pointer.value, const Offset(625, 250));
    });

    testWidgets('a second tap that does not move is a second click', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpTrackpad(tester, rig);

      await tester.tapAt(origin + const Offset(100, 100));
      await tester.tapAt(origin + const Offset(100, 100));

      expect(rig.sink.calls, [
        'p 500 250 0',
        'p 500 250 1',
        'p 500 250 0',
        'p 500 250 1',
        'p 500 250 0',
      ]);
    });

    testWidgets('a press that comes too late only moves the pointer', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpTrackpad(tester, rig);
      await tester.tapAt(origin + const Offset(100, 100));
      rig.sink.calls.clear();

      await tester.pump(const Duration(milliseconds: 400));
      final finger = await tester.startGesture(origin + const Offset(100, 100));
      await finger.moveBy(const Offset(30, 0));
      await finger.up();

      expect(rig.sink.calls, ['p 575 250 0']);
    });

    testWidgets('a drag is not a tap that arms the next one', (tester) async {
      final rig = Rig();
      final origin = await pumpTrackpad(tester, rig);
      final first = await tester.startGesture(origin + const Offset(100, 100));
      await first.moveBy(const Offset(30, 0));
      await first.up();
      rig.sink.calls.clear();

      final second = await tester.startGesture(origin + const Offset(100, 100));
      await second.moveBy(const Offset(30, 0));
      await second.up();

      expect(rig.sink.calls, ['p 650 250 0']);
    });

    testWidgets('a second finger landing during the drag lets the button '
        'go', (tester) async {
      final rig = Rig();
      final origin = await pumpTrackpad(tester, rig);
      await tester.tapAt(origin + const Offset(100, 100));
      final finger = await tester.startGesture(origin + const Offset(100, 100));
      await finger.moveBy(const Offset(30, 0));
      rig.sink.calls.clear();

      final other = await tester.startGesture(origin + const Offset(300, 300));
      await other.up();
      await finger.up();

      expect(rig.sink.calls, ['p 575 250 0']);
    });

    testWidgets('disabling the layer during the drag lets the button go', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpTrackpad(tester, rig);
      await tester.tapAt(origin + const Offset(100, 100));
      final finger = await tester.startGesture(origin + const Offset(100, 100));
      await finger.moveBy(const Offset(30, 0));
      rig.sink.calls.clear();

      await pumpLayer(
        tester,
        rig,
        mode: ScreenGestureMode.trackpad,
        enabled: false,
      );
      await finger.up();

      expect(rig.sink.calls, ['p 575 250 0']);
    });

    testWidgets('touch mode has no tap and drag: the drag starts where the '
        'finger is', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);
      await tester.tapAt(origin + const Offset(100, 150));
      rig.sink.calls.clear();

      final finger = await tester.startGesture(origin + const Offset(100, 150));
      await finger.moveBy(const Offset(30, 0));
      await finger.up();

      expect(rig.sink.calls.first, 'p 250 125 1');
    });
  });

  group('disabled', () {
    testWidgets('sends nothing for touch, mouse or wheel', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig, enabled: false);

      await tester.tapAt(origin + const Offset(200, 200));
      await tester.longPressAt(origin + const Offset(200, 200));
      final finger = await tester.startGesture(origin + const Offset(100, 150));
      await finger.moveBy(const Offset(60, 0));
      await finger.up();
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(origin + const Offset(9, 9)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await tester.sendEventToBinding(mouse.down(origin + const Offset(9, 9)));
      await tester.sendEventToBinding(mouse.up());

      expect(rig.sink.calls, isEmpty);
    });

    testWidgets('is the default', (tester) async {
      final rig = Rig();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 400,
            child: ScreenGestureLayer(sink: rig.sink, framebuffer: _screen),
          ),
        ),
      );

      await tester.tapAt(const Offset(200, 200));

      expect(rig.sink.calls, isEmpty);
    });

    testWidgets('turning it off mid-drag releases the button', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);

      final finger = await tester.startGesture(origin + const Offset(100, 150));
      await finger.moveBy(const Offset(30, 0));
      await pumpLayer(tester, rig, enabled: false);

      expect(rig.sink.calls.last, 'p 325 125 0');
      await finger.up();
      expect(rig.sink.calls.last, 'p 325 125 0');
    });

    testWidgets('a layer that goes away mid-drag releases the button', (
      tester,
    ) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);

      final finger = await tester.startGesture(origin + const Offset(100, 150));
      await finger.moveBy(const Offset(30, 0));
      await tester.pumpWidget(const SizedBox());

      expect(rig.sink.calls.last, 'p 325 125 0');
      await finger.up();
    });

    testWidgets('a sink that has closed does not break the release', (
      tester,
    ) async {
      final sink = _ClosingSink();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 400,
            child: ScreenGestureLayer(
              sink: sink,
              framebuffer: _screen,
              enabled: true,
            ),
          ),
        ),
      );

      final finger = await tester.startGesture(const Offset(100, 150));
      await finger.moveBy(const Offset(30, 0));
      sink.closed = true;
      await tester.pumpWidget(const SizedBox());

      expect(tester.takeException(), isNull);
      await finger.up();
    });
  });
}

class _ClosingSink extends RecordingSink {
  bool closed = false;

  @override
  void pointer(int x, int y, int buttonMask) {
    if (closed) throw StateError('closed');
    super.pointer(x, y, buttonMask);
  }
}
