import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:hermes_app/src/theme/hermes_theme.dart';
import 'package:hermes_app/src/theme/platform_chrome.dart';

/// The smallest height of a button here: 44 pt on iOS, 48 dp on Material,
/// 28 pt on a Mac.
double agentTargetHeight(BuildContext context) =>
    switch (platformChromeOf(context)) {
      PlatformChrome.material => 48,
      PlatformChrome.ios => kAppleMinTapTarget,
      PlatformChrome.macos => 28,
    };

/// True at the accessibility text sizes, where output and fields stop
/// clamping and layouts stack.
bool agentLargeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) > 21;

/// A section heading, announced as a header.
class AgentSectionTitle extends StatelessWidget {
  const AgentSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
  );
}

/// One line of subtle explanatory text.
class AgentSubtleText extends StatelessWidget {
  const AgentSubtleText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: context.hermesColors.subtleText),
  );
}

/// A rounded box with a dashed border, for text that can no longer be sent.
class AgentDashedBox extends StatelessWidget {
  const AgentDashedBox({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashedBorder(Theme.of(context).colorScheme.outline),
    child: Padding(padding: const EdgeInsets.all(12), child: child),
  );
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 8) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) => old.color != color;
}
