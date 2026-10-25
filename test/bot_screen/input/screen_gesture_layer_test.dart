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
                sink: rig.sink,
                framebuffer: _screen,
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

    testWidgets('the wheel is one notch per event', (tester) async {
      final rig = Rig();
      final origin = await pumpLayer(tester, rig);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      final spot = origin + const Offset(100, 150);

      await tester.sendEventToBinding(mouse.hover(spot));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 120)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -3)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(53, 0)));
      await tester.sendEventToBinding(mouse.scroll(const Offset(-53, 0)));

      expect(rig.sink.scrolls, [
        's 250 125 0 1',
        's 250 125 0 -1',
        's 250 125 1 0',
        's 250 125 -1 0',
      ]);
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
