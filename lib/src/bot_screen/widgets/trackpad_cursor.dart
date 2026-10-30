import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// The cursor of Trackpad mode, drawn where the virtual pointer is.
///
/// It fills the picture's box and places a small arrow at [pointer], a
/// position in the remote screen's pixels ([framebuffer] is its size), so it
/// moves and zooms with the picture. It takes no pointer and is not read out.
class TrackpadCursor extends StatelessWidget {
  const TrackpadCursor({
    super.key,
    required this.pointer,
    required this.framebuffer,
  });

  final ValueListenable<Offset> pointer;
  final Size framebuffer;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => ValueListenableBuilder<Offset>(
          valueListenable: pointer,
          builder: (context, at, _) {
            if (framebuffer.isEmpty) return const SizedBox.shrink();
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  key: const Key('trackpad-cursor'),
                  left: at.dx / framebuffer.width * constraints.maxWidth,
                  top: at.dy / framebuffer.height * constraints.maxHeight,
                  child: const _Arrow(),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// A black arrow with a white edge, which shows on any desktop.
class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) =>
      const CustomPaint(size: Size(14, 20), painter: _ArrowPainter());
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * 0.85)
      ..lineTo(size.width * 0.3, size.height * 0.62)
      ..lineTo(size.width * 0.55, size.height)
      ..lineTo(size.width * 0.75, size.height * 0.9)
      ..lineTo(size.width * 0.5, size.height * 0.55)
      ..lineTo(size.width, size.height * 0.5)
      ..close();
    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.white,
      )
      ..drawPath(path, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => false;
}
