import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_app/src/bot_screen/input/screen_geometry.dart';

void main() {
  group('absolute mapping', () {
    // A 1000 x 500 screen shown in a 400 x 400 viewport: the picture is
    // 400 x 200, letterboxed at y 100.
    final fitted = ScreenGeometry.fitted(
      framebuffer: const Size(1000, 500),
      viewport: const Size(400, 400),
    );

    test('the picture is fitted into the viewport', () {
      expect(fitted.pictureRect, const Rect.fromLTWH(0, 100, 400, 200));
    });

    test('maps a position at fit to the pixel under it', () {
      expect(fitted.toFramebuffer(const Offset(200, 200)), (x: 500, y: 250));
      expect(fitted.toFramebuffer(const Offset(0, 100)), (x: 0, y: 0));
      expect(fitted.toFramebuffer(const Offset(399.9, 299.9)), (
        x: 999,
        y: 499,
      ));
    });

    test('letterboxes a tall screen on the sides', () {
      final tall = ScreenGeometry.fitted(
        framebuffer: const Size(500, 1000),
        viewport: const Size(400, 400),
      );

      expect(tall.pictureRect, const Rect.fromLTWH(100, 0, 200, 400));
      expect(tall.toFramebuffer(const Offset(200, 200)), (x: 250, y: 500));
      expect(tall.toFramebuffer(const Offset(100, 0)), (x: 0, y: 0));
    });

    test('maps through a 2x zoom that is panned', () {
      // The picture is scaled 2x and moved 200 left and 100 up.
      final zoomed = ScreenGeometry.fitted(
        framebuffer: const Size(1000, 500),
        viewport: const Size(400, 400),
        transform: Matrix4.identity()
          ..translateByDouble(-200, -100, 0, 1)
          ..scaleByDouble(2, 2, 1, 1),
      );

      // Viewport (100, 150) is scene (150, 125), which is picture (150, 25).
      expect(zoomed.toFramebuffer(const Offset(100, 150)), (x: 375, y: 62));
      expect(zoomed.scale, 2);
    });

    test('clamps a position outside the picture to its edge', () {
      expect(fitted.toFramebuffer(const Offset(-50, -50)), (x: 0, y: 0));
      expect(fitted.toFramebuffer(const Offset(900, 900)), (x: 999, y: 499));
      // Above and below the letterbox keep their column.
      expect(fitted.toFramebuffer(const Offset(200, 10)), (x: 500, y: 0));
      expect(fitted.toFramebuffer(const Offset(200, 390)), (x: 500, y: 499));
    });

    test('clamps when the zoom pushes the picture past the viewport', () {
      final zoomed = ScreenGeometry.fitted(
        framebuffer: const Size(1000, 500),
        viewport: const Size(400, 400),
        transform: Matrix4.identity()..scaleByDouble(4, 4, 1, 1),
      );

      expect(zoomed.toFramebuffer(const Offset(-10, 0)), (x: 0, y: 0));
      expect(zoomed.toFramebuffer(const Offset(400, 400)), (x: 250, y: 0));
    });
  });

  group('relative movement', () {
    final geometry = ScreenGeometry.fitted(
      framebuffer: const Size(1000, 500),
      viewport: const Size(400, 400),
    );

    test('moves by the distance in screen pixels at 1x', () {
      // 400 logical pixels show 1000 screen pixels.
      expect(
        geometry.movePointer(const Offset(100, 100), const Offset(40, -8)),
        const Offset(200, 80),
      );
    });

    test('moves by a third of that at 3x', () {
      final zoomed = ScreenGeometry.fitted(
        framebuffer: const Size(1000, 500),
        viewport: const Size(400, 400),
        transform: Matrix4.identity()..scaleByDouble(3, 3, 1, 1),
      );

      final moved = zoomed.movePointer(Offset.zero, const Offset(120, 60));
      expect(moved.dx, closeTo(100, 1e-9));
      expect(moved.dy, closeTo(50, 1e-9));
    });

    test('stays on the screen', () {
      expect(
        geometry.movePointer(const Offset(990, 5), const Offset(100, -100)),
        const Offset(999, 0),
      );
      expect(
        geometry.movePointer(const Offset(5, 495), const Offset(-100, 100)),
        const Offset(0, 499),
      );
    });
  });

  group('ScrollAccumulator', () {
    test('turns 40 logical pixels into a notch and keeps the rest', () {
      final scroll = ScrollAccumulator();

      expect(scroll.add(39), 0);
      expect(scroll.add(1), 1);
      expect(scroll.add(30), 0);
      expect(scroll.add(30), 1); // 60 so far, 20 left over
      expect(scroll.add(100), 3); // 120
    });

    test('counts backwards and keeps a negative rest', () {
      final scroll = ScrollAccumulator();

      expect(scroll.add(-45), -1);
      expect(scroll.add(-35), -1); // -5 and -35 make -40
      expect(scroll.add(40), 1);
    });

    test('a direction change cancels what was gathered', () {
      final scroll = ScrollAccumulator();

      expect(scroll.add(30), 0);
      expect(scroll.add(-30), 0);
      expect(scroll.add(39), 0);
    });

    test('reset forgets the rest', () {
      final scroll = ScrollAccumulator()..add(30);
      scroll.reset();

      expect(scroll.add(30), 0);
    });
  });
}
